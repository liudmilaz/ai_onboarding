-- THE SPINE. Explodes 117 subscription periods into one row per subscription per
-- active month. Everything revenue-shaped downstream is built on this.
--
-- Boundary rule: a subscription is counted in its start month and in its end
-- month (both inclusive). A NULL end_date means still active, so it runs to the
-- end of the horizon.

select
    m.month_start,
    s.subscription_id,
    s.merchant_id,
    s.plan_sku,
    s.currency,
    s.mrr_eur,
    p.cogs_eur,
    s.mrr_eur - p.cogs_eur   as gross_profit_eur
from {{ ref('int_months') }} m
join {{ ref('stg_subscriptions') }} s
    on  m.month_start >= date_trunc('month', s.start_date)::date
    and (s.end_date is null or m.month_start <= date_trunc('month', s.end_date)::date)
join {{ ref('stg_products') }} p
    on s.plan_sku = p.sku
