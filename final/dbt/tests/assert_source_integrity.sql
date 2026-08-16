-- Source-level data quality gate.
--
-- Ported from the Postgres-only db/validate.sql so the checks survive as part
-- of `dbt build` rather than as a separate step that only ran in one path.
-- Generic relationships/unique/not_null tests cover the foreign keys; these are
-- the checks those cannot express.
--
-- Returns one row per violation, so an empty result means healthy.

with row_counts as (

    select 'raw_merchants'           as table_name, count(*) as actual, 160 as expected from {{ source('raw', 'raw_merchants') }}
    union all
    select 'raw_subscriptions',      count(*), 117 from {{ source('raw', 'raw_subscriptions') }}
    union all
    select 'raw_products',           count(*),   5 from {{ source('raw', 'raw_products') }}
    union all
    select 'raw_markets',            count(*),   8 from {{ source('raw', 'raw_markets') }}
    union all
    select 'raw_acquisition_costs',  count(*), 768 from {{ source('raw', 'raw_acquisition_costs') }}
    union all
    select 'raw_operating_costs',    count(*), 144 from {{ source('raw', 'raw_operating_costs') }}

), count_violations as (

    select
        'row_count: ' || table_name as check_name,
        'expected ' || expected || ', got ' || actual as detail
    from row_counts
    where actual != expected

), integrity_violations as (

    -- A subscription's currency must match its merchant's market currency,
    -- otherwise the eur_fx join silently converts with the wrong rate.
    select
        'currency mismatch: subscription vs market' as check_name,
        'subscription_id ' || s.subscription_id as detail
    from {{ source('raw', 'raw_subscriptions') }} s
    join {{ source('raw', 'raw_merchants') }} m on s.merchant_id = m.merchant_id
    join {{ source('raw', 'raw_markets') }} k on m.country_code = k.country_code
    where s.currency != k.currency

    union all

    select
        'end_date before start_date',
        'subscription_id ' || subscription_id
    from {{ source('raw', 'raw_subscriptions') }}
    where end_date is not null and end_date < start_date

    union all

    select
        'negative mrr',
        'subscription_id ' || subscription_id
    from {{ source('raw', 'raw_subscriptions') }}
    where mrr_local < 0

    union all

    -- A churned merchant must carry a churn_date, and an active one must not.
    select
        'status inconsistent with churn_date',
        'merchant_id ' || merchant_id
    from {{ source('raw', 'raw_merchants') }}
    where (status = 'churned' and churn_date is null)
       or (status = 'active'  and churn_date is not null)

)

select * from count_violations
union all
select * from integrity_violations
