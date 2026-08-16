-- PERIODIC SNAPSHOT FACT
-- Grain: one row per month. Foreign key: date_month -> dim_date.
--
-- ADDITIVITY: cash_balance_eur is SEMI-ADDITIVE. Only last() is meaningful
-- across time; summing balances is nonsense.
--
-- KNOWN DATA QUALITY DEFECT - read before using this table.
-- This series contradicts the P&L. Recorded cash rises 49,785 -> 57,235 across
-- 2024-25 while revenue minus operating costs minus acquisition spend implies
-- a 3,253/month burn, a divergence of about 85,500 over 24 months.
--
-- Regression analysis shows the series is a function of TIME, not of the
-- business: monthly change fits a straight line in t at R2 = 0.971
-- (d_cash = -227.7 + 50.1*t), the level fits a quadratic at R2 = 0.9992, and
-- correlation with time (+0.985) far exceeds correlation with revenue (+0.401).
-- It is a synthetic curve, not an accounting artefact - no financing, accrual
-- or non-cash-expense mechanism produces a smooth monotonic ramp like this.
--
-- Consequently mart_burn_monthly derives burn from the P&L and treats this
-- column as reference only. Do not build runway on it without saying so.

select
    month_start         as date_month,
    cash_balance_eur,
    cash_balance_eur - lag(cash_balance_eur) over (order by month_start)
                        as cash_change_eur
from {{ ref('stg_cash_balances') }}
