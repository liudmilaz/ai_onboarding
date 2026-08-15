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
