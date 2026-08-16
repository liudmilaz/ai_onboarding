-- Product dimension. price_eur and cogs_eur are already in euros (the minor-unit
-- conversion happens in staging), so gross_margin_pct can be checked against them.

select
    sku,
    product_name,
    product_type,
    price_eur,
    cogs_eur,
    gross_margin_pct,
    launched_at,
    (price_eur = 0) as is_free_plan
from {{ ref('stg_products') }}
