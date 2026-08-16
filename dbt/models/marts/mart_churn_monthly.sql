-- KPI: Logo Churn.
-- Business question: what share of paying merchants do we lose each month?
--
-- Logo churn counts customers, not euros. Pair it with
-- mart_revenue_movement.gross_revenue_churn_pct: losing one 199 EUR merchant
-- and one 9 EUR merchant is identical logo churn and very different revenue
-- churn, and the gap between the two is the interesting signal.

with merchant_months as (

    select
        d.date_month,
        m.merchant_id,
        (m.signup_month < d.date_month
         and (m.churn_month is null or m.churn_month >= d.date_month))
                                            as active_at_month_start,
        (m.churn_month = d.date_month)      as churned_this_month
    from {{ ref('dim_date') }} d
    cross join {{ ref('dim_merchant') }} m

), monthly as (

    select
        date_month,
        count(*) filter (where active_at_month_start) as merchants_at_start,
        count(*) filter (where churned_this_month)    as merchants_churned
    from merchant_months
    group by 1

)

select
    date_month,
    merchants_at_start,
    merchants_churned,
    round(100.0 * merchants_churned / nullif(merchants_at_start, 0), 2)
        as logo_churn_pct
from monthly
order by date_month
