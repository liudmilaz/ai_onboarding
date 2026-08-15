-- KPI 3: Logo Churn.
-- Business question: what share of paying merchants do we lose each month?
--
-- Logo churn, not revenue churn: the denominator is merchants active at the
-- start of the month, the numerator is merchants whose churn_date falls in it.

with merchant_months as (

    select
        m.month_start,
        mc.merchant_id,
        -- active entering the month: signed up in an earlier month and not yet churned
        (date_trunc('month', mc.signup_date)::date < m.month_start
         and (mc.churn_date is null
              or date_trunc('month', mc.churn_date)::date >= m.month_start))
                                                        as active_at_month_start,
        (mc.churn_date is not null
         and date_trunc('month', mc.churn_date)::date = m.month_start)
                                                        as churned_this_month
    from {{ ref('int_months') }} m
    cross join {{ ref('stg_merchants') }} mc

), monthly as (

    select
        month_start,
        count(*) filter (where active_at_month_start) as merchants_at_start,
        count(*) filter (where churned_this_month)    as merchants_churned
    from merchant_months
    group by 1

)

select
    month_start,
    merchants_at_start,
    merchants_churned,
    round(100.0 * merchants_churned / nullif(merchants_at_start, 0), 2)
        as logo_churn_pct
from monthly
order by month_start
