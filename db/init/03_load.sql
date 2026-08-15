-- Load the CSVs mounted read-only at /seed. Order matters: markets and products
-- first, then merchants, then subscriptions, so the foreign keys resolve.
-- In CSV format an unquoted empty field arrives as NULL, which is what we want
-- for end_date and churn_date.

\copy raw.raw_markets            FROM '/seed/raw_markets.csv'            WITH (FORMAT csv, HEADER true)
\copy raw.raw_products           FROM '/seed/raw_products.csv'           WITH (FORMAT csv, HEADER true)
\copy raw.raw_merchants          FROM '/seed/raw_merchants.csv'          WITH (FORMAT csv, HEADER true)
\copy raw.raw_subscriptions      FROM '/seed/raw_subscriptions.csv'      WITH (FORMAT csv, HEADER true)
\copy raw.raw_acquisition_costs  FROM '/seed/raw_acquisition_costs.csv'  WITH (FORMAT csv, HEADER true)
\copy raw.raw_operating_costs    FROM '/seed/raw_operating_costs.csv'    WITH (FORMAT csv, HEADER true)

ANALYZE;
