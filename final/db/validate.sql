-- Data quality gate. Run after load; every check must return zero offending rows.

\echo '--- row counts (expected: 160 / 117 / 5 / 8 / 768 / 144) ---'
select 'raw_merchants'          as table_name, count(*) as rows from raw.raw_merchants
union all select 'raw_subscriptions',     count(*) from raw.raw_subscriptions
union all select 'raw_products',          count(*) from raw.raw_products
union all select 'raw_markets',           count(*) from raw.raw_markets
union all select 'raw_acquisition_costs', count(*) from raw.raw_acquisition_costs
union all select 'raw_operating_costs',   count(*) from raw.raw_operating_costs
order by 1;

\echo '--- referential integrity (expected: all zero) ---'
select 'subs without merchant' as check, count(*) as offending
from raw.raw_subscriptions s
left join raw.raw_merchants m using (merchant_id)
where m.merchant_id is null
union all
select 'subs without product', count(*)
from raw.raw_subscriptions s
left join raw.raw_products p on s.plan_sku = p.sku
where p.sku is null
union all
select 'merchants without market', count(*)
from raw.raw_merchants m
left join raw.raw_markets k using (country_code)
where k.country_code is null
union all
select 'currency mismatch sub vs market', count(*)
from raw.raw_subscriptions s
join raw.raw_merchants m using (merchant_id)
join raw.raw_markets k on m.country_code = k.country_code
where s.currency <> k.currency
union all
select 'end_date before start_date', count(*)
from raw.raw_subscriptions
where end_date is not null and end_date < start_date
union all
select 'negative mrr', count(*)
from raw.raw_subscriptions where mrr_local < 0;

\echo '--- the stock/flow trap: unfiltered vs filtered monthly cost ---'
select
    to_char(year_month, 'YYYY-MM')                                          as month,
    round(sum(amount_eur) / 100.0, 2)                                       as naive_total_eur,
    round(sum(amount_eur) filter (where cost_category <> 'cash_balance_eom')
          / 100.0, 2)                                                       as true_costs_eur
from raw.raw_operating_costs
group by 1 order by 1 limit 3;

-- ---------------------------------------------------------------------------
-- The checks above only PRINT. psql exits 0 on a successful SELECT no matter
-- what it returned, so ON_ERROR_STOP had nothing to stop on and a corrupt load
-- sailed through to dbt and Metabase. This block is what actually gates.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
    problems text := '';
    n bigint;
BEGIN
    SELECT count(*) INTO n FROM raw.raw_merchants;
    IF n <> 160 THEN problems := problems || format('raw_merchants=%s (want 160); ', n); END IF;
    SELECT count(*) INTO n FROM raw.raw_subscriptions;
    IF n <> 117 THEN problems := problems || format('raw_subscriptions=%s (want 117); ', n); END IF;
    SELECT count(*) INTO n FROM raw.raw_products;
    IF n <> 5   THEN problems := problems || format('raw_products=%s (want 5); ', n); END IF;
    SELECT count(*) INTO n FROM raw.raw_markets;
    IF n <> 8   THEN problems := problems || format('raw_markets=%s (want 8); ', n); END IF;
    SELECT count(*) INTO n FROM raw.raw_acquisition_costs;
    IF n <> 768 THEN problems := problems || format('raw_acquisition_costs=%s (want 768); ', n); END IF;
    SELECT count(*) INTO n FROM raw.raw_operating_costs;
    IF n <> 144 THEN problems := problems || format('raw_operating_costs=%s (want 144); ', n); END IF;

    SELECT count(*) INTO n FROM raw.raw_subscriptions s
      LEFT JOIN raw.raw_merchants m USING (merchant_id) WHERE m.merchant_id IS NULL;
    IF n > 0 THEN problems := problems || format('%s subs without merchant; ', n); END IF;

    SELECT count(*) INTO n FROM raw.raw_subscriptions s
      LEFT JOIN raw.raw_products p ON s.plan_sku = p.sku WHERE p.sku IS NULL;
    IF n > 0 THEN problems := problems || format('%s subs without product; ', n); END IF;

    SELECT count(*) INTO n FROM raw.raw_merchants m
      LEFT JOIN raw.raw_markets k USING (country_code) WHERE k.country_code IS NULL;
    IF n > 0 THEN problems := problems || format('%s merchants without market; ', n); END IF;

    SELECT count(*) INTO n FROM raw.raw_subscriptions s
      JOIN raw.raw_merchants m USING (merchant_id)
      JOIN raw.raw_markets k ON m.country_code = k.country_code
      WHERE s.currency <> k.currency;
    IF n > 0 THEN problems := problems || format('%s currency mismatches; ', n); END IF;

    SELECT count(*) INTO n FROM raw.raw_subscriptions
      WHERE end_date IS NOT NULL AND end_date < start_date;
    IF n > 0 THEN problems := problems || format('%s end_date before start_date; ', n); END IF;

    SELECT count(*) INTO n FROM raw.raw_subscriptions WHERE mrr_local < 0;
    IF n > 0 THEN problems := problems || format('%s negative mrr; ', n); END IF;

    IF problems <> '' THEN
        RAISE EXCEPTION 'DATA QUALITY GATE FAILED: %', problems;
    END IF;
    RAISE NOTICE 'data quality gate passed';
END $$;
