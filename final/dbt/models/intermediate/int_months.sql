-- Month spine for the whole platform. Runs from the first subscription month to
-- the end of the cost reporting window, so revenue and cost series share an axis.

with horizon as (
    select
        (select date_trunc('month', min(start_date))
           from {{ ref('stg_subscriptions') }})  as first_month,
        (select max(month_start)
           from {{ ref('stg_operating_costs') }}) as last_month
)

select generate_series(
           cast(first_month as date),
           cast(last_month  as date),
           interval '1 month'
       )::date as month_start
from horizon
