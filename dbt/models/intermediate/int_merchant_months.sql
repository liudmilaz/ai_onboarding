-- Merchant-grain revenue, one row per merchant per month they were paying.
-- Rolls the subscription spine up a level so revenue movement (new, expansion,
-- contraction, churn) can be classified per customer rather than per contract:
-- a merchant swapping one plan for a pricier one is expansion, not a churn plus
-- a new sale, and only merchant grain can see that.

select
    month_start,
    merchant_id,
    sum(mrr_eur)            as mrr_eur,
    sum(gross_profit_eur)   as gross_profit_eur,
    count(*)                as active_subscriptions
from {{ ref('int_subscription_months') }}
group by 1, 2
