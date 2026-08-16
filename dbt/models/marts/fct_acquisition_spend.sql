-- TRANSACTION FACT
-- Grain: one row per month per market per channel.
-- Foreign keys: date_month -> dim_date, country_code -> dim_market.
-- channel is a degenerate dimension: low-cardinality text with no attributes
-- of its own, so it lives on the fact rather than in a lookup table.
--
-- ADDITIVITY: spend_eur is FULLY ADDITIVE - sum it across any combination of
-- month, market and channel.

select
    month_start     as date_month,
    cost_id         as acquisition_cost_id,
    country_code,
    channel,
    spend_eur
from {{ ref('stg_acquisition_costs') }}
