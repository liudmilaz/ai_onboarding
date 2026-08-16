# Session Handoff — read this before starting Phase 1

**Written:** 2026-08-14. **Purpose:** carry findings from the setup session into the workshop session.

This file exists because the dataset in `saas/` **is not the one this project originally shipped with**. If you skip everything else here, read section 1.

---

## 1. The dataset was rebuilt as subscription-only

The project originally modelled a **B2B card payment acquirer** — merchants took card payments, the company earned transaction fees plus subscription revenue plus hardware sales. That was deliberately reduced to a **pure subscription SaaS** business: *Invented Software*, selling business-management software to small merchants (cafés, bakeries, salons, florists, food trucks, gyms).

**Every euro of revenue is now recurring.** There are no transaction fees, no interchange, no payouts, no hardware.

### What was removed

| File | Rows | Why |
|---|---|---|
| `raw_transactions.csv` | 110,398 | The entire card-fee engine |
| `raw_payouts.csv` | 3,587 | Merchant settlements — meaningless without processing |
| `raw_hardware_orders.csv` | 198 | Card readers / POS / kiosks |

Archived to Google Drive at `claude code project/_archive_ai_onboarding_payments_layer/` if ever needed. Not in git.

### What was changed

- **`raw_products.csv`** — dropped 5 hardware SKUs. The two `FS-*` financial-service SKUs became software add-ons: `FS-001` → `SW-004 Insights Basic`, `FS-002` → `SW-005 Insights Pro`. Catalogue is now 5 software SKUs; `type` is only `subscription` or `software`.
- **`raw_subscriptions.csv`** — 25 rows remapped to the new SKUs. Row count and MRR unchanged.
- **`raw_markets.csv`** — dropped `standard_fee_rate` / `premium_fee_rate`, **added `eur_fx`**.

The original product names were thinly-veiled real-company products, and the card-scheme columns carried real card-network brands. All removed — the company is entirely fictional now.

### Why `eur_fx` had to be added

`mrr_local` is denominated in BRL/GBP/USD/PLN/EUR and the markets table had **no conversion rate**. Survivable when card fees were the main revenue line; fatal once MRR is the *only* revenue, because company-wide MRR couldn't be computed at all.

The rates were **derived from the data, not invented**: `price_eur / mrr_local` is constant per currency across all three plans, and the implied rates are exactly 0.86 GBP, 5.5 BRL, 4.3 PLN, 1.08 USD per EUR. `eur_fx` is the inverse of those.

---

## 2. Data conventions — both silently corrupt results if missed

1. **All money is in minor units (cents).** `price_eur = 1900` means €19.00.
2. **`mrr_local` and `spend_amount` are in local currency.** Join to `raw_markets.eur_fx`: `amount_eur = amount_local * eur_fx`. Operating costs are already in EUR.

---

## 3. The six tables

| Table | Rows |
|---|---|
| `raw_merchants` | 160 |
| `raw_subscriptions` | 117 |
| `raw_products` | 5 |
| `raw_markets` | 8 |
| `raw_acquisition_costs` | 768 |
| `raw_operating_costs` | 144 |

Validated: **zero referential-integrity errors**. Every `plan_sku` resolves to a product, every `merchant_id` to a merchant, every `country_code` to a market, and every subscription's currency matches its merchant's market. FX round-trips to the cent.

---

## 4. Expected results — use these to check your models

Computed directly from the CSVs. If your dbt marts disagree, the models are wrong, not the data.

| Metric | Value |
|---|---|
| MRR, Jan 2024 | €1,138 |
| MRR, Dec 2024 | €1,641 |
| MRR, Dec 2025 | €1,510 |
| Exit ARR | €18,117 |
| Blended gross margin | 84.9% |
| Logo churn (24m) | 8.1% (13 of 160) |
| Operating costs | €3,419/month |
| Acquisition spend (24m) | €32,439 |
| Net burn | €1,909/month |
| Cash balance (latest) | €57,235 |
| Implied runway | ~30 months |

The company is a small, early-stage SaaS that is **unprofitable and burning modestly**. That's intentional and coherent — it makes Burn Multiple and Cash Runway meaningful, which they wouldn't be at breakeven. MRR *declining* through 2025 is also real, not a bug: churn outpaces new business in the second year. That's worth explaining rather than smoothing over.

### Known data caveats

- **NRR is thin.** Only 9 rows carry a `previous_plan_sku`, and 8 of those upgrade from `free`. Expansion/contraction analysis will be directionally right but statistically light. Don't over-invest in it.
- **CAC is inflated by construction.** Acquisition spend covers all 24 months across 8 markets, but only 46 merchants signed up during 2024–25 — most joined earlier. Naive `spend / new_merchants` gives ~€705, which overstates it. Worth reasoning about rather than reporting blindly.
- **Scale is small.** €18k ARR is a tiny company. Internally consistent, but don't expect big-number dashboards.

---

## 5. The central modelling problem

Turning **117 subscription periods into a month-grain MRR series**. Each row has a `start_date` and sometimes an `end_date`; the mart needs one row per subscription per active month, converted to EUR.

Everything else — churn, NRR, LTV, CAC payback, burn multiple, runway — hangs off that one model. Get the spine right first.

Unlike the sibling BNPL project, this one does **not** name its mart table. Phase 1 asks you to choose 3–5 KPIs from the eleven and define the models yourself.

---

## 6. Environment — already done, don't redo

- **Docker**: Colima + Docker CLI 29.7.2 + Compose 5.4.0, installed via Homebrew. Verified end-to-end with `hello-world`.
  - Colima was **not** chosen by accident: Docker Desktop needs a paid licence for business use, and the project mandates an open-source-only stack. Colima is Apache-2.0.
  - The VM is **per-user** — a fresh `colima start --cpu 4 --memory 8 --disk 60` is needed in this account.
  - It does not survive reboot. `colima start` when you sit down, `colima stop` when done.
- **Git**: repo initialised on `main`, first commit `60dd770`. `.gitignore` covers `.DS_Store`, `target/`, `dbt_packages/`, `logs/`, `.env`.
- **dbt**: not installed — it'll run in a container.
- **superpowers plugin**: must be installed via `/plugin marketplace add obra/superpowers`. Without it, every skill the phase playbook references (`/brainstorming`, `/writing-plans`, `/executing-plans`, `/test-driven-development`, `/systematic-debugging`, `/verification-before-completion`) silently does nothing.

### Docs already updated

`README.md`, `Requirements.md`, and `CLAUDE.md` were all rewritten to match the new dataset — table counts, the subscription-only model, the data conventions, and the Phase 1 beats and comprehension checks. Stale `data/` paths were corrected to `saas/`. They are consistent with what's on disk; trust them.

`docs/superpowers/` was **left alone**. It's the archived design record of an earlier modernisation pass and still references a "jaffle cafe" and a dataset that no longer exists. Historical, not live — ignore it.

---

## 7. Where to start

Phase 1, per `Requirements.md`. Say **"I'm ready."**

The playbook is deliberately slow — one concept per message, comprehension checks gating each beat. If you'd rather build than be taught, say so up front; the playbook permits compressing the checks but not skipping them.
