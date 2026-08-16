-- TRANSACTION FACT
-- Grain: one row per month per cost category.
-- Foreign key: date_month -> dim_date.
-- cost_category is a degenerate dimension.
--
-- ADDITIVITY: amount_eur is FULLY ADDITIVE.
--
-- The cash balance is deliberately NOT in this table. In the source CSV it sits
-- in the same amount_eur column as these cost rows, which makes an unfiltered
-- SUM return roughly 16x the true monthly cost. A non-additive stock and a
-- fully-additive flow cannot share a grain - it lives in fct_cash_balance.

select
    month_start     as date_month,
    cost_id         as operating_cost_id,
    cost_category,
    amount_eur,
    (cost_category = 'cost_of_revenue') as is_cost_of_revenue
from {{ ref('stg_operating_costs') }}
