-- The sole revenue source. Two conversions happen here and nowhere else:
--   minor units -> EUR  (/100)
--   local currency -> EUR  (* eur_fx, joined via the merchant's market)
-- end_date NULL means the subscription is still active.

select
    s.subscription_id,
    s.merchant_id,
    s.plan_sku,
    s.start_date,
    s.end_date,
    s.currency,
    s.mrr_local / 100.0                     as mrr_local,
    (s.mrr_local / 100.0) * mk.eur_fx       as mrr_eur,
    s.cancellation_reason,
    s.previous_plan_sku,
    (s.end_date is null)                    as is_active
from {{ source('raw', 'raw_subscriptions') }} s
join {{ ref('stg_merchants') }} m
    on s.merchant_id = m.merchant_id
join {{ ref('stg_markets') }} mk
    on m.country_code = mk.country_code
