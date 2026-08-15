-- One row per market. eur_fx is the multiplier that takes a local amount to EUR.

select
    country_code,
    country_name,
    region,
    currency,
    eur_fx,
    launch_year,
    vat_rate
from {{ source('raw', 'raw_markets') }}
