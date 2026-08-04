---
name: speckit-dashboard
description: Generate and manage the project progress dashboard with Jira sync, token tracking, and GitHub Pages publishing.
argument-hint: Optional: sync target or leave blank
version: 1.1.0
---

# SpecKit Dashboard

Generate and manage the project progress tracking dashboard.

## ⚠️ Single source of truth: `progress-tracker.json`

The dashboard (`progress-dashboard.html`) is **100% data-driven** — every value (summary
stats, charts, contributors, epics, stories, token sessions) is rendered at runtime from
JSON. **Never hand-edit numbers in the HTML.** Only edit `docs/progress-tracker.json`.

The HTML reads data in two ways:
1. **Live:** `fetch('./progress-tracker.json')` — used on GitHub Pages / any http server.
2. **Offline fallback:** an embedded `<script id="embedded-data">` JSON island — used when
   the file is opened directly via `file://` (where `fetch` is blocked by the browser).

### MANDATORY final step after ANY tracker change

Whenever you modify `docs/progress-tracker.json` (sync from Jira, mark a story built, add a
contributor, log token sessions, add an epic), you MUST regenerate the embedded fallback so
the offline view never goes stale:

```bash
python3 .specify/scripts/sync-dashboard-data.py
```

This copies `progress-tracker.json` into the embedded island of every
`progress-dashboard.html` in the project (skips `.sk-test`). Do this **before** committing.
Do not consider a dashboard update complete until this script has run.

### Fully automatic: sync on commit (recommended)

Token/progress data lives **only** in `progress-tracker.json` and is edited locally as you
work. A git `pre-commit` hook then keeps the shared dashboard in sync with zero manual steps:

- On every `git commit`, the hook runs `sync-dashboard-data.py` and folds the refreshed
  `progress-dashboard.html` into the **same commit**.
- `git push` then shares it — teammates see it on their next page refresh (GitHub Pages
  live-fetches `progress-tracker.json`).

Enable once per clone (also done automatically by `setup-dashboard.sh`):

```bash
git config core.hooksPath .githooks
```

The hook lives at `.githooks/pre-commit` (committed, so it travels with the repo) and is
non-fatal — if `python3` is unavailable the commit still succeeds.

**Your only job:** edit `progress-tracker.json`, then `git commit` + `git push`. Everything
else is automatic.

### One-step publish (sync + commit + push)

To sync the embedded data and push in a single step, use the publish helper:

```bash
bash .specify/scripts/publish-dashboard.sh ["optional commit message"]
```

It runs `sync-dashboard-data.py`, stages every `progress-tracker.json` /
`progress-dashboard.html`, commits, and pushes. On GitHub Pages the dashboard refreshes
automatically after the push.

## Commands

### `/speckit-dashboard`

Generate or update the progress dashboard.

**Usage:**
```
/speckit-dashboard              # Generate full dashboard
/speckit-dashboard sync         # Sync from Jira
/speckit-dashboard add-epic     # Add new epic to tracker
/speckit-dashboard add-contrib  # Add contributor
```

## Dashboard Features

1. **Overview Tab** - Summary stats, progress bars, charts
2. **Built Stories Tab** - What's deployed to Salesforce org
3. **Contributors Tab** - Multi-person token tracking
4. **Epics & Stories Tab** - Full story list by epic
5. **Token Details Tab** - Session-level breakdown

## File Locations

| File | Location | Purpose |
|------|----------|---------|
| Dashboard HTML | `docs/progress-dashboard.html` | GitHub Pages UI |
| Tracker JSON | `docs/progress-tracker.json` | Data source |
| Template | `.specify/templates/progress-tracker-template.json` | Initial setup |

## Workflow

### Initial Setup

1. Run setup script:
   ```bash
   bash .specify/scripts/bash/setup-dashboard.sh
   ```

2. Generate dashboard:
   ```
   /speckit-dashboard
   ```

3. Configure GitHub Pages:
   - Repository Settings → Pages
   - Source: `main` branch, `/docs` folder

### Syncing from Jira

When stories change status in Jira:

```
/speckit-dashboard sync
```

Or tell the agent:
- "Sync dashboard from Jira"
- "Mark PR1070767-24 as built"
- "Update progress tracker"

### Adding Contributors

When a new team member starts working:

```json
{
  "id": "john",
  "name": "John Doe",
  "role": "Developer",
  "total_tokens": 0,
  "sessions_count": 0
}
```

### Adding Token Sessions

Each entry in `token_consumption.by_epic[].sessions` looks like:

```json
{
  "date": "2026-06-12",
  "contributor": "john",
  "activity": "Implemented US1: KPI Header Bar",
  "story": "PR1070767-38",
  "tokens": 4520
}
```

`story` is optional; when present the dashboard shows a badge next to the activity
so tokens can be traced to an individual story, not just the epic.

### Measured tokens from Devbar (workspace-scoped)

Everything under `token_consumption` is an *estimate* derived from artifact
volume. If Devbar is installed, the real numbers can be metered instead:

```bash
python3 .specify/scripts/devbar-tokens.py            # report this workspace
python3 .specify/scripts/devbar-tokens.py --days 7   # last 7 days
python3 .specify/scripts/devbar-tokens.py --write    # write into progress-tracker.json
python3 .specify/scripts/devbar-tokens.py --all-workspaces
```

This reads `~/.devbar/plugins/ai-analytics/events.db` read-only and writes a
separate `measured_token_consumption` block. It never touches the estimates,
because the two differ by roughly two orders of magnitude and averaging them
would be meaningless.

**Scoped to one workspace.** Devbar's own dashboard reports the whole machine,
which mixes every customer together. The script filters on the workspace path —
the git root by default — so a project's dashboard only ever contains that
project's work. `--all-workspaces` shows the split, and the parts sum to
Devbar's machine total.

**The formula**, mirroring Devbar's own aggregation. Events within one
generation carry *running cumulative* token counts, so a generation's value is
the `MAX` of its rows, not the sum — summing rows directly roughly doubles the
answer:

```
per generation:  i = MAX(input_tokens)    o  = MAX(output_tokens)
                cr = MAX(cache_read)      cw = MAX(cache_write)

total                 = SUM(i + o + cr + cw)      over generations
tokens per generation = SUM(i + cr) / COUNT(*)    output excluded, as Devbar defines it
```

Filtering happens *after* grouping so a generation is never split. `cache_read`
is context re-read on every model call inside a turn and dominates the total, so
`excluding_cache_read` is reported alongside as the figure that tracks cost more
closely.

Coverage starts when Devbar was installed, so earlier work is absent and this
cannot backfill history. It also sees only the local machine, so other
contributors' work is not included.

### Per-prompt logging (recommended — tightest numbers)

Instead of one big round estimate at the end, log **per meaningful turn** with the
helper. It appends a session and recomputes every rollup (epic / contributor /
summary) in all tracker files, so totals always reconcile.

```bash
# explicit estimate for this turn
python3 scripts/log-session.py --epic EPIC-004 --contributor praveen \
    --activity "US1 quoteBuilder LWC scaffold" --tokens 4280

# attribute to a story
python3 scripts/log-session.py --epic EPIC-004 --story PR1070767-38 \
    --contributor praveen --activity "US1 catalog search" --tokens 3120

# let the volume produced this turn drive the estimate
python3 scripts/log-session.py --epic EPIC-004 --contributor praveen \
    --activity "pricing service" --from-files force-app/main/default/classes/QuotePricingService.cls
```

Estimation rule when `--tokens` is omitted: `tokens = round(chars / 3.8 × overhead)`,
default `overhead = 5.7` (override with `--overhead`). After logging, commit — the
pre-commit hook syncs the embedded dashboard data automatically.

> Bulk re-derivation: `scripts/reestimate-tokens.py` recomputes all epic targets
> from artifact size in one pass; tune its `OVERHEAD` constant to shift the grand
> total (e.g. raise it if totals should sit closer to a known reference).

### Attributing tokens to test-case work

When the session is test-case work (generating `test-cases.md`, Apex/Jest specs),
tag it so the dashboard's **Test Cases** tab can show tokens spent on testing:

```bash
python3 scripts/log-session.py --epic EPIC-001 --story PR-001-TESTS \
    --contributor praveen --category testcases \
    --activity "US7/US9 Jest specs + Apex tests" --tokens 9548
```

`--category testcases` (or a story key containing `TEST`) makes
`sync-testcases-data.py` roll those tokens into `test_cases.totals.tokens` and the
per-epic Tokens column.

## Test Cases view (data-driven)

The dashboard's **Test Cases** tab is 100% derived from the repo — never hardcoded:

- Per epic: unique `TC-` (manual/UAT) and `AT-` (automated) ids parsed from each
  epic's `specs/<feature>/test-cases.md`, plus test-tagged token sessions.
- Repo-wide automated suite: `*Test.cls` classes + `static void` methods, and
  `__tests__/*.test.js` specs + `it(`/`test(` blocks.

Refresh after adding/editing test cases or test files:

```bash
python3 scripts/sync-testcases-data.py        # writes test_cases block into trackers
python3 scripts/sync-dashboard-data.py        # folds JSON into the embedded island
```

Both run automatically on `git commit` via the pre-commit hook. Epics without a
`test-cases.md` show "— not generated" until you run `/speckit-testcases` for them.

## Jira Integration

### Option 1: Manual Sync (No Admin Required)

Tell the agent: "Sync from Jira"

### Option 2: Automated Webhook (Requires Jira Admin)

See `docs/jira-integration.md` for setup instructions.

**Jira Automation Rule:**
- Trigger: Issue transitioned
- Action: Send webhook to GitHub
- Updates dashboard automatically

### Status Mapping

| Jira Status | Dashboard Status |
|-------------|------------------|
| Open / To Do | `pending` |
| In Progress | `in-progress` |
| In Review / QA | `in-review` |
| Done / Closed | `built` |

## Dashboard Generation

The agent will:

1. Query Jira for all epics and stories
2. Extract status, priority, and metadata
3. Calculate token consumption totals
4. Update `progress-tracker.json` (the only file that holds data)
5. Run `python3 .specify/scripts/sync-dashboard-data.py` to refresh the embedded fallback
6. Commit and push to GitHub (`progress-tracker.json` + `progress-dashboard.html`)

> Steps 5 + 6 can be done in one shot with `bash .specify/scripts/publish-dashboard.sh`.
> Step 4 alone is enough for the live GitHub Pages dashboard. Step 5 is required so the
> dashboard also shows correct data when opened locally as a file.

## Customization

### Adding Custom Metrics

Edit `progress-tracker.json` to add project-specific tracking:

```json
{
  "custom_metrics": {
    "code_coverage": 0,
    "test_cases_passed": 0,
    "deployment_count": 0
  }
}
```

### Styling

The dashboard uses CSS variables. Override in the HTML:

```css
:root {
  --accent-blue: #58a6ff;
  --accent-green: #3fb950;
}
```

## Troubleshooting

### GitHub Pages 404
- Ensure `docs/` folder exists at repo root (not inside subdirectory)
- Check Pages settings: source = `main`, folder = `/docs`

### Jira Sync Fails
- Verify Jira project key is correct
- Check MCP authentication status

### Dashboard Not Updating
- Run `/speckit-dashboard sync` to force refresh
- Check `progress-tracker.json` for data integrity
- **Opened as a file and still see old numbers?** The embedded fallback is stale. Run
  `python3 .specify/scripts/sync-dashboard-data.py`, then hard-refresh (Cmd+Shift+R).
- **Viewing on GitHub Pages and see old numbers?** Hard-refresh; Pages caches briefly.

### Values look hardcoded / won't change
- They are not. All display values render from `progress-tracker.json`. If you edited the
  HTML directly, your changes will be overwritten on load — edit the JSON instead.
