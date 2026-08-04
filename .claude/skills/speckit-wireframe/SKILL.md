---
name: speckit-wireframe
description: Feature name
argument-hint: Feature name or spec path
---

# /speckit-wireframe

Generate Figma wireframes from a feature specification for customer sign-off before implementation.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Purpose

This command bridges the gap between specification and implementation by producing visual wireframes that:
- Stakeholders can review and approve before any code is written
- Serve as the visual contract for the feature
- Reduce rework by catching UX issues early
- Provide developers with clear visual targets

## Prerequisites

- Feature spec exists at `specs/<feature>/spec.md`
- Spec includes **Panel / Screen Content** section with field mappings
- Spec includes **Navigation & Interactions** section
- Figma MCP is available and authenticated

## Outline

1. **Setup**: Run `.specify/scripts/bash/check-prerequisites.sh --json` to get FEATURE_DIR, or use `$ARGUMENTS` if a specific feature is provided.

2. **Load spec context**: Read `FEATURE_DIR/spec.md` and extract:
   - All screens/panels/tabs defined in **Panel / Screen Content**
   - Navigation flows from **Navigation & Interactions**
   - User stories and their acceptance scenarios
   - Persona capabilities (which roles see what)

3. **Generate screen inventory**: Create a list of screens to wireframe:
   ```
   | Screen ID | Screen Name | Primary User Story | Key Components |
   |-----------|-------------|-------------------|----------------|
   | S01 | [Name] | US1 | [Components] |
   ```

4. **Read Figma skill**: Load `/figma-generate-design` skill from the Figma MCP resources.

5. **For each screen**:
   a. Compose a detailed wireframe prompt including:
      - Screen purpose and context
      - All fields/data to display (from Panel Content)
      - Navigation elements and interactions
      - Persona-specific visibility rules
      - Salesforce Lightning Design System (SLDS) styling
   b. Call the Figma MCP `generate_figma_design` or `use_figma` tool
   c. Capture the Figma link

6. **Generate wireframes.md artifact**: Create `FEATURE_DIR/wireframes.md`:

   ```markdown
   # Wireframes: [FEATURE NAME]

   **Generated**: [DATE]
   **Spec**: [Link to spec.md]
   **Status**: 🟡 Pending Sign-off

   ## Screen Inventory

   | Screen | Figma Link | User Story | Status | Approved By |
   |--------|------------|------------|--------|-------------|
   | [Name] | [Link] | US1 | ⏳ Pending | |

   ## Sign-off Checklist

   - [ ] All screens reviewed by Product Owner
   - [ ] Field placements approved
   - [ ] Navigation flow approved
   - [ ] Mobile responsiveness reviewed (if applicable)
   - [ ] Accessibility considerations noted

   ## Feedback Log

   | Date | Screen | Feedback | Resolution |
   |------|--------|----------|------------|

   ## Sign-off

   **Approved for Implementation**: ☐ Yes / ☐ No
   **Approved By**: _______________
   **Date**: _______________

   ---

   ⚠️ **Do not proceed to `/speckit-plan` until sign-off is complete.**
   ```

7. **Update spec.md**: Add a Wireframes section linking to `wireframes.md`.

## Salesforce Record-Page Anatomy (MANDATORY — reality-oriented headers)

Every record-page wireframe MUST reproduce the **real Salesforce Lightning Experience structure**
top-to-bottom (see `.cursor/rules/wireframe-salesforce-anatomy.mdc` for the authoritative rule).
Do not invent a generic app shell.

1. **Global header** — company logo · global search · utility icons (⭐ App Launcher ⚙ ? 🔔 avatar).
2. **App nav bar** — app name (e.g., `Sales App`) + object tabs + open record tab(s) with object icon.
3. **Record header / highlights panel**:
   - Object icon + **object type label**, then the **record name** (H1).
   - **Compact Layout highlights row** — a horizontal strip of 5–7 real key–value fields (label on top,
     value below), exactly like the object's Compact Layout.
     *Account example:* Account Name · Account Type · Industry · Phone · Billing City · Owner.
   - **Action buttons** right-aligned: standard (**Follow · Edit · Delete · ▾**) + custom quick actions.
4. **Body** — label every block by its source: `[Standard: Details]`, `[Standard: Related List]`,
   or `[LWC: componentName]`. Include `lightning-path` for lifecycle objects; use tabs or 2/3-column regions.
5. **Utility bar** (bottom) only when the flow needs it.

Rules: always render the compact-layout highlights row with real API labels; tag each region as
Standard vs LWC; prefer declarative/standard layouts first and introduce LWCs only where the spec
requires them (Constitution Principles I & IX).

## Figma Design Guidelines

When generating wireframes for Salesforce Lightning:

### Layout Principles
- Use **Lightning Record Page** layout patterns (global header → app nav → record header with
  **compact-layout highlights row** → body). See the Record-Page Anatomy section above (MANDATORY).
- Follow **SLDS** spacing and typography; build from the org's **SLDS 2 Components – Web** library.
- Include standard Lightning components: `lightning-card`, `lightning-datatable`, `lightning-badge`
- Show field labels matching API names from spec
- Label each body region as `[Standard: …]` or `[LWC: …]` so reviewers see config vs custom

### Screen Types
- **Record Page**: Header + sidebar + tabbed content area
- **List View**: Filters + datatable with actions
- **Modal/Dialog**: Form fields + action buttons
- **Dashboard/Roll-up**: KPI cards + charts + drill-down lists

### Annotations
- Mark required fields with asterisk (*)
- Show persona visibility notes (e.g., "RSM+ only")
- Indicate dynamic elements (e.g., "Shows based on record type")
- Note approval gates and stage transitions

## Completion Report

Output:
- Path to generated `wireframes.md`
- Figma file/frame links for each screen
- Summary of screens generated
- Next steps (share with stakeholders, collect feedback)

## Done When

- [ ] All screens from spec have corresponding Figma wireframes
- [ ] `wireframes.md` created with sign-off checklist
- [ ] Spec updated with Wireframes section link
- [ ] Figma links are accessible and shareable
