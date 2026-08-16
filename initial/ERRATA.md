# Errata to the shipped project

**This file is not part of the original project.** Everything else in `initial/`
is preserved exactly as issued, which is the point of the folder — the six CSVs
are byte-identical to the ones the built platform reads, so "we solved the data
problems in the models rather than by editing the data" is verifiable by
checksum rather than asserted.

That guarantee is worth more than a tidy answer key, so the errors below are
corrected **here** rather than edited into the files that contain them.

Every figure was recomputed from the CSVs in this folder and confirmed against
the built platform.

---

## 1. Read this before trusting `HANDOFF.md` §4

`HANDOFF.md:65` says:

> If your dbt marts disagree, the models are wrong, not the data.

**Do not follow that instruction.** Four figures in that table are wrong, and
the sentence turns them from harmless errors into active harm: a trainee who
models correctly is told their model is broken and pushed to keep changing it
until it reproduces the mistake.

| Metric | `HANDOFF.md` says | Correct | Why |
|---|---|---|---|
| Net burn | €1,909/month | **€3,253/month** | Omits acquisition spend entirely |
| Implied runway | ~30 months | **~17.6 months** | Inherits the burn error |
| Logo churn (24m) | 8.1% (13 of 160) | **9.5% (9 of 95)** | Counts merchants who never paid |
| Naive CAC | ~€705 | **€1,013.72** | Divides by signups, not customers |

### Net burn and runway

€1,909 ≈ €3,419 operating costs − €1,510 exit MRR. It never subtracts
`raw_acquisition_costs`, which is **€1,352/month** of real cash leaving the bank.

Acquisition spend is *not* a subset of the `sales_and_marketing` operating-cost
line — at €1,352/month it is larger than that line's €932/month, so the two are
independent and both belong in burn. Correct:

```
€1,517 revenue − €3,419 operating costs − €1,352 acquisition = −€3,253/month
```

Runway follows: €57,235 ÷ €3,253 = **17.6 months**, not 30. That is the
difference between "two and a half years of cash" and "under eighteen months" —
a business conclusion, not a rounding difference.

### Logo churn

13 of 160 counts a population that includes **65 merchants who never held a
subscription**, and 4 of the 13 "churned" merchants never held one either. On
the paying base the answer is **9 of 95 = 9.5%**.

### CAC

€32,439 ÷ 46 signups = €705. But only **32** of those 46 signups ever
subscribed. Dividing by customers gives €1,013.72 blended. This matters beyond
the number: LTV is built from ARPA over *paying* merchants, so pairing it with a
CAC computed over *signups* makes LTV:CAC incoherent — both halves of a ratio
must describe the same population.

## 2. Two figures that are right but load-bearing on an undocumented step

**Operating costs €3,419/month** is correct **only after excluding
`cost_category = 'cash_balance_eom'`**, which is a cash *balance* sitting in the
same `amount_eur` column as five genuine cost categories. An unfiltered
`SUM(amount_eur)` gives **€54,814/month — 16× too high**, and still looks like a
plausible number. Nothing in `initial/` documents this. It is arguably the most
instructive thing in the dataset, so it is stated here rather than hidden.

**Blended gross margin 84.9%** is correct when COGS comes from
`raw_products.cogs_eur`. The equally natural route — revenue minus the
`cost_of_revenue` line in `raw_operating_costs` — gives **67.5%**. Both are
defensible readings of "gross margin"; they are different metrics. Applying the
84.9% margin *and* subtracting the operating-cost line charges cost of revenue
twice.

## 3. Smaller factual corrections

| Location | Says | Actually |
|---|---|---|
| `HANDOFF.md:85` | "8 of those upgrade from `free`" | **All 9** do |
| `HANDOFF.md:107` | first commit `60dd770` | No such object; roots are `1efb3f9` and `2ffb7a5` |
| `HANDOFF.md:23` | archive at `claude code project/_archive…` | It is a **sibling** of that directory |
| `HANDOFF.md:19` | `raw_transactions.csv`, 110,398 rows, archived | The file on disk is **0 bytes** — those rows are gone |

## 4. Environment corrections

**Installing the skills takes two steps, not one.** `HANDOFF.md:109` gives only:

```
/plugin marketplace add obra/superpowers
```

That registers the marketplace. The plugin still has to be installed afterwards,
so running exactly that line leaves you with the silent no-op failure the same
sentence warns about. Verify with `/plugins` that the skills are actually
present before relying on them.

The list in that sentence also omits `/requesting-code-review` (Phase 5) and
`/claude-automation-recommender` (Phase 6), both of which `CLAUDE.md` and
`Requirements.md` reference.

**`Requirements.md:30` says to run `/init` as the first step.** Do **not** run it
inside `initial/` — `/init` writes a `CLAUDE.md` by analysing the directory, and
it will overwrite the 212-line mentoring playbook that is the whole point of
this folder. The same line's `git init` instruction also conflicts with
`HANDOFF.md:107`, which says the repository is already initialised; running it
inside `initial/` creates a nested repository whose commits are invisible to the
outer one.

**`docs/superpowers/` is stale.** 806 lines describing a different fictional
company ("jaffle cafe"), a `data/` directory that does not exist here, and a
Postgres database named `jaffle_shop`. `HANDOFF.md:115` says to ignore it;
nothing else does, and an agent grepping the working directory for orientation
will surface the wrong company and the wrong paths. Treat it as archaeology.
