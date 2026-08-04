#!/bin/bash
# SpecKit Salesforce - Update Script
# Updates an installed project with the latest SpecKit features
# Preserves project configuration (progress-tracker.json, constitution customizations)

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ═══════════════════════════════════════════════════════════════════════════════
# BANNER
# ═══════════════════════════════════════════════════════════════════════════════
clear
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║        ${BOLD}SpecKit Salesforce - Update Tool${NC}${CYAN}                        ║${NC}"
echo -e "${CYAN}╠════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║   Updates your project with the latest SpecKit features        ║${NC}"
echo -e "${CYAN}║   while preserving your configuration and customizations       ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# TARGET DIRECTORY
# ═══════════════════════════════════════════════════════════════════════════════
if [ -z "$1" ]; then
    echo -e "${BLUE}Which project would you like to update?${NC}"
    read -p "Target directory: " TARGET_DIR
else
    TARGET_DIR="$1"
fi

# Validate target directory
if [ ! -d "$TARGET_DIR" ]; then
    echo -e "${RED}Error: Directory does not exist: $TARGET_DIR${NC}"
    exit 1
fi

TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

# Check if it's a SpecKit project
if [ ! -d "$TARGET_DIR/.specify" ] && [ ! -d "$TARGET_DIR/.cursor/skills" ]; then
    echo -e "${RED}Error: This doesn't appear to be a SpecKit project${NC}"
    echo -e "${DIM}Missing .specify or .cursor/skills directory${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}📁 Project to update: ${BOLD}$TARGET_DIR${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# PULL LATEST FROM GIT (Optional)
# ═══════════════════════════════════════════════════════════════════════════════
echo -e "${BLUE}Would you like to pull the latest SpecKit from GitHub first?${NC}"
read -p "Pull latest? (Y/n): " PULL_LATEST

if [[ "${PULL_LATEST:-Y}" =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${BLUE}📥 Pulling latest SpecKit...${NC}"
    cd "$SCRIPT_DIR"
    if git pull origin main 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} SpecKit source updated"
    else
        echo -e "  ${YELLOW}⚠${NC} Could not pull (offline or no changes)"
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# SELECT WHAT TO UPDATE
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}                    SELECT COMPONENTS TO UPDATE${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${BOLD}1${NC}) All components (recommended)"
echo -e "  ${BOLD}2${NC}) Agent skills only (.cursor/skills/)"
echo -e "  ${BOLD}3${NC}) Templates only (.specify/templates/)"
echo -e "     ${DIM}(option 1 also refreshes .cursor/rules guardrails)${NC}"
echo -e "  ${BOLD}4${NC}) Dashboard only (docs/progress-dashboard.html)"
echo -e "  ${BOLD}5${NC}) Memory file templates only (.specify/memory/)"
echo -e "  ${BOLD}6${NC}) Custom selection"
echo ""
read -p "Choice [1]: " UPDATE_CHOICE
UPDATE_CHOICE="${UPDATE_CHOICE:-1}"

# Initialize update flags
UPDATE_SKILLS=false
UPDATE_TEMPLATES=false
UPDATE_DASHBOARD=false
UPDATE_MEMORY=false
UPDATE_SCRIPTS=false
UPDATE_RULES=false

case $UPDATE_CHOICE in
    1)
        UPDATE_SKILLS=true
        UPDATE_TEMPLATES=true
        UPDATE_DASHBOARD=true
        UPDATE_SCRIPTS=true
        UPDATE_RULES=true
        # Memory templates only if user confirms (to avoid overwriting customizations)
        ;;
    2)
        UPDATE_SKILLS=true
        ;;
    3)
        UPDATE_TEMPLATES=true
        ;;
    4)
        UPDATE_DASHBOARD=true
        ;;
    5)
        UPDATE_MEMORY=true
        ;;
    6)
        echo ""
        read -p "Update agent skills? (Y/n): " ans && [[ "${ans:-Y}" =~ ^[Yy]$ ]] && UPDATE_SKILLS=true
        read -p "Update templates? (Y/n): " ans && [[ "${ans:-Y}" =~ ^[Yy]$ ]] && UPDATE_TEMPLATES=true
        read -p "Update dashboard? (Y/n): " ans && [[ "${ans:-Y}" =~ ^[Yy]$ ]] && UPDATE_DASHBOARD=true
        read -p "Update scripts? (Y/n): " ans && [[ "${ans:-Y}" =~ ^[Yy]$ ]] && UPDATE_SCRIPTS=true
        read -p "Update Cursor rules? (Y/n): " ans && [[ "${ans:-Y}" =~ ^[Yy]$ ]] && UPDATE_RULES=true
        read -p "Update memory templates? (y/N): " ans && [[ "$ans" =~ ^[Yy]$ ]] && UPDATE_MEMORY=true
        ;;
esac

# ═══════════════════════════════════════════════════════════════════════════════
# BACKUP CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${BLUE}📦 Creating backup of your configuration...${NC}"

BACKUP_DIR="$TARGET_DIR/.speckit-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup progress tracker
if [ -f "$TARGET_DIR/docs/progress-tracker.json" ]; then
    cp "$TARGET_DIR/docs/progress-tracker.json" "$BACKUP_DIR/"
    echo -e "  ${GREEN}✓${NC} Backed up progress-tracker.json"
fi

# Backup constitution (user may have customized)
if [ -f "$TARGET_DIR/.specify/memory/constitution.md" ]; then
    cp "$TARGET_DIR/.specify/memory/constitution.md" "$BACKUP_DIR/"
    echo -e "  ${GREEN}✓${NC} Backed up constitution.md"
fi

# Backup other memory files
for file in project-details.md taxonomy.md domain.md regulatory.md; do
    if [ -f "$TARGET_DIR/.specify/memory/$file" ]; then
        cp "$TARGET_DIR/.specify/memory/$file" "$BACKUP_DIR/"
    fi
done
echo -e "  ${GREEN}✓${NC} Backed up memory files"

echo -e "  ${DIM}Backup location: $BACKUP_DIR${NC}"

# ═══════════════════════════════════════════════════════════════════════════════
# PERFORM UPDATE
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${BLUE}🔄 Updating components...${NC}"

UPDATED_COUNT=0

# Update skills
if [ "$UPDATE_SKILLS" = true ]; then
    if [ -d "$SCRIPT_DIR/.cursor/skills" ]; then
        mkdir -p "$TARGET_DIR/.cursor"
        cp -r "$SCRIPT_DIR/.cursor/skills" "$TARGET_DIR/.cursor/"
        SKILL_COUNT=$(ls "$TARGET_DIR/.cursor/skills" 2>/dev/null | wc -l | tr -d ' ')
        echo -e "  ${GREEN}✓${NC} Updated Cursor agent skills ($SKILL_COUNT commands)"
        ((UPDATED_COUNT++))
    fi
    if [ -d "$SCRIPT_DIR/.claude/skills" ]; then
        mkdir -p "$TARGET_DIR/.claude"
        cp -r "$SCRIPT_DIR/.claude/skills" "$TARGET_DIR/.claude/"
        echo -e "  ${GREEN}✓${NC} Updated Claude Code agent skills ($SKILL_COUNT commands)"
    fi
fi

# Update Cursor rules (always-on guardrails)
if [ "$UPDATE_RULES" = true ]; then
    if [ -d "$SCRIPT_DIR/.cursor/rules" ]; then
        mkdir -p "$TARGET_DIR/.cursor"
        cp -r "$SCRIPT_DIR/.cursor/rules" "$TARGET_DIR/.cursor/"
        RULE_COUNT=$(ls "$TARGET_DIR/.cursor/rules" 2>/dev/null | wc -l | tr -d ' ')
        echo -e "  ${GREEN}✓${NC} Updated Cursor rules ($RULE_COUNT guardrails)"
        ((UPDATED_COUNT++))
    fi
fi

# Update templates
if [ "$UPDATE_TEMPLATES" = true ]; then
    if [ -d "$SCRIPT_DIR/.specify/templates" ]; then
        mkdir -p "$TARGET_DIR/.specify"
        cp -r "$SCRIPT_DIR/.specify/templates" "$TARGET_DIR/.specify/"
        echo -e "  ${GREEN}✓${NC} Updated templates"
        ((UPDATED_COUNT++))
    fi
fi

# Update dashboard HTML (not the JSON data)
if [ "$UPDATE_DASHBOARD" = true ]; then
    if [ -f "$SCRIPT_DIR/docs/progress-dashboard.html" ]; then
        mkdir -p "$TARGET_DIR/docs"
        cp "$SCRIPT_DIR/docs/progress-dashboard.html" "$TARGET_DIR/docs/"
        echo -e "  ${GREEN}✓${NC} Updated dashboard UI"
        ((UPDATED_COUNT++))
        
        # Also update jira-integration.md and README if they exist in source
        [ -f "$SCRIPT_DIR/docs/jira-integration.md" ] && cp "$SCRIPT_DIR/docs/jira-integration.md" "$TARGET_DIR/docs/"
        [ -f "$SCRIPT_DIR/docs/README.md" ] && cp "$SCRIPT_DIR/docs/README.md" "$TARGET_DIR/docs/"
    fi
fi

# Update scripts
if [ "$UPDATE_SCRIPTS" = true ]; then
    if [ -d "$SCRIPT_DIR/.specify/scripts" ]; then
        cp -r "$SCRIPT_DIR/.specify/scripts" "$TARGET_DIR/.specify/"
        find "$TARGET_DIR/.specify/scripts" -name "*.sh" -exec chmod +x {} \; 2>/dev/null
        echo -e "  ${GREEN}✓${NC} Updated scripts"
        ((UPDATED_COUNT++))
    fi
fi

# Update memory templates (careful - user may have customized)
if [ "$UPDATE_MEMORY" = true ]; then
    echo ""
    echo -e "${YELLOW}⚠ Warning: This will overwrite your memory files.${NC}"
    echo -e "${YELLOW}  Your customizations are backed up in: $BACKUP_DIR${NC}"
    read -p "Continue? (y/N): " CONFIRM_MEMORY
    
    if [[ "$CONFIRM_MEMORY" =~ ^[Yy]$ ]]; then
        if [ -d "$SCRIPT_DIR/.specify/memory" ]; then
            cp -r "$SCRIPT_DIR/.specify/memory" "$TARGET_DIR/.specify/"
            echo -e "  ${GREEN}✓${NC} Updated memory file templates"
            ((UPDATED_COUNT++))
        fi
    else
        echo -e "  ${YELLOW}⊘${NC} Skipped memory files"
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# RESTORE CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${BLUE}📋 Restoring your configuration...${NC}"

# Restore progress tracker (always)
if [ -f "$BACKUP_DIR/progress-tracker.json" ]; then
    cp "$BACKUP_DIR/progress-tracker.json" "$TARGET_DIR/docs/"
    echo -e "  ${GREEN}✓${NC} Restored progress-tracker.json"
fi

# Restore constitution if memory wasn't updated
if [ "$UPDATE_MEMORY" != true ] && [ -f "$BACKUP_DIR/constitution.md" ]; then
    cp "$BACKUP_DIR/constitution.md" "$TARGET_DIR/.specify/memory/"
    echo -e "  ${GREEN}✓${NC} Preserved constitution.md"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# COMPLETION
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              ✅ Update Complete!                               ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}Updated:${NC}     $UPDATED_COUNT component(s)"
echo -e "  ${CYAN}Project:${NC}     $TARGET_DIR"
echo -e "  ${CYAN}Backup:${NC}      $BACKUP_DIR"
echo ""
echo -e "${DIM}Your project configuration (progress-tracker.json) was preserved.${NC}"
echo -e "${DIM}If anything went wrong, restore from: $BACKUP_DIR${NC}"
echo ""

# Show what's new (if there's a changelog)
if [ -f "$SCRIPT_DIR/CHANGELOG.md" ]; then
    echo -e "${CYAN}What's New:${NC}"
    head -20 "$SCRIPT_DIR/CHANGELOG.md" | tail -15
    echo ""
fi

echo -e "${GREEN}Restart Cursor to use the updated skills.${NC}"
echo ""
