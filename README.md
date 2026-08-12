# SpecKit Salesforce - Development Accelerator

A comprehensive specification and progress tracking kit for Salesforce development projects. Built for Cursor IDE with AI-powered workflow automation.

## Features

- **Intent-Driven Specs** - Generate detailed specifications from high-level objectives
- **Automated Planning** - Research, data models, Apex contracts, task breakdown
- **Progress Dashboard** - GitHub Pages dashboard with real-time tracking
- **Jira Integration** - Sync story status automatically
- **Token Tracking** - Monitor AI consumption per contributor
- **Multi-Epic Support** - Manage complex projects with multiple workstreams
- **Wireframe Generation** - SLDS-aligned UI mockups for customer sign-off
- **Constitution Governance** - Enforce architectural principles and coding standards

## How It Works

For a plain-English, leadership-friendly overview of the full pipeline (transcript → spec → wireframe → plan → tasks → test cases → deployed code), open [`docs/SpecKit-How-It-Works.html`](docs/SpecKit-How-It-Works.html) in a browser. Note: this is a local HTML page, not a hosted link.

## Quick Install

Cursor loads agent skills **per project** (from `<project>/.cursor/skills/`), so you install SpecKit into each project you want to use it in. The one-liner below does that in one step.

**Run it from inside your project folder**, in a **real terminal** — not inside an AI agent's chat sandbox. Good options:

- **Cursor:** menu **File → New Terminal**
- **Claude / Claude Code:** its built-in terminal
- Or the plain **macOS Terminal** app

![Open a new terminal in Cursor: File → New Terminal](docs/assets/cursor-new-terminal.png)

### Fastest — one-shot install (no git clone, no typing)

Paste this into a terminal opened in your project folder. It reads the published release manifest, downloads the latest release zip from GitHub, extracts it, and installs SpecKit into the **current project** non-interactively (sensible defaults — customize later in `.specify/memory/`):

```bash
python3 - <<'PY'
import json, urllib.request, os, zipfile, subprocess
manifest_url = "https://github.com/pravsingh1987/speckit-salesforce/raw/refs/heads/main/latest-release.json"
manifest = json.load(urllib.request.urlopen(manifest_url))
zip_url = manifest["download_url"]
zip_name = zip_url.split("/")[-1]
folder = zip_name[:-4]
urllib.request.urlretrieve(zip_url, zip_name)
with zipfile.ZipFile(zip_name) as zf:
    zf.extractall(".")
subprocess.check_call(["bash", os.path.join(folder, "install.sh"), ".", "--yes"])
print("SpecKit installed into the current project.")
PY
```

Only `python3` and `bash` are required (both preinstalled on macOS/Linux). No `git clone`, no wizard prompts. This mirrors the manifest-driven installer used by the SF Audit Tool.

### Install / add to a project (git clone)

```bash
git clone https://github.com/pravsingh1987/speckit-salesforce.git ~/.speckit-salesforce 2>/dev/null; bash ~/.speckit-salesforce/install.sh .
```

### Update an installed project to the latest

```bash
git -C ~/.speckit-salesforce pull -q; bash ~/.speckit-salesforce/update.sh .
```

### Alternative — pip install (Python CLI)

```bash
pip install git+https://github.com/pravsingh1987/speckit-salesforce.git
speckit init ./my-project
```

### After install

The one-liner caches the package at `~/.speckit-salesforce` and copies the skills, always-on Cursor rules (`.cursor/rules/` — grounding guardrails, wireframe anatomy, dashboard enforcement), `.specify/`, and `docs/` into your current project. Then:

1. **Reload Cursor** (Cmd+Shift+P → "Reload Window")
2. All `/speckit-*` commands now work in this project
3. Verify what landed:

```bash
ls .cursor/skills   # 14 speckit-* commands
ls .cursor/rules    # dashboard-enforcement.md, grounding-guardrails.mdc, wireframe-salesforce-anatomy.mdc
```

> **Why per-project?** Unlike Claude Code (which has a global `~/.claude/skills/`), Cursor reads skills from each project's `.cursor/skills/` folder. There is no global skills directory in Cursor, so each project needs its own copy. The one-liner makes that a single command.

### Adding SpecKit to Another Project

The package is already cached (from whichever track you installed), so this is instant — it uses the cache, no remote URL needed:

```bash
cd ~/another-project
bash ~/.speckit-salesforce/install.sh .
```

See `INSTALLATION_GUIDE.md` for complete setup instructions.

## What's Included

### Agent Skills (14 Commands)

| Command | Description |
|---------|-------------|
| `/speckit-init` | Scaffold SpecKit structure and memory files |
| `/speckit-specify` | Generate specification from objective |
| `/speckit-clarify` | Refine ambiguous requirements |
| `/speckit-plan` | Create implementation plan with research |
| `/speckit-tasks` | Break down into actionable tasks |
| `/speckit-analyze` | Validate spec completeness |
| `/speckit-wireframe` | Create SLDS-aligned UI wireframes |
| `/speckit-testcases` | Generate test cases from the specification |
| `/speckit-checklist` | Generate requirement checklists |
| `/speckit-implement` | Execute task implementation |
| `/speckit-dashboard` | Manage progress dashboard |
| `/speckit-constitution` | Validate against governance principles |
| `/speckit-taskstoissues` | Export tasks to Jira |
| `/speckit-agent-context-update` | Update agent context |

### Memory Files (Project Context)

Files in `.specify/memory/` are **automatically consulted** by all commands:

| File | Purpose |
|------|---------|
| `constitution.md` | Governance principles, coding standards |
| `project-details.md` | Project info, stakeholders, timelines |
| `taxonomy.md` | Naming conventions, glossary, acronyms |
| `domain.md` | Industry knowledge, business processes |
| `regulatory.md` | Compliance requirements, data classification |

### Templates

| Template | Output |
|----------|--------|
| `spec-template.md` | Feature specifications with user stories |
| `plan-template.md` | Implementation plans with constitution check |
| `tasks-template.md` | Task breakdown organized by user story |
| `checklist-template.md` | Requirement checklists |
| `progress-tracker-template.json` | Dashboard data structure |

### Progress Dashboard

- Overview with KPIs and charts
- Built stories tracking
- Multi-contributor token consumption
- Epic & story management
- Jira status sync
- GitHub Pages ready

<!-- speckit-extras:start -->
### Toolkit Scripts

Four scripts in `.specify/scripts/` cover the jobs the skills alone cannot do. The first two
run on demand; the last two are one-time setup.

| Script | What it does |
|--------|--------------|
| `devbar-tokens.py` | Reports **measured** token usage from Devbar's local database, scoped to a single workspace so separate clients are never mixed into one figure. Without it the dashboard shows estimates only. |
| `spec_docx_kit.py` | Generates Word specifications with a contents page that navigates to real content and carries page numbers, so client-facing documents are regenerated from source instead of hand-edited. Needs `pip install python-docx`. |
| `install-hooks.sh` | Activates the dashboard's auto-refresh pre-commit hook. |
| `hooks/pre-commit` | The hook itself: regenerates each dashboard's embedded data from its sibling `progress-tracker.json` and stages the result into the same commit. |

#### Activate the dashboard hook

The dashboard is only trustworthy if it refreshes itself. Skip this and you will edit
`progress-tracker.json`, commit, and the published dashboard will still show the previous
state — which is worse than being visibly stale, because it looks current.

```bash
bash .specify/scripts/install-hooks.sh
```

Confirm it took effect:

```bash
git commit --allow-empty -m "hook check" && git show --stat HEAD
```

`progress-dashboard.html` should appear in that commit. The hook is non-fatal, so a missing
`python3` will never block a commit.

There is a second route — `git config core.hooksPath .githooks` — but it replaces the hook
directory wholesale, which silently stops any hook already in `.git/hooks/` from firing,
including ones installed by Husky, pre-commit.com or a linter. `install-hooks.sh` copies the
hook instead, leaves `core.hooksPath` alone, and refuses to overwrite a different existing
hook unless passed `--force`.

#### Measuring tokens

```bash
python3 .specify/scripts/devbar-tokens.py                    # this workspace
python3 .specify/scripts/devbar-tokens.py --all-workspaces   # the per-project split
```

Totals are `SUM(i + o)` per generation. `cache_read` and `cache_write` are a *breakdown* of
`input_tokens`, not additions to it, so adding all four counts cached context three times and
roughly doubles the figure. Coverage begins when Devbar was installed and only sees the local
machine, so it cannot backfill history or include other contributors' work.
<!-- speckit-extras:end -->

## Usage Workflow

### Recommended Order

```
1. /speckit-specify     → Create spec from requirements
2. /speckit-wireframe   → Generate wireframes (get sign-off!)
3. /speckit-analyze     → Validate spec completeness  
4. /speckit-plan        → Generate technical plan
5. /speckit-tasks       → Break into tasks
6. /speckit-implement   → Build the solution
7. /speckit-dashboard   → Track progress
```

### 1. Initialize a New Feature

```
/speckit-specify -EPIC "Feature Name" 
Objective: what you want to achieve
Primary users: who will use it
Core objects: Salesforce objects involved

[Optionally include:]
- Meeting transcripts
- Recording summaries
- Wireframe descriptions
- Requirements documents
- Discussion notes
```

### 2. Generate Wireframes (Recommended)

```
/speckit-wireframe  # Generates SLDS-aligned visual mockups
```

Creates `wireframes.md` with screen inventory, Figma links, and sign-off checklist.

> ⚠️ **Best Practice**: Get stakeholder sign-off on wireframes before proceeding to plan.

### 3. Validate Specification

```
/speckit-analyze  # Returns PASS/FAIL with recommendations
```

### 4. Generate Plan & Tasks

```
/speckit-plan    # Creates research, data model, Apex contracts
/speckit-tasks   # Breaks down into implementable tasks
```

### 5. Implement

```
/speckit-implement  # Execute tasks with guidance
```

### 6. Track Progress

```
/speckit-dashboard        # Generate/update dashboard
/speckit-dashboard sync   # Sync from Jira
```

## Project Structure

After installation:

```
your-project/
├── .cursor/
│   ├── skills/                    # Agent skills (14 commands)
│   └── rules/                     # Always-on guardrails
│       ├── grounding-guardrails.mdc        ← READ-FIRST memory/grounding mandate
│       ├── wireframe-salesforce-anatomy.mdc ← Lightning record-page anatomy for wireframes
│       └── dashboard-enforcement.md        ← Prompt to update dashboard after work
├── .specify/
│   ├── templates/                 # Document templates
│   ├── scripts/                   # Setup scripts
│   ├── memory/                    # Project context
│   │   ├── constitution.md        ← Governance principles
│   │   ├── project-details.md     ← Project info
│   │   ├── taxonomy.md            ← Naming conventions
│   │   ├── domain.md              ← Industry knowledge
│   │   └── regulatory.md          ← Compliance rules
│   └── integrations/
├── docs/                          # GitHub Pages
│   ├── progress-dashboard.html
│   └── progress-tracker.json
├── sample-constitution.md         # Customizable template
└── specs/                         # Your specifications
    └── 001-feature-name/
        ├── spec.md
        ├── plan.md
        ├── tasks.md
        ├── wireframes.md
        └── data-model.md
```

## Configuration

### Required Settings

| Setting | Description | Example |
|---------|-------------|---------|
| `name` | Your project name | "Customer Portal" |
| `salesforce_org` | SF org alias | "devhub" |

### Optional Settings (Recommended)

| Setting | Description | Example |
|---------|-------------|---------|
| `github_repo` | Full GitHub URL | `https://github.com/myorg/myrepo` |
| `jira_project` | Jira project key | `PORTAL-123` |
| `jira_url` | Jira board URL | `https://mycompany.atlassian.net/...` |

### GitHub Pages Setup

1. Push your code to GitHub
2. Go to: `Settings → Pages`
3. Source: `main` branch, `/docs` folder
4. Your dashboard URL: `https://<org>.github.io/<repo>/progress-dashboard.html`

### Jira Integration

For automatic story sync, see `docs/jira-integration.md`:
- **Manual sync**: Tell agent "Sync from Jira"
- **Automated**: Set up Jira webhook (requires admin)

## Salesforce PS Audit Tool Integration

The constitution references the Salesforce PS Audit Tool for code validation:

```bash
# Run audit
cd ~/Documents/Sf\ PS\ Audit\ Tool/salesforce-audit-tool-v1.2.17
python3 salesforce_audit.py --sfdx my-org
```

See `INSTALLATION_GUIDE.md` for complete audit tool setup.

## Requirements

- Cursor IDE with agent mode enabled
- Git repository
- Jira project (optional)
- GitHub Pages (optional)
- Salesforce CLI (for deployment)

## Documentation

- **Installation Guide**: `INSTALLATION_GUIDE.md`
- **Jira Integration**: `docs/jira-integration.md`
- **Dashboard Guide**: `docs/README.md`
- **Skill Details**: `.cursor/skills/speckit-*/SKILL.md`

## Support

For issues or enhancements, contact your SpecKit administrator.

## Version

- **SpecKit Salesforce**: 1.2.0
- **Based on**: SpecKit 0.10.1
