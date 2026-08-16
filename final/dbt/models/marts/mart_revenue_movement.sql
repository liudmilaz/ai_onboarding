-- MRR waterfall at month grain. Yields NRR and revenue churn, which logo churn
-- cannot: losing one 199 EUR merchant and one 9 EUR merchant is the same logo
-- churn and wildly different revenue churn.
--
-- Movement is classified at MERCHANT grain, not subscription grain, so a
-- merchant swapping a cheap plan for an expensive one reads as expansion rather
-- than a simultaneous churn and new sale.
--
-- Buckets, per merchant, comparing this month to last:
--   new          had no MRR last month, has MRR now
--   churned      had MRR last month, none now
--   expansion    had MRR both months, higher now
--   contraction  had MRR both months, lower now

with grid as (

    -- Every merchant that ever paid, against every month, so gaps are explicit
    -- zeros rather than missing rows. Without this a churn is invisible: the
    -- merchant simply stops appearing.
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
        coalesce(lag(mrr_eur) over (partition by merchant_id order by date_month), 0)
            as prev_mrr_eur
    from monthly

), classified as (

    select
        date_month,
        sum(prev_mrr_eur)                                                    as starting_mrr_eur,
        sum(mrr_eur)                                                         as ending_mrr_eur,
        sum(case when prev_mrr_eur = 0 and mrr_eur > 0 then mrr_eur else 0 end)
                                                                             as new_mrr_eur,
        sum(case when prev_mrr_eur > 0 and mrr_eur = 0 then prev_mrr_eur else 0 end)
                                                                             as churned_mrr_eur,
        sum(case when prev_mrr_eur > 0 and mrr_eur > prev_mrr_eur
                 then mrr_eur - prev_mrr_eur else 0 end)                     as expansion_mrr_eur,
        sum(case when prev_mrr_eur > 0 and mrr_eur > 0 and mrr_eur < prev_mrr_eur
                 then prev_mrr_eur - mrr_eur else 0 end)                     as contraction_mrr_eur
    from movement
    group by 1

)

select
    date_month,
    round(starting_mrr_eur, 2)      as starting_mrr_eur,
    round(new_mrr_eur, 2)           as new_mrr_eur,
    round(expansion_mrr_eur, 2)     as expansion_mrr_eur,
    round(contraction_mrr_eur, 2)   as contraction_mrr_eur,
    round(churned_mrr_eur, 2)       as churned_mrr_eur,
    round(ending_mrr_eur, 2)        as ending_mrr_eur,

    -- Gross revenue churn: revenue lost to cancellations, as a share of opening
    round(100.0 * churned_mrr_eur / nullif(starting_mrr_eur, 0), 2)
        as gross_revenue_churn_pct,

    -- NRR: opening cohort's revenue this month, expansion included, new excluded.
    -- Above 100% means existing customers grew enough to outweigh losses.
    round(100.0 * (starting_mrr_eur + expansion_mrr_eur - contraction_mrr_eur - churned_mrr_eur)
          / nullif(starting_mrr_eur, 0), 2)
        as net_revenue_retention_pct
from classified
order by date_month
