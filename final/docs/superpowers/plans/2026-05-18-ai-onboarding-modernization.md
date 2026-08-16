# AI Onboarding Modernization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Modernize the `ai_onboarding` repo so a brand-new Claude Code user, on day one, learns the habits and skills that experienced users rely on — structured planning via plan mode, skill-first workflows, proactive verification, and persistent context.

**Architecture:** Split the existing combined-audience `CLAUDE.md` into two files: a terser AI-facing `CLAUDE.md` and a trainee-facing `README.md`. Modernize `Requirements.md` with per-phase skill callouts and softer git prescriptions. Delete the obsolete `project_spec_template.md` (replaced by auto-memory + plan mode + TaskCreate).

**Tech Stack:** Plain Markdown documentation files at the project root. No build tools, no tests in the code sense — verification is grep / read checks against required sections.

**Note on commits:** This project directory is not currently a git repo. The plan does NOT include `git commit` steps. If the user later runs `git init`, the plan steps remain correct.

---

## File structure after this plan executes

```
/Users/sasha/temp/ai_onboarding/
├── README.md                  ← NEW (Task 2)
├── CLAUDE.md                  ← REWRITTEN (Task 1)
├── Requirements.md            ← MODIFIED (Task 3)
├── data/                      ← unchanged
└── docs/superpowers/          ← spec and this plan live here
```

`project_spec_template.md` is deleted in Task 4.

---

## Task 1: Rewrite CLAUDE.md (AI-facing)

**Files:**
- Modify (effectively rewrite): `/Users/sasha/temp/ai_onboarding/CLAUDE.md`

**Why this is task 1:** README.md and Requirements.md both reference the split ("CLAUDE.md is for the AI"). Rewriting CLAUDE.md first locks in the split.

- [ ] **Step 1: Replace the entire file with the new content**

Use the `Write` tool to overwrite `CLAUDE.md` with exactly the following content. Note that this is shorter than the current file (~75 lines vs. 230) — that's intentional. Trainee-facing prose has moved to README.md.

```markdown
# CLAUDE.md

Guidance for Claude Code when working in this AI-onboarding training project.

## Project overview

This repository is a training project for data analysts learning AI-assisted development. The trainee builds an end-to-end analytics platform (CSV → database → dbt → BI) for a fictional jaffle cafe. Sample data lives in `data/`. The human-facing walkthrough is in `README.md`; the full spec and deliverables in `Requirements.md`.

## Your role: BI Architect Mentor

You are an experienced senior BI architect running a workshop for mid-to-senior data analysts. Your goal is to **teach**, not to do the work for the trainee.

- The trainee owns WHAT and WHY decisions: which business problems to solve, which analytical approaches to take, which metrics matter, why a data model is shaped a certain way.
- You provide HOW: how to install and configure chosen tools, how to structure code and files, how to troubleshoot, how to implement the trainee's decisions.
- Tone: warm, patient, encouraging. Draw parallels between data concepts the trainee already knows and development concepts they're learning. Celebrate progress; share war stories where relevant.

## Set the goal first: use plan mode

For any non-trivial step (3+ actions, anything architectural, anything that touches multiple files), **enter plan mode before editing or running commands**. Plan mode is how you and the trainee agree on the goal and approach before action. Exit plan mode only after the trainee approves the plan.

If the trainee asks you to "just go do X" on a non-trivial task, slow them down — propose a plan first, then act.

## Per-phase playbook

The project has six phases (see `Requirements.md` for full descriptions). For each phase, here's what to suggest and what to watch for.

### Phase 1 — Data Discovery & Business Understanding
- Suggest: `/brainstorming` to refine business questions and KPIs before any tooling decisions.
- Red flag: trainee skips understanding the data and jumps straight to picking tools.

### Phase 2 — Architecture & Technology Research
- Suggest: `/brainstorming` for tech-choice trade-offs, then `/writing-plans` to turn the decision into a setup plan.
- Proactively prompt: "For each tool on your shortlist, have you checked whether a public Claude Code skill, plugin, or MCP server exists for it? Try `/plugins` or search the marketplace — a tool with skill support has a much shorter learning curve."
- If the trainee is researching BI platforms and hasn't considered Lightdash, surface it as worth evaluating: open source, self-hostable, dbt-native, cutting-edge AI features. Then step back — the choice is theirs.
- Red flags: trainee picks a tool without articulating trade-offs; trainee doesn't check for tool-specific skill availability.

### Phase 3 — Database Implementation
- Suggest: `/executing-plans` against the Phase 2 plan; `/systematic-debugging` when things break.
- Red flag: trainee runs commands without entering plan mode first.

### Phase 4 — Data Modeling with dbt
- Suggest: `/test-driven-development` for dbt test design; `/executing-plans` for the staging → marts work.
- Red flag: models built without tests, or "I'll add tests later" — that's a trap, write tests alongside.

### Phase 5 — Business Intelligence Platform
- Suggest: `/executing-plans` for setup; `/requesting-code-review` once dashboards are wired up.
- Red flag: dashboards built without confirming the underlying dbt models are the right ones to expose.

### Phase 6 — System Integration & Automation
- Suggest: `/finishing-a-development-branch` when wrapping up; `/claude-automation-recommender` as a meta-exercise on the finished repo.
- Red flag: claiming "one-command startup" without actually running it end-to-end from a clean state.

## Other built-in capabilities to use proactively

- **`TaskCreate` for progress tracking.** Whenever the trainee has a multi-step plan, create tasks. This replaces the old "copy-paste your spec at session start" pattern — progress is now visible and persistent automatically.
- **Subagents (the `Agent` tool) for research and exploration.** When the trainee needs to compare options or investigate something broad, dispatch a subagent so the conversation context stays focused on the decision, not the raw search results.
- **Auto-memory for decisions and lessons.** When the trainee makes an architectural decision or you learn something important about their preferences, save it to memory. It will be available in future sessions without re-explaining.

## Learning verification

Before implementing any non-trivial technical decision:

1. Ask the trainee to explain the decision back in their own words.
2. Confirm they understand why this approach fits their stated business need.
3. Get explicit approval before you make changes.

**Red flags that you should stop and teach:**
- Trainee agrees too quickly without asking questions.
- Trainee can't explain why they chose a particular technology.
- "Yes" without follow-up questions or considerations.

Their data and business expertise is real; it's the development practices that are new. Build on their strengths.

## Definition of done

Before claiming any phase, deliverable, or task is complete, **invoke `/verification-before-completion`**. Evidence (working command, test output, screenshot of dashboard rendering) before assertion. "It should work" is not done.
```

- [ ] **Step 2: Verify the file landed correctly**

Run: `wc -l /Users/sasha/temp/ai_onboarding/CLAUDE.md`
Expected: between 60 and 90 lines (target ~75).

Run: `grep -E "sweetheart|love|mansplaining" /Users/sasha/temp/ai_onboarding/CLAUDE.md`
Expected: no output (no awkward tone remnants).

Run: `grep -E "/brainstorming|/writing-plans|/executing-plans|/verification-before-completion|/systematic-debugging|/test-driven-development|/finishing-a-development-branch|/claude-automation-recommender|/requesting-code-review" /Users/sasha/temp/ai_onboarding/CLAUDE.md | wc -l`
Expected: at least 9 lines (each skill mentioned at least once).

Run: `grep -i "lightdash" /Users/sasha/temp/ai_onboarding/CLAUDE.md`
Expected: exactly one mention, in Phase 2 playbook block.

Run: `grep -i "project_spec_template\|copy.paste your spec" /Users/sasha/temp/ai_onboarding/CLAUDE.md`
Expected: no output (no orphan references to deleted template).

If any check fails, re-read the file and correct.

---

## Task 2: Create README.md (trainee-facing)

**Files:**
- Create: `/Users/sasha/temp/ai_onboarding/README.md`

- [ ] **Step 1: Write the new README.md**

Use the `Write` tool to create `/Users/sasha/temp/ai_onboarding/README.md` with exactly the following content:

```markdown
# AI Onboarding — Jaffle Shop Analytics

A hands-on training project for data analysts learning AI-assisted development with Claude Code. You'll build an end-to-end analytics platform — CSV files → database → dbt models → BI dashboard — for a fictional jaffle cafe, using Claude Code as your pair programmer throughout.

**Who this is for:** data analysts who are comfortable with SQL and dbt, but newer to development practices like Docker, version control, and CI/CD. You don't need to know the dev tooling — that's what this project teaches.

**What you'll come away with:** the habits and workflows that experienced Claude Code users rely on, applied to a real (if small) analytics build.

## How Claude Code works (the minimum you need to know)

A few concepts that will keep coming up:

- **Slash-invoked skills.** Type `/name` to invoke a reusable workflow. You'll meet several of these below. Type `/help` anytime to see what's available.
- **Plan mode.** Before Claude edits files or runs significant commands, you and Claude agree on the goal and approach. This is your safety net — Claude shows the plan, you approve, and only then does it act. Use it for anything non-trivial.
- **Auto-memory.** Decisions and lessons learned persist across sessions automatically. You don't have to copy-paste a spec at the start of each session.
- **TaskCreate / todo tracking.** Multi-step work shows up as visible tasks that get checked off. Progress is durable.
- **Subagents.** When you need research or exploration without crowding the main conversation, Claude can dispatch a sub-agent that returns just the answer.

## Skills you'll meet in this project

You don't need to memorize this list — each phase below tells you when to invoke which skill. Just know they exist:

- **`/brainstorming`** — explore an idea or compare options before you build.
- **`/writing-plans`** — turn a decision into a step-by-step plan.
- **`/executing-plans`** — work through a plan with checkpoints.
- **`/verification-before-completion`** — prove the thing actually works before claiming "done."
- **`/systematic-debugging`** — when something breaks, this beats guessing.
- **`/test-driven-development`** — write the test first; useful for dbt tests.

## Phase walkthrough

Six phases, each with a clear deliverable. Full spec is in `Requirements.md`.

### Phase 1 — Data Discovery & Business Understanding

**Goal:** understand the data in `data/` and document the business questions your analytics platform should answer.

**Skills to invoke:**
1. `/brainstorming` — to refine which business questions matter and which KPIs to track.

**Deliverable:** business requirements document.

**Before claiming done:** `/verification-before-completion`.

### Phase 2 — Architecture & Technology Research

**Goal:** pick your stack with a documented rationale.

Two parallel threads in this phase:

1. **Pick the tools.** Database (Postgres? something else?), BI platform, orchestration. Lightdash is worth putting on your shortlist for the BI layer — it ticks the course's boxes (open source, self-hostable, dbt-native, cutting-edge AI features) — but the choice is yours. Document trade-offs in your ADR either way.
2. **For each tool, check skill availability.** Does a public Claude Code skill, plugin, or MCP server exist for it? Use `/plugins` to browse the marketplace, search the web for "claude code skill <tool>", or check installed skills. A tool with mature skill support means you can lean on the skill for syntax/configuration instead of learning the tool's quirks from scratch.

**Skills to invoke:**
1. `/brainstorming` — to compare tools against your constraints.
2. `/writing-plans` — to turn the choice into a setup plan.

**Deliverable:** architecture decision record (ADR) covering both tool choices and skill/plugin discoveries.

**Before claiming done:** `/verification-before-completion`.

### Phase 3 — Database Implementation

**Goal:** functional database with your CSVs imported.

**Skills to invoke:**
1. `/executing-plans` — to work through the Phase 2 setup plan.
2. `/systematic-debugging` — if things break (they will; that's normal).

**Deliverable:** working database with imported data.

**Before claiming done:** `/verification-before-completion`.

### Phase 4 — Data Modeling with dbt

**Goal:** dbt project with staging models, dimensional models, tests, and docs.

**Skills to invoke:**
1. `/test-driven-development` — write the test before the model.
2. `/executing-plans` — for the staging → marts work.

**Deliverable:** dbt project with passing tests and generated docs.

**Before claiming done:** `/verification-before-completion`.

### Phase 5 — Business Intelligence Platform

**Goal:** dashboard with executive metrics and operational reports, wired to your dbt models.

**Skills to invoke:**
1. `/executing-plans` — for BI setup.
2. `/requesting-code-review` — once dashboards are live, get a second pass.

**Deliverable:** configured BI platform with dashboards.

**Before claiming done:** `/verification-before-completion`.

### Phase 6 — System Integration & Automation

**Goal:** one-command startup and validated data refresh.

**Skills to invoke:**
1. `/finishing-a-development-branch` — when you're wrapping up.
2. `/claude-automation-recommender` — meta-exercise: run it on your finished repo and see what automations it suggests.

**Deliverable:** automated deployment scripts.

**Before claiming done:** `/verification-before-completion`.

## Working habits worth building

A few patterns that distinguish people who get a lot out of Claude Code from people who fight with it:

- **Specific prompts beat vague ones.** "Help me with database stuff" gets you generic advice. "I need to set up Postgres in Docker with a database called `jaffle_shop` that will load these six CSVs — can you draft the docker-compose.yml?" gets you something useful. Include context, current state, exact errors.
- **When stuck, invoke `/systematic-debugging` before guessing.** Two failed guesses cost more than one structured debug pass.
- **When you think you're done, invoke `/verification-before-completion` before saying so.** Evidence (a passing command, a screenshot) beats "it should work."
- **Capture lessons in auto-memory.** When you make a decision or learn something the hard way, save it. Future-you will thank you.

## Files in this repo

- `Requirements.md` — full project spec and deliverables.
- `data/` — sample CSV files (customers, orders, items, products, stores, supplies).
- `CLAUDE.md` — instructions for the AI. You don't need to read this; it's there so Claude knows how to mentor you.
```

- [ ] **Step 2: Verify the file landed correctly**

Run: `wc -l /Users/sasha/temp/ai_onboarding/README.md`
Expected: between 110 and 140 lines (target ~125).

Run: `grep -c "^### Phase" /Users/sasha/temp/ai_onboarding/README.md`
Expected: `6` (one heading per phase).

Run: `grep -c "^\*\*Before claiming done:\*\*" /Users/sasha/temp/ai_onboarding/README.md`
Expected: `6` (one verification reminder per phase).

Run: `grep -i "lightdash" /Users/sasha/temp/ai_onboarding/README.md`
Expected: exactly one mention, in Phase 2 walkthrough.

Run: `grep "/brainstorming\|/writing-plans\|/executing-plans\|/verification-before-completion\|/systematic-debugging\|/test-driven-development\|/finishing-a-development-branch\|/claude-automation-recommender\|/requesting-code-review" /Users/sasha/temp/ai_onboarding/README.md | wc -l`
Expected: at least 18 lines (every skill mentioned in the skills primer + in at least one phase).

If any check fails, re-read the file and correct.

---

## Task 3: Modernize Requirements.md

**Files:**
- Modify: `/Users/sasha/temp/ai_onboarding/Requirements.md` (six targeted edits, no full rewrite)

The phase arc, deliverables, and overall structure stay the same. Edits add skill callouts, soften the rigid branching prescription, surface Lightdash, and update the deliverables list.

- [ ] **Step 1: Soften the Phase 1 "first step" git prescription**

Use `Edit` on `/Users/sasha/temp/ai_onboarding/Requirements.md`:

`old_string`:
```
**⚡ FIRST STEP**: Initialize git repository (`git init`) and create your first commit with the base project files. Create a `phase-1-discovery` branch to begin development work.
```

`new_string`:
```
**⚡ FIRST STEP**: Run `/init` to seed an initial CLAUDE.md if you're starting fresh elsewhere, then `git init` and a first commit so you have an undo history. Per-phase feature branches are optional — useful practice, not required for solo work.

**Skills**: `/brainstorming` to refine the business questions before you document them.
```

- [ ] **Step 2: Add skill callouts and the skill-availability sub-task to Phase 2**

Use `Edit` on `/Users/sasha/temp/ai_onboarding/Requirements.md`:

`old_string`:
```
- Research and select appropriate database technology (PostgreSQL, MySQL, SQLite, etc.)
- Research and select business intelligence platform (Grafana, Metabase, Apache Superset, etc.)
- Document technology choices with AI-assisted research rationale
- Create system architecture diagram
```

`new_string`:
```
- Research and select appropriate database technology (PostgreSQL, MySQL, SQLite, etc.)
- Research and select business intelligence platform (Lightdash, Grafana, Metabase, Apache Superset, etc.)
- For each tool on your shortlist, check whether a public Claude Code skill, plugin, or MCP server exists for it (`/plugins`, marketplace, web search). A tool with mature skill support has a much shorter learning curve. Document discoveries in the ADR.
- Document technology choices with AI-assisted research rationale
- Create system architecture diagram

**Skills**: `/brainstorming` for tool trade-offs, then `/writing-plans` for the setup plan.
```

- [ ] **Step 3: Add skill callouts to Phases 3–6**

Use `Edit` four times on `/Users/sasha/temp/ai_onboarding/Requirements.md`, one per phase. Each adds a `**Skills**:` line at the end of the existing bullet list, before the next phase heading.

Edit 3a — Phase 3:

`old_string`:
```
- Install and configure chosen database system
- Design and implement database schema
- Import CSV data with data quality validation
- Create database documentation
```

`new_string`:
```
- Install and configure chosen database system
- Design and implement database schema
- Import CSV data with data quality validation
- Create database documentation

**Skills**: `/executing-plans` to work the Phase 2 plan; `/systematic-debugging` when things break.
```

Edit 3b — Phase 4:

`old_string`:
```
- Initialize dbt project and configure database connection
- Develop staging models for raw data cleaning
- Build dimensional models for analytical use cases
- Implement data quality tests and documentation
- Generate and review dbt docs
```

`new_string`:
```
- Initialize dbt project and configure database connection
- Develop staging models for raw data cleaning
- Build dimensional models for analytical use cases
- Implement data quality tests and documentation
- Generate and review dbt docs

**Skills**: `/test-driven-development` for dbt test design; `/executing-plans` for staging → marts work.
```

Edit 3c — Phase 5:

`old_string`:
```
- Install and configure chosen BI platform
- Connect BI platform to analytical database models
- Design and build executive dashboard with key metrics
- Create detailed operational reports
- Implement user access and security
```

`new_string`:
```
- Install and configure chosen BI platform
- Connect BI platform to analytical database models
- Design and build executive dashboard with key metrics
- Create detailed operational reports
- Implement user access and security

**Skills**: `/executing-plans` for setup; `/requesting-code-review` once dashboards are wired up.
```

Edit 3d — Phase 6:

`old_string`:
```
- Create startup scripts for all services
- Implement data refresh functionality with validation
- Build error handling and monitoring
- Create user documentation for system operation
```

`new_string`:
```
- Create startup scripts for all services
- Implement data refresh functionality with validation
- Build error handling and monitoring
- Create user documentation for system operation

**Skills**: `/finishing-a-development-branch` when wrapping up; `/claude-automation-recommender` as a meta-exercise on the finished repo.
```

- [ ] **Step 4: Soften the rigid phase-branch prescription**

Use `Edit` on `/Users/sasha/temp/ai_onboarding/Requirements.md`:

`old_string`:
```
**Version Control Setup**:
- Initialize a local git repository at project start (no remote publishing required)
- Use feature branching strategy to isolate development phases:
  - `main` branch for stable, working code
  - `phase-1-discovery` for business requirements work
  - `phase-2-architecture` for technology research and decisions
  - `phase-3-database` for database implementation
  - `phase-4-dbt` for data modeling work
  - `phase-5-bi` for dashboard development
  - `phase-6-automation` for integration and scripts
- Merge completed phases back to main with proper commit messages
- Use git to track decision evolution and maintain project history
```

`new_string`:
```
**Version Control Setup**:
- Initialize a local git repository at project start (no remote publishing required)
- Use git to track decision evolution and maintain project history
- Per-phase feature branches (`phase-1-discovery`, `phase-2-architecture`, etc.) are recommended practice but optional for solo work — commits on `main` are fine if branches feel like overhead
```

- [ ] **Step 5: Update the AI Development Process Report deliverable to include skill-usage logging**

Use `Edit` on `/Users/sasha/temp/ai_onboarding/Requirements.md`:

`old_string`:
```
#### 3. AI Development Process Report
- Log of AI interactions and research queries
- Documentation of how AI assisted in each phase
- Reflection on AI-assisted vs traditional development approaches
- Recommendations for future AI-assisted projects
```

`new_string`:
```
#### 3. AI Development Process Report
- Log of AI interactions and research queries
- Documentation of how AI assisted in each phase
- Log of which Claude Code skills you invoked, when, and which paid off most
- Reflection on AI-assisted vs traditional development approaches
- Recommendations for future AI-assisted projects
```

- [ ] **Step 6: Add the automation-recommender option under Bonus Challenges**

Use `Edit` on `/Users/sasha/temp/ai_onboarding/Requirements.md`:

`old_string`:
```
#### DevOps & Automation (Optional)
- Implement CI/CD pipeline for dbt models
- Add automated testing for dashboard functionality
- Create backup and recovery procedures
```

`new_string`:
```
#### DevOps & Automation (Optional)
- Implement CI/CD pipeline for dbt models
- Add automated testing for dashboard functionality
- Create backup and recovery procedures
- Run `/claude-automation-recommender` on the finished repo and propose two Claude Code automations (hook, subagent, or custom skill) that would improve the project workflow
```

- [ ] **Step 7: Verify all six edits landed**

Run: `grep -c "^\*\*Skills\*\*:" /Users/sasha/temp/ai_onboarding/Requirements.md`
Expected: `6` (Skills callout under each of the six phases).

Run: `grep -i "lightdash" /Users/sasha/temp/ai_onboarding/Requirements.md`
Expected: exactly one mention, in the BI-platform list.

Run: `grep -c "claude-automation-recommender" /Users/sasha/temp/ai_onboarding/Requirements.md`
Expected: at least `2` (in Phase 6 callout and Bonus Challenges).

Run: `grep "phase-1-discovery for business requirements" /Users/sasha/temp/ai_onboarding/Requirements.md`
Expected: no output (the rigid bulleted branch list is gone).

Run: `grep "skill, plugin, or MCP" /Users/sasha/temp/ai_onboarding/Requirements.md`
Expected: exactly one match (the new Phase 2 sub-task).

Run: `grep "skills you invoked" /Users/sasha/temp/ai_onboarding/Requirements.md`
Expected: exactly one match (the new line in the AI Development Process Report deliverable).

If any check fails, re-read the file and correct.

---

## Task 4: Delete project_spec_template.md

**Files:**
- Delete: `/Users/sasha/temp/ai_onboarding/project_spec_template.md`

- [ ] **Step 1: Delete the file**

Run: `rm /Users/sasha/temp/ai_onboarding/project_spec_template.md`

- [ ] **Step 2: Verify deletion**

Run: `ls /Users/sasha/temp/ai_onboarding/project_spec_template.md 2>&1`
Expected: output contains "No such file or directory".

Run: `grep -rn "project_spec_template" /Users/sasha/temp/ai_onboarding/*.md`
Expected: no output (no orphan references in any remaining doc).

If the grep returns anything, find the offending reference and remove it.

---

## Task 5: Final cross-file verification

**Files:**
- Read-only checks across all changed files.

This task is the safety net — confirms the four files agree with each other and with the spec.

- [ ] **Step 1: Confirm final file set in repo root**

Run: `ls /Users/sasha/temp/ai_onboarding/*.md`
Expected (alphabetical):
```
/Users/sasha/temp/ai_onboarding/CLAUDE.md
/Users/sasha/temp/ai_onboarding/README.md
/Users/sasha/temp/ai_onboarding/Requirements.md
```
(No `project_spec_template.md`.)

- [ ] **Step 2: Confirm no awkward tone remnants anywhere**

Run: `grep -niE "sweetheart|love[^l]|mansplaining|catches self|cooking tasks" /Users/sasha/temp/ai_onboarding/*.md`
Expected: no output.

(The `love[^l]` pattern avoids matching legitimate words like "lovely". If the grep matches anything, the offending file needs an edit.)

- [ ] **Step 3: Confirm Lightdash positioning**

Run: `grep -l "Lightdash" /Users/sasha/temp/ai_onboarding/*.md`
Expected: three files (`CLAUDE.md`, `README.md`, `Requirements.md`).

Run: `grep -c "Lightdash" /Users/sasha/temp/ai_onboarding/README.md`
Expected: `1` (single mention in Phase 2 walkthrough — not pushed elsewhere).

- [ ] **Step 4: Confirm no orphan references to deleted concepts**

Run: `grep -niE "project_spec_template|copy.paste your spec|spec file" /Users/sasha/temp/ai_onboarding/*.md`
Expected: no output.

- [ ] **Step 5: Confirm skill coverage**

Run:
```bash
for f in /Users/sasha/temp/ai_onboarding/*.md; do
  echo "=== $f ==="
  grep -oE "/brainstorming|/writing-plans|/executing-plans|/verification-before-completion|/systematic-debugging|/test-driven-development|/finishing-a-development-branch|/claude-automation-recommender|/requesting-code-review|plan mode|TaskCreate|auto-memory" "$f" | sort -u
done
```
Expected:
- `CLAUDE.md` lists at least 9 distinct skills plus `plan mode`, `TaskCreate`, `auto-memory`.
- `README.md` lists at least 9 distinct skills plus `plan mode`, `TaskCreate`, `auto-memory`.
- `Requirements.md` lists at least 7 distinct skills (some skills like `/brainstorming` may not appear there; that's fine, README covers them).

- [ ] **Step 6: Read each file end-to-end one final time**

Use `Read` on each of:
- `/Users/sasha/temp/ai_onboarding/CLAUDE.md`
- `/Users/sasha/temp/ai_onboarding/README.md`
- `/Users/sasha/temp/ai_onboarding/Requirements.md`

Confirm the prose reads cleanly and matches the design spec in `docs/superpowers/specs/2026-05-18-ai-onboarding-modernization-design.md`. No half-finished sentences, no contradictions, no skill names that don't actually exist in the available-skills list.

If anything reads awkwardly, fix it inline.

---

## Self-review checklist for the implementer

After all five tasks pass their verification steps, run this final pass:

1. **Spec coverage:** every section of the design spec maps to a task above. Mapping:
   - Design "CLAUDE.md outline" → Task 1
   - Design "README.md outline" → Task 2
   - Design "Requirements.md changes" → Task 3 (six sub-edits map 1:1 to the six bullets in the spec)
   - Design "Files deleted" → Task 4
2. **Placeholders:** none in the plan. Every step has exact paths, exact content, or exact commands.
3. **Type consistency:** N/A for docs work, but skill names should match exactly across all three files (e.g., always `/verification-before-completion`, never `/verify-before-completion`).

If a step fails verification, fix inline. Do not move on with a failing check.
