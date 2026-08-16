-- Market dimension. eur_fx lives here as an attribute for traceability, but it
-- must NOT be used downstream: every monetary measure reaching a fact table has
-- already been converted to EUR in staging. Converting twice is the failure this
-- comment exists to prevent.

select
    country_code,
    country_name,
    region,
    currency,
    eur_fx,
    launch_year,
    vat_rate,
    (currency = 'EUR') as is_eurozone
from {{ ref('stg_markets') }}
