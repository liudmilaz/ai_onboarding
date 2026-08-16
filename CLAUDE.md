# CLAUDE.md — repository root

This repository holds two things. Which one you are working on determines
everything else, so establish that first.

| Folder | What it is |
|---|---|
| `initial/` | The training project **as issued** — dataset, spec, mentoring playbook. Preserved unmodified. |
| `final/` | The **built** analytics platform: Postgres + dbt + Metabase in Docker Compose. |

## If the user wants to be taught the project

They are here to work through `initial/`, and **the mentoring playbook is
`initial/CLAUDE.md`** — a 212-line per-phase script with narration, comprehension
checks and pacing rules. Read it and follow it. Do not improvise a curriculum;
that file is the product.

Read these too, in this order:

1. `initial/CLAUDE.md` — the playbook, and your actual instructions
2. `initial/ERRATA.md` — **corrections to the shipped answer key.** Four figures
   in `HANDOFF.md` §4 are wrong, and that file tells the trainee "if your dbt
   marts disagree, the models are wrong, not the data." Read the errata before
   using any figure from it to grade someone's work.
3. `initial/HANDOFF.md` — data conventions and expected results
4. `initial/Requirements.md` — the spec: six phases and deliverables

Do not run `/init` inside `initial/`. It would overwrite `initial/CLAUDE.md`
with a generated summary, destroying the playbook.

Ignore `initial/docs/superpowers/`. It describes a different fictional company
and a directory layout that no longer exists.

## If the user wants to work on the built platform

Everything lives in `final/`. Start with `final/README.md`, then
`final/docs/operations.md` for running it and `final/docs/adr.md` for why it is
shaped the way it is.

```bash
cd final && ./start.sh
```

The stack is Postgres 16 + Metabase in Docker Compose, with dbt run from a host
venv against the published port. Cold start is about two and a half minutes.

## Things that are true of both folders

**The six CSVs in `initial/saas/` and `final/saas/` are byte-identical.** That
is deliberate and load-bearing: the dataset contains defects that were resolved
in the models rather than patched in the data, and identical checksums are what
make that claim checkable. Do not "fix" a CSV in either folder.

**The company is fictional and the data is synthetic.** Invented Software does
not exist; every figure is generated. Never present these numbers as a benchmark
or as a claim about any real market.

**Three data conventions**, each of which silently corrupts results:

1. All money is in **minor units** (cents). `price_eur = 1900` means €19.00.
2. `mrr_local` and `spend_amount` are in **local currency** — convert via
   `raw_markets.eur_fx`. Operating costs are already EUR.
3. `raw_operating_costs` mixes a **stock in with the flows**: `cost_category =
   'cash_balance_eom'` is a balance, not a cost. An unfiltered `SUM(amount_eur)`
   returns €54,814/month against a true €3,419 — **16× too high**, and plausible
   enough to pass a smell test.
