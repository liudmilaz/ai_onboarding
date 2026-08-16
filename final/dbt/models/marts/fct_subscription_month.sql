-- PERIODIC SNAPSHOT FACT
-- Grain: one row per subscription per month it was active.
-- Foreign keys: date_month -> dim_date, merchant_id -> dim_merchant,
--               plan_sku -> dim_product, country_code -> dim_market.
--
-- ADDITIVITY - the thing to get right about this table:
--   mrr_eur, cogs_eur, gross_profit_eur are SEMI-ADDITIVE. They sum correctly
--   across merchants, products and markets, but NOT across time. Summing
--   mrr_eur over twelve months does not give annual revenue - it gives a
--   meaningless number. Aggregate across time with avg(), or filter to a
--   single month.

select
    s.month_start           as date_month,
    s.subscription_id,
    s.merchant_id,
    s.plan_sku,
    m.country_code,
    s.currency,
    s.mrr_eur,
    s.cogs_eur,
    s.gross_profit_eur
from {{ ref('int_subscription_months') }} s
join {{ ref('stg_merchants') }} m
    on s.merchant_id = m.merchant_id
