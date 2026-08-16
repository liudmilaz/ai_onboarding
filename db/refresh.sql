-- Reload the raw layer from the CSVs without destroying the database.
--
-- Wrapped in a transaction: if any COPY fails, the whole reload rolls back and
-- the previous data is still there. A partial reload would be worse than no
-- reload, because the models would build cleanly on top of half a dataset.
--
-- TRUNCATE order does not matter under CASCADE, but the reload order does:
-- markets and products first, then merchants, then subscriptions, so foreign
-- keys resolve as rows arrive.

begin;

truncate table
    raw.raw_subscriptions,
    raw.raw_acquisition_costs,
    raw.raw_operating_costs,
    raw.raw_merchants,
    raw.raw_products,
    raw.raw_markets
cascade;

\copy raw.raw_markets            FROM '/seed/raw_markets.csv'            WITH (FORMAT csv, HEADER true)
\copy raw.raw_products           FROM '/seed/raw_products.csv'           WITH (FORMAT csv, HEADER true)
\copy raw.raw_merchants          FROM '/seed/raw_merchants.csv'          WITH (FORMAT csv, HEADER true)
\copy raw.raw_subscriptions      FROM '/seed/raw_subscriptions.csv'      WITH (FORMAT csv, HEADER true)
\copy raw.raw_acquisition_costs  FROM '/seed/raw_acquisition_costs.csv'  WITH (FORMAT csv, HEADER true)
\copy raw.raw_operating_costs    FROM '/seed/raw_operating_costs.csv'    WITH (FORMAT csv, HEADER true)

commit;

ANALYZE;
