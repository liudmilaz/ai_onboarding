-- Raw landing zone: one table per CSV in saas/, column names and types kept
-- faithful to the source. No cleaning happens here - that is dbt staging's job.
--
-- Money is stored as-is in MINOR UNITS (cents). price_eur = 1900 means EUR 19.00.
-- mrr_local and spend_amount are in LOCAL currency and need raw_markets.eur_fx.

CREATE SCHEMA IF NOT EXISTS raw;

CREATE TABLE raw.raw_markets (
    country_code  text PRIMARY KEY,
    country_name  text        NOT NULL,
    region        text        NOT NULL,
    currency      text        NOT NULL,
    eur_fx        numeric(12,5) NOT NULL,  -- amount_eur = amount_local * eur_fx
    launch_year   integer     NOT NULL,
    vat_rate      numeric(5,4) NOT NULL
);

CREATE TABLE raw.raw_products (
    sku              text PRIMARY KEY,
    name             text    NOT NULL,
    type             text    NOT NULL,   -- 'subscription' | 'software'
    price_eur        integer NOT NULL,   -- minor units
    cogs_eur         integer NOT NULL,   -- minor units
    gross_margin_pct numeric(5,3) NOT NULL,
    description      text,
    launched_at      date    NOT NULL
);

CREATE TABLE raw.raw_merchants (
    merchant_id   text PRIMARY KEY,
    merchant_name text NOT NULL,
    business_type text NOT NULL,
    country_code  text NOT NULL REFERENCES raw.raw_markets (country_code),
    city          text,
    signup_date   date NOT NULL,
    plan_type     text,
    status        text NOT NULL,         -- 'active' | 'churned'
    churn_date    date                   -- NULL while active
);

CREATE TABLE raw.raw_subscriptions (
    subscription_id     text PRIMARY KEY,
    merchant_id         text NOT NULL REFERENCES raw.raw_merchants (merchant_id),
    plan_sku            text NOT NULL REFERENCES raw.raw_products (sku),
    start_date          date NOT NULL,
    end_date            date,            -- NULL means still active
    mrr_local           integer NOT NULL, -- minor units, LOCAL currency
    currency            text    NOT NULL,
    cancellation_reason text,
    previous_plan_sku   text             -- free text, includes 'free'; not an FK
);

CREATE TABLE raw.raw_acquisition_costs (
    cost_id      text PRIMARY KEY,
    year_month   date NOT NULL,          -- first of month
    country_code text NOT NULL REFERENCES raw.raw_markets (country_code),
    channel      text NOT NULL,
    spend_amount integer NOT NULL,       -- minor units, LOCAL currency
    currency     text NOT NULL
);

CREATE TABLE raw.raw_operating_costs (
    cost_id       text PRIMARY KEY,
    year_month    date NOT NULL,         -- first of month
    cost_category text NOT NULL,         -- NB: 'cash_balance_eom' is a BALANCE, not a cost
    amount_eur    integer NOT NULL,      -- minor units, already EUR
    description   text
);

CREATE INDEX ON raw.raw_subscriptions (merchant_id);
CREATE INDEX ON raw.raw_subscriptions (plan_sku);
CREATE INDEX ON raw.raw_merchants (country_code);
CREATE INDEX ON raw.raw_acquisition_costs (year_month);
CREATE INDEX ON raw.raw_operating_costs (year_month);
