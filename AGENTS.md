# AGENTS.md — repository root

Instructions for any coding agent working in this repository — Claude Code,
Cursor, Codex, Copilot, Gemini CLI or otherwise. Nothing here depends on a
specific tool.

## What this repository is

| Folder | What it is |
|---|---|
| `initial/` | The training project **as issued** — dataset, spec, and the mentoring playbook. |
| `final/` | A **reference implementation**: Postgres + dbt + a BI tool, containerized. Arrives in a separate pull request. |

They are kept apart so a trainee can start from `initial/` without the answers
in view, and so the two can be diffed afterwards. If you are unsure which the
user means, ask before editing.

## If you are mentoring someone through the project

Your instructions are **`initial/AGENTS.md`** — a per-phase playbook with
narration, comprehension checks and pacing rules. Read it and follow it rather
than improvising a curriculum; that file is the product.

Read, in this order:

1. `initial/AGENTS.md` — the playbook, and your actual instructions
2. `initial/prerequisites.md` — what the trainee must install before Phase 3
3. `initial/data-guide.md` — data conventions, traps, and expected results
4. `initial/requirements.md` — the spec: six phases and deliverables

**Have the trainee work on a copy, not on `initial/` itself:**

```bash
cp -r initial workspace && cd workspace
```

`initial/` is the control. If they build in place, there is nothing left to
compare against.

## Spoiler control — read this before Phase 1

You will read this repository and therefore know the answers. **The trainee's
job is to find them; yours is to ask the questions that make that possible.**

Never state a finding the trainee has not reached. Do not open Phase 1 by
listing the data traps. Ask them to compute something, let the number look
wrong, and ask whether it is plausible. If they are stuck after two genuine
attempts, narrow the question rather than answering it.

This matters most for the three defects described in `initial/data-guide.md`.
Handing those over is the single fastest way to make the workshop pointless.

## Working on the reference implementation

Everything is in `final/`. Start with `final/README.md`, then
`final/docs/operations.md` to run it and `final/docs/adr.md` for why it is
shaped as it is.

## True of both folders

**The CSVs in `initial/data/` and `final/saas/` are byte-identical.** The
dataset contains defects that were resolved in the models rather than patched in
the data, and matching checksums are what make that claim checkable. Do not
"fix" a CSV in either folder.

**The company is fictional and the data is synthetic.** Invented Software does
not exist; every figure is generated. Never present these numbers as a benchmark
or as a claim about any real market.

**Three data conventions**, each of which silently corrupts results if missed —
stated in full, with the join paths, in `initial/data-guide.md`:

1. All money is in **minor units** (cents). `price_eur = 1900` means €19.00.
2. `mrr_local` and `spend_amount` are in **local currency**. Convert via
   `raw_markets.eur_fx`, joining `raw_subscriptions → raw_merchants.country_code
   → raw_markets`. Joining on `currency` instead fans 117 rows into 300.
3. `raw_operating_costs` mixes a **stock in with the flows**: `cost_category =
   'cash_balance_eom'` is a balance, not a cost, and is 93.8% of the column by
   value. An unfiltered `SUM` returns €54,814/month against a true €3,419.
