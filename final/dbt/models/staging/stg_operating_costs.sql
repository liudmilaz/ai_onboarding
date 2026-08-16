-- Operating cost FLOWS only. The source table also carries a stock
-- (cost_category = 'cash_balance_eom'), which is excluded here and surfaced
-- separately in stg_cash_balances. Leaving it in inflates monthly costs ~15x.
-- Already denominated in EUR; only the minor-units conversion is needed.

select
    cost_id,
    year_month              as month_start,
    cost_category,
    amount_eur / 100.0      as amount_eur,
    description
from {{ source('raw', 'raw_operating_costs') }}
where cost_category != 'cash_balance_eom'
