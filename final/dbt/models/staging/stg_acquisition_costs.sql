-- Channel- and market-level campaign spend. Local currency, minor units.
-- NB: this is NOT a subset of operating costs' sales_and_marketing line - it is
-- larger than it, so the two are independent and both are real cash out.

select
    a.cost_id,
    a.year_month                                as month_start,
    a.country_code,
    a.channel,
    a.currency,
    a.spend_amount / 100.0                      as spend_local,
    (a.spend_amount / 100.0) * mk.eur_fx        as spend_eur
from {{ source('raw', 'raw_acquisition_costs') }} a
join {{ ref('stg_markets') }} mk
    on a.country_code = mk.country_code
