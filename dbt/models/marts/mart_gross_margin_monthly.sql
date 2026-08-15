-- KPI 2: Gross Profit Margin.
-- Business question: how much of each euro of recurring revenue do we keep
-- after the cost of serving it?
--
-- COGS here is product-level cost of revenue per active subscription month.
-- It is deliberately NOT raw_operating_costs.cost_of_revenue - mixing the two
-- would charge cost of revenue twice.

with monthly as (

    select
        month_start,
        sum(mrr_eur)            as revenue_eur,
        sum(cogs_eur)           as cogs_eur,
        sum(gross_profit_eur)   as gross_profit_eur
    from {{ ref('int_subscription_months') }}
    group by 1

)

select
    month_start,
    round(revenue_eur, 2)       as revenue_eur,
    round(cogs_eur, 2)          as cogs_eur,
    round(gross_profit_eur, 2)  as gross_profit_eur,
    round(100.0 * gross_profit_eur / nullif(revenue_eur, 0), 2)
                                as gross_margin_pct
from monthly
order by month_start
