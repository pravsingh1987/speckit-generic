#!/bin/bash
# SpecKit Salesforce Installer
# Guided installation with step-by-step configuration

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ═══════════════════════════════════════════════════════════════════════════════
# BANNER
# ═══════════════════════════════════════════════════════════════════════════════
clear 2>/dev/null || true
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║        ${BOLD}SpecKit - Salesforce Development Accelerator${NC}${CYAN}           ║${NC}"
echo -e "${CYAN}║                    Salesforce Edition v1.1                     ║${NC}"
echo -e "${CYAN}╠════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║   This installer will guide you through:                       ║${NC}"
echo -e "${CYAN}║   ${BOLD}Step 1${NC}${CYAN} → Constitution Setup (governance & standards)         ║${NC}"
echo -e "${CYAN}║   ${BOLD}Step 2${NC}${CYAN} → Memory Files (project context)                      ║${NC}"
echo -e "${CYAN}║   ${BOLD}Step 3${NC}${CYAN} → Templates & Extensions                              ║${NC}"
echo -e "${CYAN}║   ${BOLD}Step 4${NC}${CYAN} → Integrations (GitHub, Jira)                         ║${NC}"
echo -e "${CYAN}║   ${BOLD}Step 5${NC}${CYAN} → Contributor Setup                                   ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# ARGUMENTS & MODE
#   Usage: install.sh [target-dir] [-y|--yes]
#   Non-interactive mode is used when -y/--yes is passed OR stdin is not a TTY
#   (e.g. when run from the one-line manifest installer). It accepts sensible
#   defaults for every prompt so the whole install runs without any typing.
# ═══════════════════════════════════════════════════════════════════════════════
ASSUME_YES=0
TARGET_ARG=""
for arg in "$@"; do
    case "$arg" in
        -y|--yes|--non-interactive) ASSUME_YES=1 ;;
        *) [ -z "$TARGET_ARG" ] && TARGET_ARG="$arg" ;;
    esac
done

if [ "$ASSUME_YES" = "1" ] || [ ! -t 0 ]; then
    NONINTERACTIVE=1
else
    NONINTERACTIVE=0
fi

# ───────────────────────────────────────────────────────────────────────────────
# TARGET DIRECTORY
# ───────────────────────────────────────────────────────────────────────────────
if [ -n "$TARGET_ARG" ]; then
    TARGET_DIR="$TARGET_ARG"
elif [ "$NONINTERACTIVE" = "1" ]; then
    TARGET_DIR="."
else
    echo -e "${BLUE}Where would you like to install SpecKit?${NC}"
    read -p "Target directory (. for current): " TARGET_DIR
    TARGET_DIR="${TARGET_DIR:-.}"
fi

[ "$TARGET_DIR" = "." ] && TARGET_DIR="$(pwd)" || { mkdir -p "$TARGET_DIR" 2>/dev/null; TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"; }

echo ""
echo -e "${BLUE}📁 Install location: ${BOLD}$TARGET_DIR${NC}"
echo ""
if [ "$NONINTERACTIVE" = "1" ]; then
    echo -e "${DIM}Non-interactive install — using defaults (customize later in .specify/memory/).${NC}"
else
    read -p "Proceed with installation? (Y/n): " CONFIRM
    [[ ! "${CONFIRM:-Y}" =~ ^[Yy]$ ]] && echo "Cancelled." && exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════════
# COPY FILES
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${BLUE}📦 Installing SpecKit components...${NC}"

# Each copy is checked independently so failures are loud (not hidden by && chains)
cp -r "$SCRIPT_DIR/.specify" "$TARGET_DIR/"
echo -e "  ${GREEN}✓${NC} SpecKit core (.specify)"

# Agent skills — critical. Verify they actually landed.
# Install for both Cursor (.cursor/skills) and Claude Code (.claude/skills)
mkdir -p "$TARGET_DIR/.cursor"
cp -r "$SCRIPT_DIR/.cursor/skills" "$TARGET_DIR/.cursor/"
SKILL_COUNT=$(ls "$TARGET_DIR/.cursor/skills" 2>/dev/null | wc -l | tr -d ' ')
if [ "$SKILL_COUNT" -lt 1 ]; then
    echo -e "  ${RED}✗ ERROR: Agent skills failed to copy into .cursor/skills${NC}"
    echo -e "  ${YELLOW}If you are running this inside an AI agent/sandbox, run it in a normal terminal instead.${NC}"
    exit 1
fi
echo -e "  ${GREEN}✓${NC} Cursor agent skills ($SKILL_COUNT commands)"

# Claude Code skills
if [ -d "$SCRIPT_DIR/.claude/skills" ]; then
    mkdir -p "$TARGET_DIR/.claude"
    cp -r "$SCRIPT_DIR/.claude/skills" "$TARGET_DIR/.claude/"
    echo -e "  ${GREEN}✓${NC} Claude Code agent skills ($SKILL_COUNT commands)"
fi

# Cursor rules — always-on guardrails (grounding, wireframe anatomy, dashboard enforcement)
if [ -d "$SCRIPT_DIR/.cursor/rules" ]; then
    cp -r "$SCRIPT_DIR/.cursor/rules" "$TARGET_DIR/.cursor/"
    RULE_COUNT=$(ls "$TARGET_DIR/.cursor/rules" 2>/dev/null | wc -l | tr -d ' ')
    echo -e "  ${GREEN}✓${NC} Cursor rules ($RULE_COUNT guardrails)"
fi

cp -r "$SCRIPT_DIR/docs" "$TARGET_DIR/"
echo -e "  ${GREEN}✓${NC} Progress dashboard"

mkdir -p "$TARGET_DIR/specs"
echo -e "  ${GREEN}✓${NC} Specs directory"

cp "$SCRIPT_DIR/sample-constitution.md" "$TARGET_DIR/" 2>/dev/null && echo -e "  ${GREEN}✓${NC} Sample constitution"
find "$TARGET_DIR/.specify/scripts" -name "*.sh" -exec chmod +x {} \; 2>/dev/null
echo -e "  ${GREEN}✓${NC} Files installed"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 1: CONSTITUTION SETUP
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║  ${BOLD}STEP 1 of 5: SALESFORCE CONSTITUTION${NC}${MAGENTA}                         ║${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}The Constitution defines your project's governance rules:${NC}"
echo -e "  • Architectural principles (platform-first, no technical debt)"
echo -e "  • Security standards (user mode, CRUD/FLS, sharing)"
echo -e "  • Governor limits & bulkification rules"
echo -e "  • Code quality standards (trigger patterns, testing)"
echo -e "  • Permission set naming conventions"
echo -e "  • Audit tool configuration"
echo ""
echo -e "${DIM}Location: .specify/memory/constitution.md${NC}"
echo ""

echo -e "${BLUE}Would you like to customize the constitution now?${NC}"
echo -e "  ${BOLD}1${NC}) Yes - Open in editor after installation"
echo -e "  ${BOLD}2${NC}) No - Use default (can customize later)"
echo ""
if [ "$NONINTERACTIVE" = "1" ]; then
    CONSTITUTION_CHOICE="2"
else
    read -p "Choice [2]: " CONSTITUTION_CHOICE
    CONSTITUTION_CHOICE="${CONSTITUTION_CHOICE:-2}"
fi

if [ "$CONSTITUTION_CHOICE" = "1" ]; then
    OPEN_CONSTITUTION=true
    echo -e "  ${GREEN}✓${NC} Will open constitution for customization"
else
    OPEN_CONSTITUTION=false
    echo -e "  ${GREEN}✓${NC} Using default constitution"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 2: MEMORY FILES SETUP
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║  ${BOLD}STEP 2 of 5: MEMORY FILES (Project Context)${NC}${MAGENTA}                  ║${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Memory files are automatically consulted by all SpecKit commands:${NC}"
echo ""
echo -e "  ${BOLD}project-details.md${NC} - Stakeholders, timelines, environments"
echo -e "  ${BOLD}taxonomy.md${NC}         - Naming conventions, glossary, acronyms"
echo -e "  ${BOLD}domain.md${NC}           - Industry knowledge, business processes"
echo -e "  ${BOLD}regulatory.md${NC}       - Compliance requirements, data classification"
echo ""
echo -e "${DIM}Location: .specify/memory/${NC}"
echo ""

# Project Name (required for memory files)
if [ "$NONINTERACTIVE" = "1" ]; then
    PROJECT_NAME="$(basename "$TARGET_DIR")"
    echo -e "  ${GREEN}✓${NC} Project name: $PROJECT_NAME ${DIM}(folder name; change in project-details.md)${NC}"
else
    while [ -z "$PROJECT_NAME" ]; do
        read -p "$(echo -e ${BOLD}Project Name${NC} [required]: )" PROJECT_NAME
        [ -z "$PROJECT_NAME" ] && echo -e "${RED}  Project name is required${NC}"
    done
fi

# Salesforce Org Alias
if [ "$NONINTERACTIVE" = "1" ]; then
    SF_ORG="default"
else
    read -p "$(echo -e ${BOLD}Salesforce Org Alias${NC} [e.g., my-dev-org]: )" SF_ORG
    SF_ORG="${SF_ORG:-default}"
fi

# Industry/Domain
echo ""
echo -e "${BLUE}What industry/domain is this project for?${NC}"
echo -e "  ${BOLD}1${NC}) Healthcare / Life Sciences / Pharma"
echo -e "  ${BOLD}2${NC}) Financial Services / Banking / Insurance"
echo -e "  ${BOLD}3${NC}) Manufacturing / Supply Chain"
echo -e "  ${BOLD}4${NC}) Retail / E-commerce"
echo -e "  ${BOLD}5${NC}) Technology / SaaS"
echo -e "  ${BOLD}6${NC}) Other / General"
echo ""
if [ "$NONINTERACTIVE" = "1" ]; then
    INDUSTRY_CHOICE="6"
else
    read -p "Choice [6]: " INDUSTRY_CHOICE
    INDUSTRY_CHOICE="${INDUSTRY_CHOICE:-6}"
fi

case $INDUSTRY_CHOICE in
    1) INDUSTRY="Healthcare / Life Sciences" ;;
    2) INDUSTRY="Financial Services" ;;
    3) INDUSTRY="Manufacturing" ;;
    4) INDUSTRY="Retail" ;;
    5) INDUSTRY="Technology" ;;
    *) INDUSTRY="General" ;;
esac

echo -e "  ${GREEN}✓${NC} Industry: $INDUSTRY"

# Update project-details.md
if [ -f "$TARGET_DIR/.specify/memory/project-details.md" ]; then
    sed -i.bak "s/\[Your Project Name\]/$PROJECT_NAME/g" "$TARGET_DIR/.specify/memory/project-details.md" 2>/dev/null || true
    sed -i.bak "s/\[e.g., my-dev-org\]/$SF_ORG/g" "$TARGET_DIR/.specify/memory/project-details.md" 2>/dev/null || true
    rm -f "$TARGET_DIR/.specify/memory/project-details.md.bak" 2>/dev/null
fi

# Update domain.md
if [ -f "$TARGET_DIR/.specify/memory/domain.md" ]; then
    sed -i.bak "s/\[e.g., Healthcare, Financial Services, Manufacturing, Retail\]/$INDUSTRY/g" "$TARGET_DIR/.specify/memory/domain.md" 2>/dev/null || true
    rm -f "$TARGET_DIR/.specify/memory/domain.md.bak" 2>/dev/null
fi

echo -e "  ${GREEN}✓${NC} Memory files configured"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 3: TEMPLATES & EXTENSIONS
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║  ${BOLD}STEP 3 of 5: TEMPLATES & EXTENSIONS${NC}${MAGENTA}                          ║${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Templates define the output format for SpecKit commands:${NC}"
echo ""
echo -e "  ${BOLD}spec-template.md${NC}    - Feature specifications with user stories"
echo -e "  ${BOLD}plan-template.md${NC}    - Implementation plans with constitution check"
echo -e "  ${BOLD}tasks-template.md${NC}   - Task breakdown organized by user story"
echo -e "  ${BOLD}checklist-template.md${NC} - Requirement checklists"
echo ""
echo -e "${DIM}Location: .specify/templates/${NC}"
echo ""
echo -e "${BLUE}Templates are pre-configured. You can customize them later.${NC}"
echo ""
echo -e "  ${GREEN}✓${NC} Templates ready"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 4: INTEGRATIONS (GitHub, Jira)
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║  ${BOLD}STEP 4 of 5: INTEGRATIONS${NC}${MAGENTA}                                     ║${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# GitHub
echo -e "${BLUE}─── GitHub Configuration ───${NC}"
echo -e "${YELLOW}For dashboard links and GitHub Pages hosting${NC}"
echo -e "${DIM}Example: https://github.com/myorg/my-project${NC}"
echo ""
if [ "$NONINTERACTIVE" = "1" ]; then
    GITHUB_REPO=""
else
    read -p "GitHub Repository URL (press Enter to skip): " GITHUB_REPO
fi

if [ -n "$GITHUB_REPO" ]; then
    echo -e "  ${GREEN}✓${NC} GitHub: $GITHUB_REPO"
    
    # Extract org/repo for Pages URL
    GITHUB_PAGES_URL=$(echo "$GITHUB_REPO" | sed 's|https://github.com/\([^/]*\)/\([^/]*\).*|https://\1.github.io/\2|')
    echo -e "  ${DIM}Dashboard will be at: $GITHUB_PAGES_URL/progress-dashboard.html${NC}"
else
    echo -e "  ${YELLOW}⊘${NC} GitHub skipped (can configure later)"
fi

echo ""

# Jira
echo -e "${BLUE}─── Jira Configuration ───${NC}"
echo -e "${YELLOW}For story status sync and progress tracking${NC}"
echo ""
if [ "$NONINTERACTIVE" = "1" ]; then
    JIRA_KEY=""
else
    read -p "Jira Project Key (e.g., MYPROJ, press Enter to skip): " JIRA_KEY
fi

if [ -n "$JIRA_KEY" ]; then
    echo -e "${DIM}Example: https://company.atlassian.net/jira/software/projects/MYPROJ/boards/1${NC}"
    read -p "Jira Board URL: " JIRA_URL
    echo -e "  ${GREEN}✓${NC} Jira: $JIRA_KEY"
else
    echo -e "  ${YELLOW}⊘${NC} Jira skipped (can configure later)"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 5: CONTRIBUTOR SETUP
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║  ${BOLD}STEP 5 of 5: CONTRIBUTOR SETUP${NC}${MAGENTA}                                ║${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Your information for token tracking and dashboard${NC}"
echo ""

if [ "$NONINTERACTIVE" = "1" ]; then
    CONTRIBUTOR_NAME="$(git config user.name 2>/dev/null || whoami 2>/dev/null || echo Developer)"
    CONTRIBUTOR_ROLE="Developer"
else
    read -p "Your Name: " CONTRIBUTOR_NAME
    CONTRIBUTOR_NAME="${CONTRIBUTOR_NAME:-Developer}"

    read -p "Your Role (e.g., Developer, Architect, Lead): " CONTRIBUTOR_ROLE
    CONTRIBUTOR_ROLE="${CONTRIBUTOR_ROLE:-Developer}"
fi

CONTRIBUTOR_ID=$(echo "$CONTRIBUTOR_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | cut -c1-20)
echo -e "  ${GREEN}✓${NC} Contributor: $CONTRIBUTOR_NAME ($CONTRIBUTOR_ROLE)"

# ═══════════════════════════════════════════════════════════════════════════════
# SAVE CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${BLUE}⚙️  Saving configuration...${NC}"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

cat > "$TARGET_DIR/docs/progress-tracker.json" << EOF
{
  "project": {
    "name": "$PROJECT_NAME",
    "industry": "$INDUSTRY",
    "jira_project": "${JIRA_KEY:-}",
    "jira_url": "${JIRA_URL:-}",
    "github_repo": "${GITHUB_REPO:-}",
    "salesforce_org": "$SF_ORG",
    "last_updated": "$TIMESTAMP"
  },
  "summary": {
    "total_epics": 0,
    "total_stories": 0,
    "stories_built": 0,
    "stories_in_progress": 0,
    "stories_in_review": 0,
    "stories_pending": 0,
    "completion_percentage": 0,
    "total_tokens": 0
  },
  "contributors": [
    {
      "id": "$CONTRIBUTOR_ID",
      "name": "$CONTRIBUTOR_NAME",
      "role": "$CONTRIBUTOR_ROLE",
      "total_tokens": 0,
      "sessions_count": 0
    }
  ],
  "token_consumption": {
    "note": "Token estimates based on conversation session length.",
    "total_estimated_tokens": 0,
    "by_contributor": [],
    "by_epic": []
  },
  "deployment_status": {
    "last_deployment": null,
    "deployed_components": {
      "custom_objects": [],
      "custom_fields": [],
      "apex_classes": [],
      "lwc_components": [],
      "permission_sets": [],
      "flexipages": []
    }
  },
  "epics": []
}
EOF
echo -e "  ${GREEN}✓${NC} Dashboard configuration saved"

# Update constitution with project name
if [ -f "$TARGET_DIR/.specify/memory/constitution.md" ]; then
    sed -i.bak "s/\[YOUR-PROJECT\]/$PROJECT_NAME/g" "$TARGET_DIR/.specify/memory/constitution.md" 2>/dev/null || true
    sed -i.bak "s/\[Your Organization\]/$PROJECT_NAME/g" "$TARGET_DIR/.specify/memory/constitution.md" 2>/dev/null || true
    sed -i.bak "s/\[YOUR-ORG-ALIAS\]/$SF_ORG/g" "$TARGET_DIR/.specify/memory/constitution.md" 2>/dev/null || true
    rm -f "$TARGET_DIR/.specify/memory/constitution.md.bak" 2>/dev/null
    echo -e "  ${GREEN}✓${NC} Constitution updated"
fi

# Git initialization
if [ ! -d "$TARGET_DIR/.git" ] && [ "$NONINTERACTIVE" != "1" ]; then
    echo ""
    read -p "Initialize git repository? (Y/n): " INIT_GIT
    if [[ "${INIT_GIT:-Y}" =~ ^[Yy]$ ]]; then
        cd "$TARGET_DIR" && git init -q
        echo -e "  ${GREEN}✓${NC} Git initialized"
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# COMPLETION
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           ✅ SpecKit Installation Complete!                    ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Project Summary:${NC}"
echo -e "  ${BOLD}Name:${NC}      $PROJECT_NAME"
echo -e "  ${BOLD}Industry:${NC}  $INDUSTRY"
echo -e "  ${BOLD}Location:${NC}  $TARGET_DIR"
echo -e "  ${BOLD}SF Org:${NC}    $SF_ORG"
[ -n "$GITHUB_REPO" ] && echo -e "  ${BOLD}GitHub:${NC}    $GITHUB_REPO"
[ -n "$JIRA_KEY" ] && echo -e "  ${BOLD}Jira:${NC}      $JIRA_KEY"
echo ""

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                      NEXT STEPS                                ║${NC}"
echo -e "${CYAN}╠════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║                                                                ║${NC}"
echo -e "${CYAN}║  ${BOLD}1. Open in Cursor or Claude Code:${NC}${CYAN}                            ║${NC}"
echo -e "${CYAN}║     ${YELLOW}cursor $TARGET_DIR${NC}${CYAN}  ${DIM}or${NC}${CYAN}  ${YELLOW}claude-code $TARGET_DIR${NC}${CYAN}              ║${NC}"
echo -e "${CYAN}║                                                                ║${NC}"
echo -e "${CYAN}║  ${BOLD}2. Review & customize constitution:${NC}${CYAN}                         ║${NC}"
echo -e "${CYAN}║     ${YELLOW}/speckit-constitution${NC}${CYAN}                                    ║${NC}"
echo -e "${CYAN}║                                                                ║${NC}"
echo -e "${CYAN}║  ${BOLD}3. Create your first specification:${NC}${CYAN}                         ║${NC}"
echo -e "${CYAN}║     ${YELLOW}/speckit-specify -EPIC \"Feature Name\"${NC}${CYAN}                    ║${NC}"
echo -e "${CYAN}║     ${YELLOW}Objective: what you want to achieve${NC}${CYAN}                      ║${NC}"
echo -e "${CYAN}║                                                                ║${NC}"
echo -e "${CYAN}║  ${BOLD}4. Generate plan & tasks:${NC}${CYAN}                                   ║${NC}"
echo -e "${CYAN}║     ${YELLOW}/speckit-plan${NC}${CYAN}                                            ║${NC}"
echo -e "${CYAN}║     ${YELLOW}/speckit-tasks${NC}${CYAN}                                           ║${NC}"
echo -e "${CYAN}║                                                                ║${NC}"
if [ -n "$GITHUB_REPO" ]; then
echo -e "${CYAN}║  ${BOLD}5. Enable GitHub Pages:${NC}${CYAN}                                     ║${NC}"
echo -e "${CYAN}║     Repository Settings → Pages → /docs folder                ║${NC}"
echo -e "${CYAN}║                                                                ║${NC}"
fi
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}${BOLD}⚑ FILL THESE IN NEXT — your project grounding (read on every command):${NC}"
echo -e "  ${BOLD}1.${NC} .specify/memory/constitution.md      ${DIM}Governance: architecture, security, governor limits, testing, perm-set naming${NC}"
echo -e "  ${BOLD}2.${NC} .specify/memory/project-details.md   ${DIM}Project name, org alias & API version, connected systems, scope, Jira/repo IDs${NC}"
echo -e "  ${BOLD}3.${NC} .specify/memory/domain.md            ${DIM}Industry, business processes, personas, guiding principles${NC}"
echo -e "  ${BOLD}4.${NC} .specify/memory/taxonomy.md          ${DIM}Canonical naming & terminology (objects, records, roles) used verbatim${NC}"
echo -e "  ${BOLD}5.${NC} .specify/memory/regulatory.md        ${DIM}Compliance & data-governance guardrails${NC}"
echo -e "  ${BOLD}6.${NC} .cursor/rules/wireframe-salesforce-anatomy.mdc  ${DIM}Lightning page anatomy for /speckit-wireframe${NC}"
echo ""
echo -e "${DIM}Anything left as a [PLACEHOLDER] will be flagged by SpecKit instead of assumed.${NC}"
echo -e "${DIM}Guided fill: run /speckit-constitution then /speckit-specify. Full guide: INSTALLATION_GUIDE.md → \"Next Steps\".${NC}"
echo ""

# Open constitution if requested
if [ "$OPEN_CONSTITUTION" = true ]; then
    echo -e "${BLUE}Opening constitution for customization...${NC}"
    if command -v cursor &> /dev/null; then
        cursor "$TARGET_DIR/.specify/memory/constitution.md"
    elif command -v code &> /dev/null; then
        code "$TARGET_DIR/.specify/memory/constitution.md"
    else
        echo -e "${YELLOW}Please open: $TARGET_DIR/.specify/memory/constitution.md${NC}"
    fi
fi

echo -e "${GREEN}Happy building! 🚀${NC}"
echo ""
