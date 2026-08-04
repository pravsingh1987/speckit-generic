---
name: "speckit-testcases"
description: "Generate test cases (manual/UAT + automated Apex/Jest scaffolds) and a traceability matrix from a feature's user stories and acceptance scenarios."
argument-hint: Optional: feature area or leave blank
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "speckit-salesforce"
  source: "templates/commands/testcases.md"
  version: "1.0.0"
---


## Purpose

Convert the **Acceptance Scenarios** (`Given / When / Then`) and **Edge Cases** in
`spec.md` into:

1. **Manual / UAT test cases** — `specs/<feature>/test-cases.md` (for QA + business sign-off)
2. **Automated tests** — Apex `@isTest` classes and LWC Jest specs that encode the same scenarios
3. **A traceability matrix** — proving every acceptance scenario and edge case is covered

Runs **between `/speckit-tasks` and `/speckit-implement`** so tests exist before code
(TDD-first). It can also run after implementation to backfill coverage.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty). Users may scope
the run, e.g. "only US1", "manual only", "Apex only", or "regenerate the matrix".

## Pre-Execution Checks

**Check for extension hooks (before test-case generation)**:
- Check if `.specify/extensions.yml` exists in the project root.
- If it exists, read it and look for entries under the `hooks.before_testcases` key.
- If the YAML cannot be parsed or is invalid, skip hook checking silently and continue.
- Filter out hooks where `enabled` is explicitly `false`. Treat hooks without an `enabled` field as enabled.
- Do **not** interpret or evaluate hook `condition` expressions; if a non-empty `condition` exists, skip the hook.
- When constructing slash commands from hook command names, replace dots (`.`) with hyphens (`-`).
- If no hooks are registered or `.specify/extensions.yml` does not exist, skip silently.

## Outline

1. **Setup**: Run `.specify/scripts/bash/setup-testcases.sh --json` from repo root and parse
   `FEATURE_DIR`, `FEATURE_SPEC`, `TASKS`, `TASKS_PRESENT`, `TEST_CASES_FILE`,
   `TESTCASES_TEMPLATE`, and `AVAILABLE_DOCS`. Paths are absolute when provided.

2. **Load context**: Read from `FEATURE_DIR`:
   - **Required**: `spec.md` — user stories (with priorities), Acceptance Scenarios, Edge Cases,
     Persona Capabilities, Success Criteria.
   - **Strongly recommended**: `tasks.md` and `plan.md` — to learn the real class/component
     names and file paths so automated test paths are accurate (not guessed).
   - **Optional**: `data-model.md` (entities → test data), `contracts/` (interface contracts →
     assertions), `research.md`, `quickstart.md`.
   - **IF EXISTS**: `.specify/memory/constitution.md` for testing standards (coverage targets,
     `runAs`/FLS expectations, no `SeeAllData`, bulk/governor rules).

3. **Generate manual / UAT test cases** into `TEST_CASES_FILE` using `TESTCASES_TEMPLATE`:
   - One section per user story (priority order). For **each acceptance scenario**, create at
     least one **positive** test case AND, wherever the story has input, an action, or access
     control, at least one **negative** test case. For **each edge case**, an edge/boundary case.
     Positive and negative are **distinct** types — do **not** file a negative as "edge".
   - Each test case MUST have: stable ID (`TC-US<n>-<nn>`), type (one of **Positive / Negative /
     Edge / Security / Performance**), priority, **traces to** (the exact scenario/edge),
     preconditions, concrete test data, numbered steps, and an expected result that matches the
     `Then` clause.
   - **Granular negative matrix (required)**: add a dedicated "Negative & validation test cases"
     section with `TC-NEG-<nn>` IDs grouped by category, derived from the real implementation:
       - **Input validation** — one negative per required-field guard / format / range / size
         limit in each controller method (e.g. each `String.isBlank(...)` throw, each
         `Date.valueOf` parse, malformed JSON, out-of-range number).
       - **Referential / null** — null/blank Id, non-existent or inaccessible parent record.
       - **Authorization / persona** — each persona that must NOT see/do an action is blocked.
       - **Sharing / FLS** — out-of-span record hidden (`with sharing`); FLS-stripped field via
         `WITH USER_MODE`; records the user can't see are omitted, not errored.
     Tag each negative `[A]` (automated now) or `[M]` (manual) and assert the system **rejects or
     handles** the bad input — never corrupts data or throws an unhandled error.
   - Add cross-cutting tests: bulk/governor (200 records), persona/FLS denial (from Persona
     Capabilities), and any Success Criteria that are measurable.
   - In the document legend, state the **Type taxonomy** (Positive / Negative / Edge / Security /
     Performance) and include `TC-NEG-nn` in the ID scheme so positive vs negative is explicit.
   - **Step-level detail (required)**: every manual test case MUST be written at step granularity,
     not a one-line summary. Each case carries: **Test Case Id**, **Test Case Title** prefixed with
     its type (`Positive:` / `Negative:` / `Security:` / `Edge:` / `Performance:`), a **Description**
     (what is being verified, one sentence), **Preconditions** (data + user/persona + state), and an
     ordered list of **Steps** where each step has a **Step Number**, a concrete **Test Step**
     (the action), and a per-step **Expected Result**. Prefer 2–6 steps; the final step's expected
     result MUST match the scenario's `Then` clause.
   - **Security suite (required)**: always generate a dedicated **Security test cases** set
     (`TC-SEC-nn`), step-level, covering — as applicable to the feature:
       - **Authentication / session** (unauthenticated or expired session is rejected; login audit).
       - **Authorization / CRUD & object perms** (user without object/app permission cannot reach
         the action; `@AuraEnabled` method denies).
       - **Record-level sharing** (`with sharing`: user outside the role/sharing span cannot read
         another team's record; related panels never widen access).
       - **Field-level security (FLS)** via `WITH USER_MODE` / `Security.stripInaccessible` (a user
         without FLS on a field does not receive it; no leak, no unhandled error).
       - **Input / injection safety** (SOQL/JSON/HTML inputs are bound/escaped; malicious strings
         do not alter queries or render as markup).
       - **Sensitive-data exposure** (PII / pricing / approval limits not exposed to unauthorized
         personas; not logged in clear).
       - **Privilege escalation / persona gating** (a lower persona cannot perform a higher
         persona's action — reassign, team edit, approvals).
   - **Optional CSV export for test-management import**: when the user asks for a spreadsheet/
     importable form (or mentions Jira/Zephyr/qTest/Excel), also emit `test-cases-detailed.csv`
     next to `test-cases.md` with one **row per step** and these exact columns:
     `User Story Id, User Story Title, User Story Solution, Test Case Id, Test Case Title,
     Test Case Description, Test Case Preconditions, Step Number, Test Step, Expected Result`.

4. **Generate automated tests** (skip layers the feature doesn't use, or per user scope):
   - **Apex** (`@isTest`): one test class per Apex class under test. Place at
     `force-app/main/default/classes/<Name>Test.cls` (+ `<Name>Test.cls-meta.xml`).
     Use `@TestSetup` for shared data, `System.runAs(...)` for persona/FLS, wrap the action in
     `Test.startTest()` / `Test.stopTest()`, assert with `Assert.*`, include a bulk (200-record)
     method, and **never** use `@isTest(SeeAllData=true)`. Target ≥ 90% coverage on new classes.
   - **LWC Jest**: `force-app/main/default/lwc/<cmp>/__tests__/<cmp>.test.js`. Mock `@wire`/Apex
     with `jest.mock`, assert rendered DOM + empty/loading/error states, `flushPromises()` for async.
   - **Flow**: Flows can't be unit-tested like Apex — emit a short "Flow test recipe" in
     `test-cases.md` (inputs, path to exercise, expected record/field outcomes, fault-path check).
   - **TDD-first**: derive real assertions from the acceptance scenarios. If the implementation
     does not exist yet, the tests are expected to fail (red) until `/speckit-implement` makes them pass.
     Name each test method to match its `AT-US<n>-<nn>` ID in the matrix.

5. **Build the traceability matrix** (bottom of `test-cases.md`): one row per acceptance scenario
   AND per edge case → manual TC → automated test → status. **Flag any scenario with no covering
   test as a ❌ Gap** and list gaps explicitly in the completion report. Do not silently skip.

6. **Write outputs**: save `test-cases.md`; create/update the Apex and Jest files at the resolved
   paths. If a target path is unknown (no tasks.md), write the test next to its best-guess location
   and note the assumption in the completion report.

## Mandatory Post-Execution Hooks

**You MUST complete this section before reporting completion to the user.**

- Check if `.specify/extensions.yml` exists. If not, or no hooks under `hooks.after_testcases`, skip to the Completion Report.
- If it exists, read entries under `hooks.after_testcases`; on parse failure, skip silently.
- Filter out `enabled: false` hooks; treat missing `enabled` as enabled.
- Do not evaluate `condition` expressions; skip hooks with a non-empty condition.
- Replace dots with hyphens when constructing slash commands.
- For each **mandatory** hook (`optional: false`) emit `EXECUTE_COMMAND: {command}`; for **optional** hooks, list the command and description for the user.

## Dashboard / progress integration

After generating test cases, log the work so the dashboard stays accurate:

```bash
python3 scripts/log-session.py --epic <EPIC-ID> --story <STORY-KEY> \
    --contributor <id> --activity "Test cases + automated scaffolds for <feature>" --tokens <estimate>
```

(In an installed project, the path is `.specify/scripts/log-session.py`.) Optionally record a
test-coverage note per story in `progress-tracker.json` so reviewers can see which stories have tests.

## Completion Report

Report to the user:
- Path to `test-cases.md`
- Manual test-case count (by user story, by type)
- Automated tests created (Apex classes + methods, Jest specs) with file paths
- **Coverage**: X of Y acceptance scenarios covered; list any ❌ gaps explicitly
- Any assumptions made about file paths (when tasks.md was absent)
- Suggested next step: run the Apex tests (`sf apex run test`) / Jest (`npm run test:unit`), or proceed to `/speckit-implement`

## Done When

- [ ] `test-cases.md` generated with per-story manual cases (**both positive and negative**), edge/cross-cutting cases, and a traceability matrix
- [ ] Manual cases written at **step level** (Test Case Id + Title with type prefix, Description, Preconditions, numbered Steps each with its own Expected Result)
- [ ] Dedicated granular **Negative & validation** matrix present (`TC-NEG-nn` by category: input-validation / referential / authorization / sharing-FLS)
- [ ] Dedicated **Security** suite present (`TC-SEC-nn`: auth/session, CRUD, sharing, FLS, injection, sensitive-data, privilege escalation)
- [ ] Type taxonomy + `TC-NEG` documented in the legend/ID scheme
- [ ] Automated Apex/Jest scaffolds created at correct paths (for in-scope layers), including negative-path methods (invalid input, null, persona/FLS)
- [ ] If requested, `test-cases-detailed.csv` emitted (one row per step, columns per the spec) for test-management import
- [ ] Every acceptance scenario and edge case appears in the matrix; gaps flagged
- [ ] Extension hooks dispatched or skipped per the rules above
- [ ] Completion reported with counts, coverage, and gaps
