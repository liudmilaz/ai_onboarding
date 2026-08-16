-- Regression anchor. These figures were computed directly from the CSVs and are
-- published in HANDOFF.md section 4. If this test fails, the models drifted -
-- the data did not. Tolerance is 1 EUR / 0.1pp to absorb rounding.
--
-- LEFT JOIN, not INNER. With an inner join a month that vanished from the mart
-- produced no row to compare and the test passed - so the anchor would have
-- stayed green through exactly the horizon-truncation bug it exists to catch.
-- A missing month is now a violation in its own right.

with expected as (
    select * from (values
        (date '2024-01-01', 1138.0),
        (date '2024-12-01', 1641.0),
        (date '2025-12-01', 1510.0)
    ) as t(date_month, expected_mrr_eur)
),

mrr_check as (
    select
        e.date_month,
        case when a.date_month is null then 'mrr_month_MISSING' else 'mrr' end as metric,
        a.mrr_eur           as actual,
        e.expected_mrr_eur  as expected
    from expected e
    left join {{ ref('mart_mrr_monthly') }} a using (date_month)
    where a.date_month is null
       or abs(a.mrr_eur - e.expected_mrr_eur) > 1.0
),

-- Blended gross margin across the whole horizon should be 84.9%
margin_check as (
    select
        null::date  as date_month,
        'blended_gross_margin' as metric,
        round(100.0 * sum(gross_profit_eur) / nullif(sum(revenue_eur), 0), 1) as actual,
        84.9        as expected
    from {{ ref('mart_gross_margin_monthly') }}
    having abs(
        round(100.0 * sum(gross_profit_eur) / nullif(sum(revenue_eur), 0), 1) - 84.9
    ) > 0.1
),

-- The spine must cover every subscription month. Guards the horizon directly.
coverage_check as (
    select
        null::date as date_month,
        'spine_shorter_than_subscriptions' as metric,
        (select count(*) from {{ ref('stg_subscriptions') }} s
          where date_trunc('month', s.start_date)
                > (select max(month_start) from {{ ref('int_months') }}))::numeric as actual,
        0::numeric as expected
    where (select count(*) from {{ ref('stg_subscriptions') }} s
            where date_trunc('month', s.start_date)
                  > (select max(month_start) from {{ ref('int_months') }})) > 0
)

select * from mrr_check
union all
select * from margin_check
union all
select * from coverage_check
