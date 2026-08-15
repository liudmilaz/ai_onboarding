# AI Onboarding — SaaS Analytics Platform

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
./start.sh
```

It creates a Python environment if missing, starts Colima and the containers, waits for Postgres, runs the data-quality gate in `db/validate.sql`, builds the dbt models, then provisions Metabase — admin user, database connection, five cards and the executive dashboard at <http://localhost:3000/dashboard/2>.

```bash
./start.sh --clean
```

Destroys the containers and volumes first, so the run proves a genuine cold start.

**Verified end to end**: from `docker compose down -v` to a live dashboard in **210 seconds**, with `dbt build` reporting `PASS=55 ERROR=0`. The marts reproduce the figures in `HANDOFF.md` §4 exactly — MRR €1,138 / €1,641 / €1,510 and exit ARR €18,117.

Re-running is safe: cards and the dashboard are matched by name and reused rather than duplicated, and Metabase's bundled H2 sample database is removed during provisioning.

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
| `dbt/models/marts/` | MRR/ARR, gross margin, logo churn. |
| `dbt/tests/` | `assert_known_kpi_values` pins the figures published in `HANDOFF.md` §4 as a regression anchor; `assert_source_integrity` checks row counts and the rules generic tests can't express. |
| `db/` | Postgres schema, CSV loaders, and the data-quality gate run before modelling. |
| `scripts/` | Metabase provisioning. |
| `docker-compose.yml` | Postgres 16 and Metabase, with healthchecks gating startup order. |
