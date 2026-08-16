# Database Schema

**Phase 3 deliverable.** Generated from the live database via `information_schema`.

Four schemas, 31 tables. dbt model-level documentation (lineage graph, column
descriptions, tests) is generated separately with `dbt docs generate` — see the
README.

| Schema | Tables | Purpose |
|---|---|---|
| `raw` | 6 | Raw landing zone |
| `analytics_staging` | 7 | Staging |
| `analytics_intermediate` | 3 | Intermediate |
| `analytics_marts` | 15 | Marts — dimensional star + KPIs |


## Raw landing zone — `raw`

One table per CSV in `saas/`, loaded by `db/init/03_load.sql` on first container boot. Types are faithful to the source: money is in **minor units**, `mrr_local` and `spend_amount` are in **local currency**. No cleaning happens here.

### `raw_acquisition_costs`

| Column | Type | Null |
|---|---|---|
| `cost_id` | text | no |
| `year_month` | date | no |
| `country_code` | text | no |
| `channel` | text | no |
| `spend_amount` | int | no |
| `currency` | text | no |

### `raw_markets`

| Column | Type | Null |
|---|---|---|
| `country_code` | text | no |
| `country_name` | text | no |
| `region` | text | no |
| `currency` | text | no |
| `eur_fx` | numeric | no |
| `launch_year` | int | no |
| `vat_rate` | numeric | no |

### `raw_merchants`

| Column | Type | Null |
|---|---|---|
| `merchant_id` | text | no |
| `merchant_name` | text | no |
| `business_type` | text | no |
| `country_code` | text | no |
| `city` | text | yes |
| `signup_date` | date | no |
| `plan_type` | text | yes |
| `status` | text | no |
| `churn_date` | date | yes |

### `raw_operating_costs`

| Column | Type | Null |
|---|---|---|
| `cost_id` | text | no |
| `year_month` | date | no |
| `cost_category` | text | no |
| `amount_eur` | int | no |
| `description` | text | yes |

### `raw_products`

| Column | Type | Null |
|---|---|---|
| `sku` | text | no |
| `name` | text | no |
| `type` | text | no |
| `price_eur` | int | no |
| `cogs_eur` | int | no |
| `gross_margin_pct` | numeric | no |
| `description` | text | yes |
| `launched_at` | date | no |

### `raw_subscriptions`

| Column | Type | Null |
|---|---|---|
| `subscription_id` | text | no |
| `merchant_id` | text | no |
| `plan_sku` | text | no |
| `start_date` | date | no |
| `end_date` | date | yes |
| `mrr_local` | int | no |
| `currency` | text | no |
| `cancellation_reason` | text | yes |
| `previous_plan_sku` | text | yes |


## Staging — `analytics_staging`

Type casting and the two unit conversions. Minor units are divided by 100 and local currency is multiplied by `eur_fx` here **and nowhere else** — anything downstream that converts again is a bug. `raw_operating_costs` is split into `stg_operating_costs` (flows) and `stg_cash_balances` (the stock).

### `stg_acquisition_costs`

| Column | Type | Null |
|---|---|---|
| `cost_id` | text | yes |
| `month_start` | date | yes |
| `country_code` | text | yes |
| `channel` | text | yes |
| `currency` | text | yes |
| `spend_local` | numeric | yes |
| `spend_eur` | numeric | yes |

### `stg_cash_balances`

| Column | Type | Null |
|---|---|---|
| `cost_id` | text | yes |
| `month_start` | date | yes |
| `cash_balance_eur` | numeric | yes |

### `stg_markets`

| Column | Type | Null |
|---|---|---|
| `country_code` | text | yes |
| `country_name` | text | yes |
| `region` | text | yes |
| `currency` | text | yes |
| `eur_fx` | numeric | yes |
| `launch_year` | int | yes |
| `vat_rate` | numeric | yes |

### `stg_merchants`

| Column | Type | Null |
|---|---|---|
| `merchant_id` | text | yes |
| `merchant_name` | text | yes |
| `business_type` | text | yes |
| `country_code` | text | yes |
| `city` | text | yes |
| `signup_date` | date | yes |
| `plan_type` | text | yes |
| `status` | text | yes |
| `churn_date` | date | yes |
| `is_churned` | bool | yes |

### `stg_operating_costs`

| Column | Type | Null |
|---|---|---|
| `cost_id` | text | yes |
| `month_start` | date | yes |
| `cost_category` | text | yes |
| `amount_eur` | numeric | yes |
| `description` | text | yes |

### `stg_products`

| Column | Type | Null |
|---|---|---|
| `sku` | text | yes |
| `product_name` | text | yes |
| `product_type` | text | yes |
| `price_eur` | numeric | yes |
| `cogs_eur` | numeric | yes |
| `gross_margin_pct` | numeric | yes |
| `launched_at` | date | yes |

### `stg_subscriptions`

| Column | Type | Null |
|---|---|---|
| `subscription_id` | text | yes |
| `merchant_id` | text | yes |
| `plan_sku` | text | yes |
| `start_date` | date | yes |
| `end_date` | date | yes |
| `currency` | text | yes |
| `mrr_local` | numeric | yes |
| `mrr_eur` | numeric | yes |
| `cancellation_reason` | text | yes |
| `previous_plan_sku` | text | yes |
| `is_active` | bool | yes |


## Intermediate — `analytics_intermediate`

The month spine and the subscription explosion. `int_subscription_months` turns 117 subscription periods into one row per subscription per active month — the model every revenue metric depends on.

### `int_merchant_months`

| Column | Type | Null |
|---|---|---|
| `month_start` | date | yes |
| `merchant_id` | text | yes |
| `mrr_eur` | numeric | yes |
| `gross_profit_eur` | numeric | yes |
| `active_subscriptions` | bigint | yes |

### `int_months`

| Column | Type | Null |
|---|---|---|
| `month_start` | date | yes |

### `int_subscription_months`

| Column | Type | Null |
|---|---|---|
| `month_start` | date | yes |
| `subscription_id` | text | yes |
| `merchant_id` | text | yes |
| `plan_sku` | text | yes |
| `currency` | text | yes |
| `mrr_eur` | numeric | yes |
| `cogs_eur` | numeric | yes |
| `gross_profit_eur` | numeric | yes |


## Marts — dimensional star + KPIs — `analytics_marts`

Conformed dimensions (`dim_*`), facts (`fct_*`) with declared grain and additivity, and metric marts (`mart_*`) for the KPIs that need multi-step logic.

### `dim_date`

| Column | Type | Null |
|---|---|---|
| `date_month` | date | yes |
| `year` | int | yes |
| `quarter` | int | yes |
| `month_of_year` | int | yes |
| `year_month` | text | yes |
| `month_label` | text | yes |
| `year_quarter` | text | yes |

### `dim_market`

| Column | Type | Null |
|---|---|---|
| `country_code` | text | yes |
| `country_name` | text | yes |
| `region` | text | yes |
| `currency` | text | yes |
| `eur_fx` | numeric | yes |
| `launch_year` | int | yes |
| `vat_rate` | numeric | yes |
| `is_eurozone` | bool | yes |

### `dim_merchant`

| Column | Type | Null |
|---|---|---|
| `merchant_id` | text | yes |
| `merchant_name` | text | yes |
| `business_type` | text | yes |
| `country_code` | text | yes |
| `city` | text | yes |
| `signup_date` | date | yes |
| `signup_month` | date | yes |
| `churn_date` | date | yes |
| `churn_month` | date | yes |
| `plan_type` | text | yes |
| `status` | text | yes |
| `is_churned` | bool | yes |

### `dim_product`

| Column | Type | Null |
|---|---|---|
| `sku` | text | yes |
| `product_name` | text | yes |
| `product_type` | text | yes |
| `price_eur` | numeric | yes |
| `cogs_eur` | numeric | yes |
| `gross_margin_pct` | numeric | yes |
| `launched_at` | date | yes |
| `is_free_plan` | bool | yes |

### `fct_acquisition_spend`

| Column | Type | Null |
|---|---|---|
| `date_month` | date | yes |
| `acquisition_cost_id` | text | yes |
| `country_code` | text | yes |
| `channel` | text | yes |
| `spend_eur` | numeric | yes |

### `fct_cash_balance`

| Column | Type | Null |
|---|---|---|
| `date_month` | date | yes |
| `cash_balance_eur` | numeric | yes |
| `cash_change_eur` | numeric | yes |

### `fct_operating_cost`

| Column | Type | Null |
|---|---|---|
| `date_month` | date | yes |
| `operating_cost_id` | text | yes |
| `cost_category` | text | yes |
| `amount_eur` | numeric | yes |
| `is_cost_of_revenue` | bool | yes |

### `fct_subscription_month`

| Column | Type | Null |
|---|---|---|
| `date_month` | date | yes |
| `subscription_id` | text | yes |
| `merchant_id` | text | yes |
| `plan_sku` | text | yes |
| `country_code` | text | yes |
| `currency` | text | yes |
| `mrr_eur` | numeric | yes |
| `cogs_eur` | numeric | yes |
| `gross_profit_eur` | numeric | yes |

### `mart_burn_monthly`

| Column | Type | Null |
|---|---|---|
| `date_month` | date | yes |
| `revenue_eur` | numeric | yes |
| `operating_cost_eur` | numeric | yes |
| `acquisition_spend_eur` | numeric | yes |
| `net_cash_flow_eur` | numeric | yes |
| `net_burn_eur` | numeric | yes |
| `net_new_arr_eur` | numeric | yes |
| `burn_multiple` | numeric | yes |
| `runway_months` | numeric | yes |
| `recorded_cash_balance_eur` | numeric | yes |
| `recorded_cash_change_eur` | numeric | yes |
| `ledger_vs_pnl_gap_eur` | numeric | yes |

### `mart_cac_monthly`

| Column | Type | Null |
|---|---|---|
| `date_month` | date | yes |
| `acquisition_spend_eur` | numeric | yes |
| `new_merchants` | bigint | yes |
| `cac_eur` | numeric | yes |
| `unattributed_spend_eur` | numeric | yes |
| `is_acquiring_month` | bool | yes |
| `has_spend_data` | bool | yes |

### `mart_churn_monthly`

| Column | Type | Null |
|---|---|---|
| `date_month` | date | yes |
| `merchants_at_start` | bigint | yes |
| `merchants_churned` | bigint | yes |
| `logo_churn_pct` | numeric | yes |

### `mart_gross_margin_monthly`

| Column | Type | Null |
|---|---|---|
| `date_month` | date | yes |
| `revenue_eur` | numeric | yes |
| `cogs_eur` | numeric | yes |
| `gross_profit_eur` | numeric | yes |
| `gross_margin_pct` | numeric | yes |

### `mart_mrr_monthly`

| Column | Type | Null |
|---|---|---|
| `date_month` | date | yes |
| `mrr_eur` | numeric | yes |
| `arr_eur` | numeric | yes |
| `active_subscriptions` | bigint | yes |
| `active_merchants` | bigint | yes |
| `mrr_change_eur` | numeric | yes |
| `mrr_growth_pct` | numeric | yes |
| `arpa_eur` | numeric | yes |

### `mart_revenue_movement`

| Column | Type | Null |
|---|---|---|
| `date_month` | date | yes |
| `starting_mrr_eur` | numeric | yes |
| `new_mrr_eur` | numeric | yes |
| `expansion_mrr_eur` | numeric | yes |
| `contraction_mrr_eur` | numeric | yes |
| `churned_mrr_eur` | numeric | yes |
| `ending_mrr_eur` | numeric | yes |
| `gross_revenue_churn_pct` | numeric | yes |
| `net_revenue_retention_pct` | numeric | yes |

### `mart_unit_economics`

| Column | Type | Null |
|---|---|---|
| `from_month` | date | yes |
| `to_month` | date | yes |
| `arpa_eur` | numeric | yes |
| `gross_margin_pct` | numeric | yes |
| `monthly_revenue_churn_pct` | numeric | yes |
| `implied_lifetime_months_uncapped` | numeric | yes |
| `expected_lifetime_months` | numeric | yes |
| `ltv_eur` | numeric | yes |
| `ltv_eur_uncapped` | numeric | yes |
| `cac_eur` | numeric | yes |
| `blended_cac_eur` | numeric | yes |
| `merchants_acquired` | numeric | yes |
| `total_spend_eur` | numeric | yes |
| `unattributed_spend_eur` | numeric | yes |
| `spend_attributed_pct` | numeric | yes |
| `cac_payback_months` | numeric | yes |
| `blended_cac_payback_months` | numeric | yes |
| `ltv_to_cac_ratio` | numeric | yes |
| `ltv_to_blended_cac_ratio` | numeric | yes |

