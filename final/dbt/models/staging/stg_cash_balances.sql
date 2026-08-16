-- The stock half of raw_operating_costs: end-of-month cash position.
-- Isolated into its own model so it can never be summed alongside the flows.
--
-- WARNING: this series is known to contradict the P&L. Recorded cash rises
-- across 2024-25 while revenue minus operating costs minus acquisition spend
-- implies a material monthly burn. Do not build Cash Runway on it without
-- resolving that first - see the deferred task on the cash ledger.

select
    cost_id,
    year_month              as month_start,
    amount_eur / 100.0      as cash_balance_eur
from {{ source('raw', 'raw_operating_costs') }}
where cost_category = 'cash_balance_eom'
