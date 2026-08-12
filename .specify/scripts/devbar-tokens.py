#!/usr/bin/env python3
"""
Measure real token consumption for THIS workspace from Devbar's local event log.

Why this exists
---------------
token_consumption in progress-tracker.json is an *estimate*: artifact characters
divided by 3.8, multiplied by a 5.7 overhead factor (see reestimate-tokens.py).
Devbar meters the real thing locally, per generation, so we no longer have to
guess. The estimate counts what was *written* and this counts every token
*processed*, so they are not interchangeable and this writes a separate block
rather than overwriting the estimates. How far apart they sit is computed at
write time by calibration() and stated in the tracker's own note, so it stays
true as both figures move instead of quoting a multiple that has since drifted.

Devbar's dashboard reports the whole machine, which mixes every customer
together. Everything here is filtered to one workspace, so a project's numbers
only ever contain that project's work.

The formula
-----------
Events inside one generation carry *running cumulative* token counts, so the
final value for a generation is the MAX of its rows, not the sum. Summing rows
directly roughly doubles the answer. So:

    per generation:  i  = MAX(input_tokens)
                     o  = MAX(output_tokens)
                     cr = MAX(cache_read_tokens)
                     cw = MAX(cache_write_tokens)

input_tokens ALREADY CONTAINS the cached tokens
-----------------------------------------------
This is the trap. `input_tokens` is the whole input for the call, and
`cache_read_tokens` and `cache_write_tokens` are a *breakdown* of it, not
additions to it. Measured over this repo's own history, across all 53
generations, i - cr - cw never exceeded 136 tokens and never went negative:

    SUM(i)  = 173,978,534
    SUM(cr) + SUM(cw)
            = 173,976,848      <- 99.999% of input
    residual (genuinely fresh, uncached input)
            =       1,686

So `i + o + cr + cw` counts the cached tokens three times over and roughly
doubles the honest figure. The correct totals are:

    total tokens         = SUM(i + o)              over generations
    fresh input          = SUM(i - cr - cw)
    excluding cache read = SUM(i + o - cr)         tracks cost
    tokens per generation = SUM(i) / COUNT(*)      context volume per turn

A generation is one full agent turn spanning many model calls, so cache_read is
the same context re-sent on each of them. It is ~95% of all input, which is why
the measured number dwarfs the artifact-derived estimate even after the
double-count is removed. The estimate counts what was *written*; this counts
every token *processed*, and re-reading dominates.

Cost note: cache_read bills far below fresh input and cache_write bills above
it, so `excluding_cache_read` is the figure that tracks spend, not `total`.

Usage
-----
    python3 scripts/devbar-tokens.py                  # report for this workspace
    python3 scripts/devbar-tokens.py --days 7         # last 7 days only
    python3 scripts/devbar-tokens.py --write          # also update progress-tracker.json
    python3 scripts/devbar-tokens.py --workspace /path/to/other
    python3 scripts/devbar-tokens.py --all-workspaces # what else is on this machine

Read-only: the Devbar database is opened with mode=ro and never written to.
Exits 0 when Devbar is not installed, so commit hooks do not break.
"""
import argparse
import json
import sqlite3
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

DEFAULT_DB = Path.home() / ".devbar" / "plugins" / "ai-analytics" / "events.db"

# One row per generation, each token column reduced by MAX. Everything else is
# built on top of this, so the definition lives in exactly one place.
GENERATIONS_CTE = """
WITH gen AS (
    SELECT generation_id,
           MIN(ts)                                             AS first_ts,
           COALESCE(MAX(NULLIF(workspace, '')),
                    MAX(NULLIF(cwd, '')), '')                  AS ws,
           COALESCE(MAX(tool), '')                             AS tool,
           MAX(input_tokens)                                   AS i,
           MAX(output_tokens)                                  AS o,
           MAX(cache_read_tokens)                              AS cr,
           MAX(cache_write_tokens)                             AS cw
    FROM events
    WHERE input_tokens IS NOT NULL
    GROUP BY generation_id
)
"""


def repo_root() -> Path:
    try:
        out = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, check=True,
        )
        return Path(out.stdout.strip())
    except Exception:
        return Path.cwd()


def connect(db: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    return conn


def where_clause(workspace, since_ms):
    """Filter AFTER grouping, so a generation is never split across the boundary."""
    clauses, params = [], []
    if workspace:
        clauses.append("(ws = ? OR ws LIKE ?)")
        params += [workspace, workspace.rstrip("/") + "/%"]
    if since_ms:
        clauses.append("first_ts >= ?")
        params.append(since_ms)
    return ("WHERE " + " AND ".join(clauses)) if clauses else "", params


def measure(conn, workspace, since_ms):
    where, params = where_clause(workspace, since_ms)

    totals = conn.execute(GENERATIONS_CTE + f"""
        SELECT COUNT(*)                AS generations,
               COALESCE(SUM(i), 0)     AS input,
               COALESCE(SUM(o), 0)     AS output,
               COALESCE(SUM(cr), 0)    AS cache_read,
               COALESCE(SUM(cw), 0)    AS cache_write,
               MIN(first_ts)           AS first_ts,
               MAX(first_ts)           AS last_ts
        FROM gen {where}
    """, params).fetchone()

    # cr and cw are a breakdown of i, never added to it. See the module docstring.
    by_day = conn.execute(GENERATIONS_CTE + f"""
        SELECT date(first_ts / 1000, 'unixepoch', 'localtime') AS day,
               COUNT(*)        AS generations,
               SUM(i + o)      AS total,
               SUM(i + o - cr) AS excluding_cache_read
        FROM gen {where}
        GROUP BY day ORDER BY day
    """, params).fetchall()

    by_tool = conn.execute(GENERATIONS_CTE + f"""
        SELECT tool,
               COUNT(*)   AS generations,
               SUM(i + o) AS total
        FROM gen {where}
        GROUP BY tool ORDER BY total DESC
    """, params).fetchall()

    n = totals["generations"]
    grand = totals["input"] + totals["output"]
    return {
        "generations": n,
        "input": totals["input"],
        "output": totals["output"],
        "cache_read": totals["cache_read"],
        "cache_write": totals["cache_write"],
        "fresh_input": totals["input"] - totals["cache_read"] - totals["cache_write"],
        "total": grand,
        "excluding_cache_read": grand - totals["cache_read"],
        "tokens_per_generation": round(totals["input"] / n) if n else 0,
        "first_day": iso_day(totals["first_ts"]),
        "last_day": iso_day(totals["last_ts"]),
        "by_day": [dict(r) for r in by_day],
        "by_tool": [dict(r) for r in by_tool],
    }


def iso_day(ms):
    if not ms:
        return None
    return datetime.fromtimestamp(ms / 1000).strftime("%Y-%m-%d")


def trackers(root: Path):
    found = [p for p in (root / "docs" / "progress-tracker.json",) if p.exists()]
    # Hidden directories are scratch and test scaffolding, not published dashboards.
    found += sorted(p for p in root.glob("*/docs/progress-tracker.json")
                    if not p.relative_to(root).parts[0].startswith("."))
    return found


def calibration(data, m) -> str:
    """
    State how far the estimate sits under the measurement, computed rather than
    remembered. Earlier versions hard-coded these two multiples, which then went
    stale the moment either figure moved and left the tracker asserting a
    relationship that no longer held.
    """
    est = data.get("token_consumption", {}).get("total_estimated_tokens")
    if not est:
        return ""
    # The estimate's own base before the 5.7 overhead: comparable with output,
    # since both are roughly "tokens actually written".
    base = est / 5.7
    return (
        f"Compared like with like, on the coverage above: the estimate "
        f"({est:,}) sits {m['excluding_cache_read'] / est:.1f}x under "
        f"excluding_cache_read ({m['excluding_cache_read']:,}), and the "
        f"estimate's artifact base ({base:,.0f}, the estimate before its 5.7 "
        f"overhead) sits {m['output'] / base:.1f}x under measured output "
        f"({m['output']:,}). Both multiples are computed at write time, not "
        f"remembered, so they cannot go stale. The estimate covers the whole "
        f"project while this measurement starts when Devbar was installed, so "
        f"the ratio understates the true gap by whatever preceded it. "
    )


def write_block(path: Path, workspace: str, days, m) -> None:
    data = json.loads(path.read_text())
    data["measured_token_consumption"] = {
        "source": "devbar ai-analytics, ~/.devbar/plugins/ai-analytics/events.db",
        "workspace": workspace,
        "window_days": days or "all",
        "updated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "method": (
            "Per generation take MAX of each token column, because events within a "
            "generation carry running cumulative counts, then sum across generations. "
            "total is input + output. cache_read and cache_write are a BREAKDOWN of "
            "input, not additions to it: measured here, input minus cache_read minus "
            "cache_write leaves under 2,000 genuinely fresh tokens across all "
            "generations. Adding the cache columns to input, as an earlier version of "
            "this script did, counts cached context three times and roughly doubles "
            "the answer."
        ),
        "note": (
            "Measured, not estimated, and scoped to this workspace only. Not comparable "
            "with token_consumption above, which is derived from artifact volume: that "
            "one counts what was written, this counts every token processed. cache_read "
            "is the same context re-sent on every model call inside a turn and is about "
            "95% of all input, which is what opens the gap between the two figures. "
            + calibration(data, m) +
            "Since cache_read bills far below fresh input, excluding_cache_read is the "
            "figure that tracks spend. Coverage starts when Devbar was installed, so "
            "earlier work is absent."
        ),
        "totals": {k: m[k] for k in (
            "generations", "input", "output", "cache_write", "cache_read",
            "fresh_input", "excluding_cache_read", "total", "tokens_per_generation")},
        "coverage": {"first_day": m["first_day"], "last_day": m["last_day"]},
        "by_day": m["by_day"],
        "by_tool": m["by_tool"],
    }
    path.write_text(json.dumps(data, indent=2) + "\n")


def human(n):
    if n >= 1_000_000:
        return f"{n/1_000_000:,.2f}M"
    if n >= 1_000:
        return f"{n/1_000:,.1f}K"
    return str(n)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    ap.add_argument("--db", type=Path, default=DEFAULT_DB)
    ap.add_argument("--workspace", help="Defaults to the git root of the current directory")
    ap.add_argument("--days", type=int, help="Only generations from the last N days")
    ap.add_argument("--write", action="store_true", help="Update progress-tracker.json")
    ap.add_argument("--json", action="store_true", help="Emit JSON instead of a report")
    ap.add_argument("--all-workspaces", action="store_true",
                    help="Break down every workspace on this machine")
    args = ap.parse_args()

    if not args.db.exists():
        print(f"Devbar event log not found at {args.db} - nothing to measure.")
        return 0

    root = repo_root()
    workspace = args.workspace or str(root)
    since_ms = None
    if args.days:
        since_ms = int((datetime.now().timestamp() - args.days * 86400) * 1000)

    conn = connect(args.db)

    if args.all_workspaces:
        where, params = where_clause(None, since_ms)
        rows = conn.execute(GENERATIONS_CTE + f"""
            SELECT CASE WHEN ws = '' THEN '(unattributed)' ELSE ws END AS ws,
                   COUNT(*) AS generations, SUM(i + o) AS total
            FROM gen {where}
            GROUP BY ws ORDER BY total DESC
        """, params).fetchall()
        print("\nEvery workspace on this machine:\n")
        for r in rows:
            print(f"  {human(r['total']):>10}  {r['generations']:>4} gens  {r['ws']}")
        print()
        return 0

    m = measure(conn, workspace, since_ms)

    if args.json:
        print(json.dumps(m, indent=2))
    else:
        window = f"last {args.days} days" if args.days else "all recorded history"
        print(f"\nWorkspace : {workspace}")
        print(f"Window    : {window}"
              + (f"  ({m['first_day']} to {m['last_day']})" if m["first_day"] else ""))
        if not m["generations"]:
            print("\nNo generations recorded for this workspace.\n")
            return 0
        pct = (100 * m["cache_read"] / m["input"]) if m["input"] else 0
        print(f"\n  generations           {m['generations']:>14,}")
        print(f"  input                 {m['input']:>14,}   {human(m['input'])}")
        print(f"    of which cache read {m['cache_read']:>14,}   {pct:.1f}% re-read context")
        print(f"    of which cache write{m['cache_write']:>14,}")
        print(f"    genuinely fresh     {m['fresh_input']:>14,}")
        print(f"  output                {m['output']:>14,}")
        print(f"  {'-'*46}")
        print(f"  excluding cache read  {m['excluding_cache_read']:>14,}   tracks cost")
        print(f"  TOTAL  input + output {m['total']:>14,}   {human(m['total'])}")
        print(f"  per generation        {m['tokens_per_generation']:>14,}   "
              f"{human(m['tokens_per_generation'])} of context")
        if m["by_day"]:
            print("\n  by day")
            for r in m["by_day"]:
                print(f"    {r['day']}  {r['generations']:>3} gens  {human(r['total']):>9}"
                      f"   excl cache read {human(r['excluding_cache_read']):>9}")
        print()

    if args.write:
        found = trackers(root)
        if not found:
            print(f"No progress-tracker.json under {root} - nothing written.")
            return 0
        for p in found:
            write_block(p, workspace, args.days, m)
            print(f"  wrote measured_token_consumption to {p.relative_to(root)}")
        print("Commit to publish (the pre-commit hook syncs the dashboards).")

    return 0


if __name__ == "__main__":
    sys.exit(main())
