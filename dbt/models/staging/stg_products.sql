-- Product catalogue. Minor units are converted to EUR here so nothing
-- downstream has to remember the /100.

select
    sku,
    name                        as product_name,
    type                        as product_type,
    price_eur / 100.0           as price_eur,
    cogs_eur  / 100.0           as cogs_eur,
    gross_margin_pct,
    launched_at
from {{ source('raw', 'raw_products') }}
