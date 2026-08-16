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
