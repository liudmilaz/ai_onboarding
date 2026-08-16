-- One row per merchant (the customers of Invented Software, not their own shops).

select
    merchant_id,
    merchant_name,
    business_type,
    country_code,
    city,
    signup_date,
    plan_type,
    status,
    churn_date,
    (status = 'churned')        as is_churned
from {{ source('raw', 'raw_merchants') }}
