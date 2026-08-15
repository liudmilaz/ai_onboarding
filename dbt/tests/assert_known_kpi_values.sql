-- Regression anchor. These figures were computed directly from the CSVs and are
-- published in HANDOFF.md section 4. If this test fails, the models drifted -
-- the data did not. Tolerance is 1 EUR / 0.1pp to absorb rounding.

with expected as (
    select * from (values
        (date '2024-01-01', 1138.0),
        (date '2024-12-01', 1641.0),
        (date '2025-12-01', 1510.0)
    ) as t(month_start, expected_mrr_eur)
),

mrr_check as (
    select
        e.month_start,
        'mrr'               as metric,
        a.mrr_eur           as actual,
        e.expected_mrr_eur  as expected
    from expected e
    join {{ ref('mart_mrr_monthly') }} a using (month_start)
    where abs(a.mrr_eur - e.expected_mrr_eur) > 1.0
),

-- Blended gross margin across the whole horizon should be 84.9%
margin_check as (
    select
        null::date  as month_start,
        'blended_gross_margin' as metric,
        round(100.0 * sum(gross_profit_eur) / nullif(sum(revenue_eur), 0), 1) as actual,
        84.9        as expected
    from {{ ref('mart_gross_margin_monthly') }}
    having abs(
        round(100.0 * sum(gross_profit_eur) / nullif(sum(revenue_eur), 0), 1) - 84.9
    ) > 0.1
)

select * from mrr_check
union all
select * from margin_check
