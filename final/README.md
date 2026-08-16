# AI Onboarding — SaaS Analytics Platform (built)

> This is the **`final/`** folder — the working platform. The project as it was
> issued, unmodified, is preserved in [`../initial/`](../initial/). The six CSVs
> in both folders are byte-identical.

**To start: open Claude Code in this directory and say "I'm ready."** Claude will walk you through the project step by step, explaining each concept and checking that you understand before moving on. You don't need to read anything else first.

This is a training project for data analysts learning AI-assisted development. You'll build an end-to-end analytics platform (CSV → database → dbt → BI dashboard) for **Invented Software**, a fictional B2B SaaS company selling business-management software to small merchants — cafés, bakeries, salons, florists, food trucks, gyms. Along the way you'll pick up the workflows and habits that experienced Claude Code users rely on.

The company earns **subscription revenue only**. There are no transaction fees, no hardware, no payment processing — every euro of revenue is recurring, which makes this a clean dataset for learning the standard SaaS metric stack.

## Files in this repo

- `saas/` — sample CSVs representing the company's operational data (see table overview below).
- `Requirements.md` — the full project spec and deliverables. Claude reads this to know what you're building; you don't have to.
- `CLAUDE.md` — Claude's playbook for mentoring you through the project. Claude reads this; you don't have to.

## Data overview

Six raw tables covering two years (2024–2025) across 8 markets and 160 merchants:

| Table | Description | Key fields |
|---|---|---|
| `raw_merchants` | Small businesses subscribing to Invented Software (the customers) | `merchant_id`, `business_type`, `country_code`, `plan_type`, `signup_date`, `status`, `churn_date` |
| `raw_subscriptions` | Active and cancelled subscription periods — the sole revenue source | `plan_sku`, `start_date`, `end_date`, `mrr_local`, `currency`, `cancellation_reason`, `previous_plan_sku` |
| `raw_products` | Product catalogue: subscription plans and software add-ons | `sku`, `type`, `price_eur`, `cogs_eur`, `gross_margin_pct` |
| `raw_markets` | Countries where the company operates | `country_code`, `currency`, `eur_fx`, `launch_year`, `vat_rate` |
| `raw_acquisition_costs` | Monthly marketing & sales spend by market and channel | `channel`, `spend_amount`, `currency` |
| `raw_operating_costs` | Monthly company P&L inputs including cash balance | `cost_category`, `amount_eur` |

**Two conventions worth knowing before you model:**

- **All money is stored in minor units** (cents). `price_eur = 1900` means €19.00.
- **`mrr_local` and `spend_amount` are in local currency.** Join to `raw_markets.eur_fx` to convert: `amount_eur = amount_local * eur_fx`. Operating costs are already in EUR.

The dataset is designed so the following SaaS metrics can be computed in the dbt mart layer: **MRR, ARR, Churn Rate, NRR, LTV, CAC, CAC Payback Period, LTV:CAC, Gross Profit Margin, Burn Multiple, Cash Runway**.

If something goes sideways during onboarding, you can always tell Claude "let's back up" — the pace is yours to set.

## Running the platform

The stack is **Postgres + dbt + Metabase, containerized with Docker Compose**. One command brings it all up:

```bash
cd final
./start.sh
```

It creates a Python environment if missing, starts Colima and the containers, waits for Postgres, runs the data-quality gate in `db/validate.sql`, builds the dbt models, then provisions Metabase — admin user, database connection, a collection, a read-only analyst group, and two dashboards:

- **Executive** — <http://localhost:3000/dashboard/2>: MRR/ARR, NRR, gross margin, logo churn, net burn, LTV:CAC, runway, unit-economics scorecard
- **Operational** — <http://localhost:3000/dashboard/3>: drill-downs by market, business type, plan and channel, the MRR waterfall, CAC by month, and the ledger-vs-P&L divergence

```bash
./start.sh --clean     # destroy containers and volumes first - cold-start proof
./start.sh --refresh   # reload the CSVs and rebuild, containers left running
./start.sh --help
```

Every run is logged to `logs/run-<timestamp>.log`. Failures report the step,
line, command and a targeted hint rather than a bare stack trace.

**Refreshing data** replaces the CSVs in `saas/` and runs `./start.sh --refresh`
(53 s). Nothing touches the database until the CSVs satisfy
`db/schema_contract.json` — `COPY` maps columns by *position*, so a reordering of
two same-typed columns would otherwise load silently and corrupt every
downstream number. If a schema change is intended, accept it with
`python3 scripts/validate_csv_schema.py --generate`.

**Verified end to end**: from `docker compose down -v` to live dashboards in **261 seconds**, with `dbt build` reporting `PASS=102 ERROR=0` across 25 models and 77 tests, and **18 of 18 dashboard cards returning data**. The marts reproduce the figures in `HANDOFF.md` §4 exactly — MRR €1,138 / €1,641 / €1,510 and exit ARR €18,117.

Re-running is safe: cards and dashboards are matched by name and **updated** to match the definitions in `scripts/provision_metabase.py`, cards no longer defined are archived, and Metabase's bundled H2 sample database is removed.

Credentials are generated into `.env` on first run (gitignored). The Metabase login is printed at the end of `./start.sh`; the email defaults to `analyst@invented.software`.

Three environment details this stack depends on, each of which cost time to find:

- **Colima needs `--vm-type vz` on Apple Silicon.** The default falls back to QEMU, which isn't installed, and then hangs silently rather than erroring.
- **The Colima VM and its image cache are per-user.** A second account on the same Mac starts from zero.
- **Homebrew installs the Compose CLI plugin only for the installing user.** On another account `docker compose` fails with `unknown shorthand flag: 'd'` and the standalone `docker-compose` binary is the working path — `start.sh` detects which is available.

### Layout

| Path | What it is |
|---|---|
| `dbt/models/staging/` | One model per raw table. Minor units and local currency are converted here and nowhere else. |
| `dbt/models/intermediate/` | `int_subscription_months` — the spine: 117 subscription periods exploded to one row per subscription per active month. |
| `docs/` | Business requirements, ADRs, database schema, operations manual, AI process report. |
| `dbt/models/marts/` | Kimball star — `dim_*` conformed dimensions, `fct_*` facts with declared grain and additivity, `mart_*` KPI models. |
| `dbt/tests/` | `assert_known_kpi_values` pins the figures published in `HANDOFF.md` §4 as a regression anchor; `assert_source_integrity` checks row counts and the rules generic tests can't express. |
| `db/` | Postgres schema, CSV loaders, and the data-quality gate run before modelling. |
| `scripts/` | Metabase provisioning and the CSV schema-contract validator. |
| `docker-compose.yml` | Postgres 16 and Metabase, with healthchecks gating startup order. |

## The eleven KPIs

| KPI | Model |
|---|---|
| MRR, ARR | `mart_mrr_monthly` |
| Gross Profit Margin | `mart_gross_margin_monthly` |
| Churn Rate (logo) | `mart_churn_monthly` |
| Churn Rate (revenue), NRR | `mart_revenue_movement` |
| CAC | `mart_cac_monthly` |
| LTV, CAC Payback, LTV:CAC | `mart_unit_economics` |
| Burn Multiple, Cash Runway | `mart_burn_monthly` |

Two carry deliberate caveats, both documented in the models and in
`docs/business_requirements.md`:

- **CAC is reported twice.** Attributed (€165.73, using the 23.5% of spend that
  fell in months with signups) and blended (€705.20, counting every euro). They
  give LTV:CAC of 5.52 and **1.30** respectively — the blended figure is the one
  to act on.
- **Burn is derived from the P&L, not the cash ledger.** The recorded
  `cash_balance_eom` series contradicts the P&L by €85,519 and is a function of
  time rather than of the business (R² = 0.971 against a linear trend). See
  `docs/business_requirements.md` §Q7a.

## Documentation

```bash
cd dbt && ../.venv/bin/dbt docs generate --profiles-dir profiles
../.venv/bin/dbt docs serve --profiles-dir profiles     # lineage graph, tests, columns
```

| Document | Contents |
|---|---|
| `docs/business_requirements.md` | Business questions, calculation specs, data conventions |
| `docs/adr.md` | Seven architecture decision records with consequences |
| `docs/database_schema.md` | All 31 tables, generated from `information_schema` |
| `docs/operations.md` | Running, refreshing, troubleshooting, backup, capacity |
| `docs/ai_process_report.md` | How this was built with AI, including what failed |
