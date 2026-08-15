-- KPI 1: MRR / ARR.
-- Business question: what is recurring revenue each month, and is it growing?

with monthly as (

    select
        month_start,
        sum(mrr_eur)                as mrr_eur,
        count(*)                    as active_subscriptions,
        count(distinct merchant_id) as active_merchants
    from {{ ref('int_subscription_months') }}
    group by 1

)

select
    month_start,
    round(mrr_eur, 2)                                       as mrr_eur,
    round(mrr_eur * 12, 2)                                  as arr_eur,
    active_subscriptions,
    active_merchants,
    round(mrr_eur - lag(mrr_eur) over (order by month_start), 2)
                                                            as mrr_change_eur,
    round(
        100.0 * (mrr_eur - lag(mrr_eur) over (order by month_start))
        / nullif(lag(mrr_eur) over (order by month_start), 0)
    , 2)                                                    as mrr_growth_pct,
    round(mrr_eur / nullif(active_merchants, 0), 2)         as arpa_eur
from monthly
order by month_start
