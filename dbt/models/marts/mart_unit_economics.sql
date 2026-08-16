-- Company-level unit economics: LTV, CAC, CAC Payback and LTV:CAC.
-- Grain: one row. This is a scorecard, not a time series.
--
-- Window: 2024-01 to 2025-12, the period for which cost data exists. Revenue
-- data starts in 2022 but comparing revenue against costs that do not exist
-- would flatter every ratio here.
--
-- CAC is blended over the ACQUIRING window only (months with at least one
-- signup). Spend in months that acquired nobody is excluded from the numerator
-- and reported separately - including it would inflate CAC with money that
-- bought no customers.

with window_bounds as (

    select min(date_month) as from_month, max(date_month) as to_month
    from {{ ref('fct_operating_cost') }}

), revenue as (

    select
        avg(monthly_mrr)      as avg_monthly_mrr_eur,
        avg(monthly_merchants) as avg_monthly_merchants
    from (
        select
            f.date_month,
            sum(f.mrr_eur)                as monthly_mrr,
            count(distinct f.merchant_id) as monthly_merchants
        from {{ ref('fct_subscription_month') }} f
        cross join window_bounds w
        where f.date_month between w.from_month and w.to_month
        group by 1
    ) t

), margin as (

    select sum(gross_profit_eur) / nullif(sum(mrr_eur), 0) as gross_margin
    from {{ ref('fct_subscription_month') }} f
    cross join window_bounds w
    where f.date_month between w.from_month and w.to_month

), churn as (

    -- Average monthly gross revenue churn over the window. This is the rate
    -- that drives expected customer lifetime.
    select avg(gross_revenue_churn_pct) / 100.0 as monthly_revenue_churn
    from {{ ref('mart_revenue_movement') }} r
    cross join window_bounds w
    where r.date_month between w.from_month and w.to_month
      and r.starting_mrr_eur > 0

), cac as (

    select
        sum(acquisition_spend_eur) filter (where is_acquiring_month) as acquiring_spend_eur,
        sum(acquisition_spend_eur)                                   as total_spend_eur,
        sum(new_merchants)                                           as merchants_acquired,
        sum(unattributed_spend_eur)                                  as unattributed_spend_eur
    from {{ ref('mart_cac_monthly') }} c
    cross join window_bounds w
    where c.date_month between w.from_month and w.to_month

), calc as (

    select
        w.from_month,
        w.to_month,
        r.avg_monthly_mrr_eur,
        r.avg_monthly_merchants,
        r.avg_monthly_mrr_eur / nullif(r.avg_monthly_merchants, 0) as arpa_eur,
        m.gross_margin,
        ch.monthly_revenue_churn,
        c.acquiring_spend_eur,
        c.total_spend_eur,
        c.merchants_acquired,
        c.unattributed_spend_eur,
        c.acquiring_spend_eur / nullif(c.merchants_acquired, 0)     as cac_eur,
        c.total_spend_eur     / nullif(c.merchants_acquired, 0)     as blended_cac_eur
    from window_bounds w
    cross join revenue r
    cross join margin  m
    cross join churn   ch
    cross join cac     c

)

select
    from_month,
    to_month,
    round(arpa_eur, 2)                                          as arpa_eur,
    round(100.0 * gross_margin, 2)                              as gross_margin_pct,
    round(100.0 * monthly_revenue_churn, 2)                     as monthly_revenue_churn_pct,

    -- 1/churn implies a 230-month (19-year) customer life here, because only 8
    -- of 42 months contain any churn at all. That is an artefact of a thin
    -- sample, not a real retention curve, so the horizon is capped at 60 months
    -- before it feeds LTV. Both figures are exposed: the uncapped one shows how
    -- far the naive formula overshoots.
    round(1.0 / nullif(monthly_revenue_churn, 0), 1)            as implied_lifetime_months_uncapped,
    least(round(1.0 / nullif(monthly_revenue_churn, 0), 1), 60) as expected_lifetime_months,

    -- LTV = ARPA x gross margin x lifetime. Gross margin, not revenue: what a
    -- customer is worth is the profit they generate, not the cash they send.
    round(arpa_eur * gross_margin
          * least(1.0 / nullif(monthly_revenue_churn, 0), 60), 2)
                                                                as ltv_eur,
    round(arpa_eur * gross_margin / nullif(monthly_revenue_churn, 0), 2)
                                                                as ltv_eur_uncapped,

    -- Two honest CAC answers to two different questions.
    --   cac_eur         what a customer cost in the months we actually acquired
    --   blended_cac_eur what a customer cost counting every euro spent
    -- The gap between them is the 2025 spend that acquired nobody.
    round(cac_eur, 2)                                           as cac_eur,
    round(blended_cac_eur, 2)                                   as blended_cac_eur,
    merchants_acquired,
    round(total_spend_eur, 2)                                   as total_spend_eur,
    round(unattributed_spend_eur, 2)                            as unattributed_spend_eur,
    round(100.0 * acquiring_spend_eur / nullif(total_spend_eur, 0), 1)
                                                                as spend_attributed_pct,

    -- Months of gross profit needed to repay the cost of winning the customer.
    round(cac_eur / nullif(arpa_eur * gross_margin, 0), 1)      as cac_payback_months,
    round(blended_cac_eur / nullif(arpa_eur * gross_margin, 0), 1)
                                                                as blended_cac_payback_months,

    -- Rule of thumb: above 3 is healthy, below 1 means growth destroys value.
    round(arpa_eur * gross_margin * least(1.0 / nullif(monthly_revenue_churn, 0), 60)
          / nullif(cac_eur, 0), 2)                              as ltv_to_cac_ratio,
    round(arpa_eur * gross_margin * least(1.0 / nullif(monthly_revenue_churn, 0), 60)
          / nullif(blended_cac_eur, 0), 2)                      as ltv_to_blended_cac_ratio
from calc
