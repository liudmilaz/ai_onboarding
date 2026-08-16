-- KPI: Gross Profit Margin.
-- Business question: how much of each euro of recurring revenue survives the
-- cost of serving it?
--
-- COGS here is product-level cost of revenue per active subscription month,
-- taken from the fact. It is deliberately NOT fct_operating_cost's
-- cost_of_revenue line - charging both would count cost of revenue twice.

with monthly as (

    select
        date_month,
        sum(mrr_eur)            as revenue_eur,
        sum(cogs_eur)           as cogs_eur,
        sum(gross_profit_eur)   as gross_profit_eur
    from {{ ref('fct_subscription_month') }}
    group by 1

)

select
    date_month,
    round(revenue_eur, 2)       as revenue_eur,
    round(cogs_eur, 2)          as cogs_eur,
    round(gross_profit_eur, 2)  as gross_profit_eur,
    round(100.0 * gross_profit_eur / nullif(revenue_eur, 0), 2)
                                as gross_margin_pct
from monthly
order by date_month
