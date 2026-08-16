# Business Requirements — Invented Software Analytics Platform

**Phase 1 deliverable.** What the platform must answer, and how each number is
calculated. Written against the dataset in `saas/`, verified against the built
models.

---

## 1. The business

Invented Software sells business-management software to small merchants — cafés,
bakeries, salons, florists, food trucks, gyms — across 8 markets in Europe and
the Americas.

Revenue is **subscription-only**. There are no transaction fees, no hardware, no
payment processing. Every euro is recurring, which makes the standard SaaS
metric stack the natural analytical frame and makes `mrr_local` in
`raw_subscriptions` the single source of revenue.

Scale is small and deliberately so: **160 merchants, 117 subscriptions, €18.1k
exit ARR**. The company is unprofitable and burning.

## 2. The data

| Table | Rows | Grain | Role |
|---|---|---|---|
| `raw_merchants` | 160 | one per merchant | customers, with signup and churn dates |
| `raw_subscriptions` | 117 | one per subscription period | **the only revenue source** |
| `raw_products` | 5 | one per SKU | price and cost of revenue |
| `raw_markets` | 8 | one per country | currency and the EUR conversion rate |
| `raw_acquisition_costs` | 768 | month × market × channel | marketing spend |
| `raw_operating_costs` | 144 | month × category | P&L lines **and a cash balance** |

**Relationships:** subscriptions → merchants → markets; subscriptions →
products. Acquisition costs join to markets. Operating costs are company-level
and join only to the calendar.

### 2.1 Three conventions that silently corrupt results

1. **All money is in minor units (cents).** `price_eur = 1900` means €19.00.
   Divide by 100 once, in staging, and never again.
2. **`mrr_local` and `spend_amount` are in local currency.** Convert with
   `raw_markets.eur_fx`: `amount_eur = amount_local * eur_fx`. Operating costs
   are already EUR. Summing a BRL subscription alongside a EUR one without
   converting overstates revenue by roughly 5.5× on the affected rows.
3. **`raw_operating_costs` mixes a stock in with the flows.** The category
   `cash_balance_eom` is an end-of-month *balance* sitting in the same
   `amount_eur` column as five genuine cost categories. An unfiltered
   `SUM(amount_eur)` returns about **€51,000/month** instead of the true
   **€3,419** — a 15× error that still looks like a plausible number, which is
   what makes it dangerous.

Convention 3 is not documented in `README.md` or `Requirements.md`. It was
discovered during Phase 1 and is the strongest argument in this project for
sanity-checking magnitudes against a known anchor before trusting any aggregate.

### 2.2 The central modelling problem

117 subscription rows each carry a `start_date` and sometimes an `end_date`.
Every revenue metric requires these **periods** exploded into **months**: one
row per subscription per month it was active, converted to EUR.

That model is `fct_subscription_month` (3,200 rows). Churn, NRR, LTV, CAC
payback, burn multiple and runway all hang off it. Boundary rule: a subscription
counts in both its start month and its end month; a NULL `end_date` means still
active and runs to the end of the horizon.

## 3. Business questions the platform must answer

| # | Question | Metric | Model |
|---|---|---|---|
| Q1 | What is recurring revenue, and is it growing? | MRR, ARR | `mart_mrr_monthly` |
| Q2 | How much of each euro survives the cost of service? | Gross margin | `mart_gross_margin_monthly` |
| Q3 | What share of customers do we lose? | Logo churn | `mart_churn_monthly` |
| Q4 | Do existing customers grow or shrink? | NRR, revenue churn | `mart_revenue_movement` |
| Q5 | What does a customer cost to acquire? | CAC | `mart_cac_monthly` |
| Q6 | Is a customer worth more than they cost? | LTV, LTV:CAC, payback | `mart_unit_economics` |
| Q7 | How fast is cash leaving, and how long does it last? | Burn, Burn Multiple, Runway | `mart_burn_monthly` |

## 4. Calculation specifications

### Q1 — MRR / ARR
- **Source:** `fct_subscription_month`
- **Formula:** `MRR[m] = sum(mrr_eur)` for month `m`; `ARR = MRR × 12`
- **Grain:** month
- **Additivity:** MRR is **semi-additive** — it sums across merchants, products
  and markets but **never across time**. Summing MRR over 12 months produces a
  meaningless number.
- **Verified:** €1,137.85 (2024-01), €1,640.77 (2024-12), €1,509.78 (2025-12)

### Q2 — Gross Profit Margin
- **Source:** `fct_subscription_month` (`mrr_eur`, `cogs_eur` from `dim_product`)
- **Formula:** `(revenue − COGS) / revenue`
- **Caution:** COGS comes from the product catalogue, **not** from
  `fct_operating_cost.cost_of_revenue`. Applying the margin *and* subtracting
  the operating-cost line charges cost of revenue twice.
- **Verified:** 84.9% blended

### Q3 — Logo Churn
- **Source:** `int_merchant_months` (paying merchants only)
- **Formula:** merchants with revenue last month and none this month ÷ merchants
  with revenue entering the month
- **Denominator is paying merchants, not all merchants.** 65 of the 160 rows in
  `dim_merchant` never held a subscription. Including them inflated the base by
  roughly 1.7× and put 4 never-paying merchants into the numerator.
- **Detection matches `mart_revenue_movement`** — MRR present last month, absent
  this month. Keying off `churn_date` instead placed logo churn one month before
  the revenue it removed, because a subscription counts through its end month
  inclusive, so the two series described different cohorts.

### Q4 — NRR and Revenue Churn
- **Source:** `int_merchant_months` (merchant grain, not subscription grain)
- **Buckets:** new / expansion / contraction / churned, by comparing each
  merchant's MRR to the prior month
- **Formulas:**
  - `gross revenue churn = churned ÷ starting`
  - `NRR = (starting + expansion − contraction − churned) ÷ starting`
- **Why merchant grain:** a merchant swapping a cheap plan for an expensive one
  is *expansion*. At subscription grain it looks like a churn plus a new sale.
- **Caveat:** only 9 rows carry `previous_plan_sku`, 8 of them upgrades from
  free. NRR is directionally right, statistically thin. Averages 100.9%.

### Q5 — CAC
- **Source:** `fct_acquisition_spend`, `dim_merchant.signup_month`
- **Formula:** `spend[m] ÷ new merchants[m]`
- **Two deliberate NULLs**, which must not be conflated:
  - *no spend data* — months before 2024-01, where spend was never reported.
    Returning 0 would read as "customers were free."
  - *no signups* — undefined, not infinite.
- **Known anomaly:** the last merchant signed up **2024-06-29**, yet €16,856 of
  spend is booked across 2025. That spend acquired nobody and is reported as
  `unattributed_spend_eur`.

### Q6 — LTV, CAC Payback, LTV:CAC
- **Source:** `mart_unit_economics`, window 2024-01 to 2025-12 (the period with
  cost data)
- **Formulas:**
  - `LTV = ARPA × gross margin × expected lifetime`
  - `CAC payback = CAC ÷ (ARPA × gross margin)`
  - `LTV:CAC = LTV ÷ CAC`
- **Lifetime is capped at 60 months.** Only 8 of 42 months contain any churn, so
  `1 ÷ churn` implies a 230-month (19-year) customer life. That is a thin-sample
  artefact, not a retention curve. Uncapped LTV is retained for contrast.
- **Two CAC answers are reported**, because they answer different questions and
  disagree sharply:

  | | Attributed | Blended |
  |---|---|---|
  | CAC | €238.24 | €1,013.72 |
  | Payback | 15.6 months | 66.5 months |
  | LTV:CAC | 3.84 | **0.90** |

  The attributed view uses only the spend that fell in months with acquisitions.
  The blended view counts every euro. **The blended figure is the one a CFO
  should act on**: at **0.90 it is below 1.0**, meaning that counting all
  acquisition spend, each customer costs more to win than they are worth.

  **Denominator note.** CAC counts *acquired customers*, not signups. Only 32 of
  the 46 merchants who signed up in the window ever held a subscription — 65 of
  the 160 merchants in the dataset never subscribed at all. Dividing by signups
  understated CAC by 44% and made LTV:CAC incoherent, because LTV is built from
  ARPA over paying merchants. Both halves of the ratio must describe the same
  population.

### Q7 — Burn, Burn Multiple, Runway
- **Source:** `fct_subscription_month`, `fct_operating_cost`, `fct_acquisition_spend`
- **Formula:** `burn = revenue − operating costs − acquisition spend`
- **Acquisition spend is included.** It is real cash out and **not** a subset of
  the `sales_and_marketing` cost line — at €1,352/month it is *larger* than that
  line's €932/month, so the two are independent. Excluding it understates burn
  by 42%.
- **Burn Multiple** = net burn ÷ net new ARR. NULL when ARR shrinks, because
  efficiency of growth is undefined without growth.
- **Verified:** €3,253/month average burn, €3,716 in the exit month.

### Q7a — The cash ledger is not trustworthy

`cash_balance_eom` **contradicts the P&L**. Recorded cash rises €49,785 →
€57,235 across 2024–25, while the P&L implies a €3,253/month burn that would
leave the company insolvent from May 2025. The divergence is €85,519.

Regression analysis settles which is wrong:

| Test | Result |
|---|---|
| monthly cash change ~ linear in time | **R² = 0.971** (`d_cash = −227.7 + 50.1·t`) |
| cash level ~ quadratic in time | **R² = 0.9992** |
| corr(cash change, time) | **+0.985** |
| corr(cash change, revenue) | +0.401 |

The series is a **function of time, not of the business** — a synthetic J-curve.
No real mechanism produces this: financing is lumpy, accrual timing oscillates,
non-cash expenses are flat or step-shaped. A smooth monotonic ramp is none of
these.

**Decision: burn is derived from the P&L.** The recorded balance is carried for
comparison only, with `ledger_vs_pnl_gap_eur` exposing the divergence per month.
Runway (~15 months) rests on that disputed balance and is indicative only.

## 5. Success metrics for the platform

| Criterion | Target | Actual |
|---|---|---|
| One-command startup from clean | works | ✅ 261 s |
| Data pipeline runs without errors | 0 errors | ✅ `PASS=102 ERROR=0` |
| Every dashboard card returns data | 100% | ✅ 18/18 |
| Marts reproduce known-good figures | exact | ✅ `assert_known_kpi_values` |
| Source data quality gated before modelling | enforced | ✅ `assert_source_integrity` |
| Every widget traces to a business question | 100% | ✅ Q1–Q7 |

## 6. Out of scope

Predictive forecasting, cohort retention curves, real-time alerting, and
customer segmentation beyond the drill-downs in the operational dashboard.
