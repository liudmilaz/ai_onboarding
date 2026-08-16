-- KPI: MRR / ARR.
-- Business question: what is recurring revenue each month, and is it growing?
--
-- A convenience rollup over fct_subscription_month. For any cut other than
-- plain month - by market, business type or plan - query the fact joined to its
-- dimensions rather than adding columns here.

with monthly as (

    select
        date_month,
        sum(mrr_eur)                as mrr_eur,
        count(*)                    as active_subscriptions,
        count(distinct merchant_id) as active_merchants
    from {{ ref('fct_subscription_month') }}
    group by 1

)

select
    date_month,
    round(mrr_eur, 2)                                       as mrr_eur,
    round(mrr_eur * 12, 2)                                  as arr_eur,
    active_subscriptions,
    active_merchants,
    round(mrr_eur - lag(mrr_eur) over (order by date_month), 2)
                                                            as mrr_change_eur,
    round(
        100.0 * (mrr_eur - lag(mrr_eur) over (order by date_month))
        / nullif(lag(mrr_eur) over (order by date_month), 0)
    , 2)                                                    as mrr_growth_pct,
    round(mrr_eur / nullif(active_merchants, 0), 2)         as arpa_eur
from monthly
order by date_month
