-- Burn, Burn Multiple and Cash Runway at month grain.
--
-- BURN IS DERIVED FROM THE P&L, NOT FROM THE CASH LEDGER. The recorded
-- cash_balance_eom series contradicts the cost and revenue tables and is a
-- function of time rather than of the business (see fct_cash_balance for the
-- regression evidence). Burn here is:
--
--     revenue - operating costs - acquisition spend
--
-- Acquisition spend is included because it is real cash leaving the bank. It is
-- NOT a subset of the sales_and_marketing operating-cost line: at ~1,352/month
-- it is larger than that line's ~932/month, so the two are independent.
--
-- The recorded balance is carried alongside for comparison only, with the
-- divergence made explicit.

with revenue as (

    select date_month, sum(mrr_eur) as revenue_eur
    from {{ ref('fct_subscription_month') }}
    group by 1

), opex as (

    select date_month, sum(amount_eur) as operating_cost_eur
    from {{ ref('fct_operating_cost') }}
    group by 1

), acq as (

    select date_month, sum(spend_eur) as acquisition_spend_eur
    from {{ ref('fct_acquisition_spend') }}
    group by 1

), combined as (

    select
        d.date_month,
        coalesce(r.revenue_eur, 0)           as revenue_eur,
        coalesce(o.operating_cost_eur, 0)    as operating_cost_eur,
        coalesce(a.acquisition_spend_eur, 0) as acquisition_spend_eur,
        c.cash_balance_eur,
        c.cash_change_eur
    from {{ ref('dim_date') }} d
    left join revenue            r on d.date_month = r.date_month
    left join opex               o on d.date_month = o.date_month
    left join acq                a on d.date_month = a.date_month
    left join {{ ref('fct_cash_balance') }} c on d.date_month = c.date_month
    -- Costs only exist from 2024-01; earlier months would show a fake profit.
    where o.operating_cost_eur is not null

), calc as (

    select
        date_month,
        revenue_eur,
        operating_cost_eur,
        acquisition_spend_eur,
        revenue_eur - operating_cost_eur - acquisition_spend_eur as net_cash_flow_eur,
        cash_balance_eur,
        cash_change_eur,
        -- Net new ARR is the denominator of Burn Multiple.
        (revenue_eur - lag(revenue_eur) over (order by date_month)) * 12 as net_new_arr_eur
    from combined

)

select
    date_month,
    round(revenue_eur, 2)                                   as revenue_eur,
    round(operating_cost_eur, 2)                            as operating_cost_eur,
    round(acquisition_spend_eur, 2)                         as acquisition_spend_eur,
    round(net_cash_flow_eur, 2)                             as net_cash_flow_eur,
    round(greatest(-net_cash_flow_eur, 0), 2)               as net_burn_eur,
    round(net_new_arr_eur, 2)                               as net_new_arr_eur,

    -- Burn Multiple = net burn / net new ARR. Lower is better; under 1 is
    -- excellent, over 3 is alarming. NULL when ARR shrank, because efficiency
    -- of growth is undefined when there is no growth.
    case when net_new_arr_eur > 0
         then round(greatest(-net_cash_flow_eur, 0) / net_new_arr_eur, 2)
    end                                                     as burn_multiple,

    -- Runway on the recorded balance at the current month's burn. The balance
    -- is the disputed series, so this is indicative only.
    case when net_cash_flow_eur < 0 and cash_balance_eur is not null
         then round(cash_balance_eur / (-net_cash_flow_eur), 1)
    end                                                     as runway_months,

    round(cash_balance_eur, 2)                              as recorded_cash_balance_eur,
    round(cash_change_eur, 2)                               as recorded_cash_change_eur,
    -- What the ledger says happened, minus what the P&L says should have.
    round(cash_change_eur - net_cash_flow_eur, 2)           as ledger_vs_pnl_gap_eur
from calc
order by date_month
