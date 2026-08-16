-- Month spine for the whole platform.
--
-- The horizon is the UNION of the subscription window and the cost window, not
-- the cost window alone. Driving the end bound off operating costs was wrong in
-- both directions:
--   * 102 of 117 subscriptions have a NULL end_date and are extended to the
--     bound, so adding one month of cost rows with no new subscription data
--     fabricated a full extra month of MRR - as if every open subscription had
--     silently renewed.
--   * dropping cost rows truncated revenue history that had nothing to do with
--     costs.
-- Revenue and cost series still share an axis; neither now defines the other's
-- extent.

with bounds as (

    select
        least(
            (select min(date_trunc('month', start_date)) from {{ ref('stg_subscriptions') }}),
            (select min(month_start) from {{ ref('stg_operating_costs') }})
        ) as first_month,
        greatest(
            (select max(date_trunc('month', coalesce(end_date, start_date)))
               from {{ ref('stg_subscriptions') }}),
            (select max(month_start) from {{ ref('stg_operating_costs') }})
        ) as last_month
    from (select 1) _

)

select generate_series(
           cast(first_month as date),
           cast(last_month  as date),
           interval '1 month'
       )::date as month_start
from bounds
