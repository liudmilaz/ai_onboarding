-- Merchant dimension. Type 1 (overwrite): the source carries only the current
-- status and a single churn_date, so there is no history to preserve. If the
-- source ever emitted status changes over time this would become Type 2.

select
    merchant_id,
    merchant_name,
    business_type,
    country_code,
    city,
    signup_date,
    date_trunc('month', signup_date)::date  as signup_month,
    churn_date,
    date_trunc('month', churn_date)::date   as churn_month,
    plan_type,
    status,
    is_churned
from {{ ref('stg_merchants') }}
