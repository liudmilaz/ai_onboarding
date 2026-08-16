# AI Onboarding Modernization — Design Spec

**Date:** 2026-05-18
**Status:** Awaiting user review before implementation plan

## Background

This repository (`ai_onboarding`) is a training project for data analysts who are new to AI-assisted development. The trainee builds a small end-to-end analytics platform (CSV → database → dbt → BI) for a fictional jaffle cafe, using Claude Code as their pair programmer.

The current state of the repo was authored before Claude Code's skills system, plan mode, auto-memory, and TaskCreate were widely used. As a result:

- The custom "PRP-like" workflow described in `CLAUDE.md` duplicates what built-in skills (`brainstorming`, `writing-plans`, `executing-plans`, `verification-before-completion`) now provide natively.
- Manual context-management advice ("copy-paste your spec at session start") is obsolete now that auto-memory, persistent sessions, and plan mode exist.
- The tone instructions include awkward "sweetheart / love" examples and a "mansplaining slip-up" recovery passage that are embarrassing to ship to a new colleague.
- There is no guidance to use skills at all — neither workflow skills nor the tool-specific skills/plugins/MCPs the community has built.

## Goal

Modernize the onboarding so a brand-new Claude Code user, on day one, learns the habits and skills that experienced users rely on. Specifically: structured planning via plan mode, skill-first workflows, proactive verification, and persistent context via auto-memory and TaskCreate.

## Out of scope

- Changing the analytics project itself (data, phase arc, deliverables) — those work and don't need rework.
- Pre-naming specific tool-skill/plugin/MCP combinations the trainee should install. Skill availability changes fast; the doc teaches discovery patterns rather than shipping a stale catalog.
- Worktrees, hooks, scheduled agents, or other advanced features beyond what serves a first-time user.

## File-level changes

| File | Change |
|------|--------|
| `README.md` | **NEW.** Trainee-facing. Project intro + Claude Code primer + phase walkthrough with per-phase skill callouts + working habits. |
| `CLAUDE.md` | **REWRITTEN.** AI-facing only. Terser (~70 lines vs. 230). Mentor role (positive framing), per-phase playbook telling the AI which skills to suggest, plan-mode-first rule, definition of done. |
| `Requirements.md` | **MODERNIZED.** Same 6 phases, same deliverables. Adds per-phase skill callouts, softens the rigid phase-branch prescription, adds Lightdash to the BI-platform examples list, adds a Phase 2 sub-task to check for tool-specific skills/plugins/MCPs, mentions `claude-automation-recommender` as a Phase 6 bonus. |
| `project_spec_template.md` | **DELETED.** Auto-memory + plan mode + TaskCreate replace it. |

## CLAUDE.md outline (AI-facing)

```
1. Project overview (3 lines, unchanged content)

2. Your role: BI Architect Mentor (~8 lines)
   - Mentor whose goal is to teach, not to do work for the trainee
   - Trainee owns WHAT/WHY decisions; AI provides HOW
   - Warm, patient, encouraging tone
   - (positive framing only — no "don't do X" examples)

3. Set the goal first: use plan mode (~6 lines)
   - For any non-trivial step, enter plan mode before editing or running
   - Plan mode is how trainee and AI agree on the goal before action
   - Exit plan mode only after the trainee approves the plan

4. Per-phase playbook (~30 lines)
   For each of the 6 phases, one block:
     * skill(s) to suggest
     * red flag(s) specific to this phase

   Phase 1 — Data Discovery
     Suggest: /brainstorming for business-question refinement.
     Red flag: trainee skips understanding the data and jumps to tools.

   Phase 2 — Architecture & Tech Research
     Suggest: /brainstorming for tech choices, /writing-plans for setup.
     Proactively prompt: "For each tool you're considering, have you
     checked whether a Claude Code skill, plugin, or MCP server exists
     for it? Try /plugins or search the marketplace."
     If trainee is shortlisting BI platforms and hasn't considered
     Lightdash, surface it as worth evaluating (open source,
     self-hostable, dbt-native, AI features). Then step back.
     Red flags:
       - trainee picks a tool without articulating trade-offs
       - trainee doesn't check for tool-specific skill availability

   Phase 3 — Database Implementation
     Suggest: /executing-plans against the Phase 2 plan,
     /systematic-debugging if things break.
     Red flag: trainee runs commands without entering plan mode first.

   Phase 4 — Data Modeling with dbt
     Suggest: /test-driven-development for dbt tests,
     /executing-plans for staging→marts work.
     Red flag: models without tests; "I'll add tests later" is a trap.

   Phase 5 — BI Platform
     Suggest: /executing-plans, /requesting-code-review at the end.
     Red flag: dashboards built without confirming the underlying
     dbt models are the right ones to expose.

   Phase 6 — Integration & Automation
     Suggest: /finishing-a-development-branch when wrapping up,
     /claude-automation-recommender as a meta-exercise.
     Red flag: claiming "one-command startup" without actually
     running it end-to-end from a clean state.

5. Other built-in capabilities to use proactively (~10 lines)
   - TaskCreate for progress tracking (replaces the deleted spec template)
   - Subagents (Agent tool) for research/exploration without burning
     main-conversation context
   - Auto-memory: capture decisions and lessons learned there, not
     in a spec file

6. Learning verification (~8 lines, mostly preserved from current doc)
   - Have the trainee explain decisions back in their own words
   - Red flags: too-quick agreement, can't justify a choice,
     "yes" without follow-up questions

7. Definition of done (~4 lines)
   - Before claiming any phase complete, invoke /verification-before-completion
   - Evidence (working command, test output) before assertion of done
```

## README.md outline (trainee-facing, NEW)

```
1. Welcome (~5 lines)
   - What this project is, who it's for, what you'll learn

2. How Claude Code works (~20 lines, essential minimum)
   - Slash-invoked skills: /name to invoke a reusable workflow
   - Plan mode: agree on the goal before the AI edits anything
   - Auto-memory: decisions persist across sessions automatically
   - TaskCreate / todo tracking: visible progress
   - Subagents: delegate research without crowding your conversation
   - "type /help anytime"

3. The skills you'll meet in this project (~15 lines, teaser only)
   - One-liner each for:
       * /brainstorming
       * /writing-plans
       * /executing-plans
       * /verification-before-completion
       * /systematic-debugging
       * /test-driven-development
   - "Each phase below tells you when — no need to memorize"

4. Phase walkthrough (~60 lines)
   For each of the 6 phases (mirrors Requirements.md):
     * Goal (1 line)
     * Skills to invoke, in order (3–5 lines)
     * Deliverable
     * "Before claiming done": /verification-before-completion

   Phase 2 contains additional discovery prose:
     - Two parallel threads: pick tools + check for tool-specific
       Claude Code skills/plugins/MCPs
     - Note that Lightdash is worth putting on the shortlist
       (open source, self-hostable, dbt-native, AI features) —
       the choice is still yours, document trade-offs in the ADR

5. Working habits worth building (~10 lines)
   - Specific prompts beat vague ones (condensed from current CLAUDE.md)
   - When stuck: /systematic-debugging before guessing
   - When done: /verification-before-completion before saying done
   - Capture lessons in auto-memory so the next session builds on this one

6. Files in this repo (~5 lines)
   - Requirements.md — full spec & deliverables
   - data/ — sample CSVs
   - CLAUDE.md — instructions for the AI (you don't need to read this)
```

## Requirements.md changes

- **Per-phase skill callouts** added under each existing phase (in "spec / deliverables" voice rather than "tutorial" voice, complementing README.md's friendlier walkthrough).
- **Phase 1 "first step":** replace the bare "git init + first commit" with a softer note: "Run `/init` to seed a CLAUDE.md if it's missing, then git init and a first commit. Feature branches per phase are optional — they're useful practice but not required for solo work."
- **Phase 2:** Update the BI-platform examples list from `(Grafana, Metabase, Apache Superset, etc.)` to `(Lightdash, Grafana, Metabase, Apache Superset, etc.)` — same weight as the others.
- **Phase 2:** Add a sub-task: "For each tool on your shortlist, check whether a public Claude Code skill, plugin, or MCP server exists for it (`/plugins`, marketplace, web search). Document discoveries in the ADR."
- **AI Development Process Report deliverable:** add "log which skills you used in each phase and which paid off."
- **Bonus Challenges:** add one new optional item — "Run the `claude-automation-recommender` skill against your finished repo and propose two Claude Code automations (hook, subagent, custom skill) that would improve the project."
- **No structural change** to phase order, names, or deliverables otherwise.

## Files deleted

- `project_spec_template.md` — superseded by auto-memory + plan mode + TaskCreate. CLAUDE.md instructs the AI to use those mechanisms proactively.

## Open questions

None identified at this stage. The design has been iteratively refined through the brainstorming session with the user.

## Next step

Hand off to the `writing-plans` skill to produce a step-by-step implementation plan (which files to touch in what order, what to verify after each change).
