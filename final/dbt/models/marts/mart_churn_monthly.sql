-- KPI: Logo Churn.
-- Business question: what share of PAYING merchants do we lose each month?
--
-- The denominator is merchants who actually carried revenue entering the month,
-- not merchants who exist. 65 of the 160 rows in dim_merchant never held a
-- subscription at all; counting them inflated the base by ~1.7x and put 4
-- never-paying merchants into the churn numerator.
--
-- Churn is detected the same way mart_revenue_movement detects it - MRR present
-- last month, absent this month - so the two series describe the same event in
-- the same month. Keying off dim_merchant.churn_month instead would put logo
-- churn one month earlier than the revenue it removes, because a subscription
-- is counted through its end month inclusive.

with grid as (

    select d.date_month, m.merchant_id
    from {{ ref('dim_date') }} d
    cross join (select distinct merchant_id from {{ ref('int_merchant_months') }}) m

), monthly as (

    select
        g.date_month,
        g.merchant_id,
        coalesce(mm.mrr_eur, 0) as mrr_eur
    from grid g
    left join {{ ref('int_merchant_months') }} mm
        on  g.date_month  = mm.month_start
        and g.merchant_id = mm.merchant_id

), movement as (

    select
        date_month,
        merchant_id,
        mrr_eur,
        lag(mrr_eur) over (partition by merchant_id order by date_month) as prev_mrr_eur
    from monthly

)

select
    date_month,
    count(*) filter (where prev_mrr_eur > 0)                        as merchants_at_start,
    count(*) filter (where prev_mrr_eur > 0 and mrr_eur = 0)        as merchants_churned,
    count(*) filter (where coalesce(prev_mrr_eur, 0) = 0 and mrr_eur > 0)
                                                                    as merchants_new,
    round(100.0 * count(*) filter (where prev_mrr_eur > 0 and mrr_eur = 0)
          / nullif(count(*) filter (where prev_mrr_eur > 0), 0), 2) as logo_churn_pct
from movement
group by 1
order by 1
