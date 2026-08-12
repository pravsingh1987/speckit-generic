#!/usr/bin/env bash
#
# Activate the dashboard auto-sync pre-commit hook in this repository.
#
# The dashboard is only trustworthy if it refreshes itself. Without this hook you
# edit docs/progress-tracker.json, commit, and the published dashboard still shows
# the previous state — which is worse than being obviously stale, because it looks
# current. The hook regenerates each dashboard's embedded data from its sibling
# tracker and stages the result into the same commit.
#
# The alternative is 'git config core.hooksPath .githooks', but that replaces the
# hook directory wholesale and silently disables anything already in .git/hooks/
# (Husky, pre-commit.com, a linter). This script copies the hook instead, so other
# hook mechanisms keep working.
#
#   bash .specify/scripts/install-hooks.sh
#   bash .specify/scripts/install-hooks.sh --force   # overwrite a different hook
#
set -euo pipefail

FORCE=0
[[ "${1:-}" == "--force" ]] && FORCE=1

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "Not a git repository — run 'git init' first, then re-run this." >&2
    exit 1
}
GITDIR="$(git rev-parse --git-common-dir 2>/dev/null || git rev-parse --git-dir)"
[[ "$GITDIR" = /* ]] || GITDIR="$ROOT/$GITDIR"
DST="$GITDIR/hooks/pre-commit"

# Installed projects get the hook under .specify/hooks/; the toolkit's own repo
# keeps it at .githooks/. Accept either so this works in both places.
SRC=""
for cand in "$ROOT/.specify/hooks/pre-commit" "$ROOT/.githooks/pre-commit"; do
    [[ -f "$cand" ]] && { SRC="$cand"; break; }
done
[[ -n "$SRC" ]] || {
    echo "Hook source missing — looked for:" >&2
    echo "  $ROOT/.specify/hooks/pre-commit" >&2
    echo "  $ROOT/.githooks/pre-commit" >&2
    exit 1
}
mkdir -p "$(dirname "$DST")"

if [[ -f "$DST" ]] && ! cmp -s "$SRC" "$DST"; then
    if [[ $FORCE -eq 0 ]]; then
        echo "A different pre-commit hook already exists:"
        echo "  $DST"
        echo ""
        echo "Not overwriting it. Either:"
        echo "  • merge the two by hand — the toolkit's hook is at $SRC, and it is"
        echo "    safe to append: it exits 0 whenever python3 or the sync scripts are absent"
        echo "  • or re-run with --force to replace yours"
        exit 1
    fi
    cp "$DST" "$DST.replaced-by-speckit"
    echo "  existing hook backed up to $(basename "$DST").replaced-by-speckit"
fi

cp "$SRC" "$DST"
chmod +x "$DST"
echo "✓ pre-commit hook installed at ${DST#$ROOT/}"
echo ""
echo "It runs on every commit and is non-fatal — if python3 is missing the commit"
echo "proceeds normally. Test it with:"
echo "  touch docs/progress-tracker.json && git add -A && git commit -m 'test hook'"
