-- Customer Acquisition Cost at month grain.
--
-- DELIBERATE NULLs. The last merchant signed up 2024-06-29, yet acquisition
-- spend continues through 2025 - 16,856 EUR of it. Dividing that by zero
-- signups is undefined, not infinite, and reporting a huge number would be
-- worse than reporting nothing. CAC is therefore NULL in months with no
-- signups, and the unattributed spend is surfaced in its own column so the
-- anomaly is visible rather than silently averaged away.

with spend as (

    select date_month, sum(spend_eur) as acquisition_spend_eur
    from {{ ref('fct_acquisition_spend') }}
    group by 1

), signups as (

    select signup_month as date_month, count(*) as new_merchants
    from {{ ref('dim_merchant') }}
    group by 1

)

select
    d.date_month,
    s.acquisition_spend_eur,
    coalesce(g.new_merchants, 0)                    as new_merchants,

    -- CAC is NULL for two distinct reasons, and conflating them would lie:
    --   no spend data   -> months before 2024-01, where spend was never reported.
    --                      coalesce-ing to zero would report a CAC of 0.00, which
    --                      reads as "customers were free" rather than "unknown".
    --   no signups      -> undefined, not infinite.
    case when s.acquisition_spend_eur is not null and coalesce(g.new_merchants, 0) > 0
         then round(s.acquisition_spend_eur / g.new_merchants, 2)
    end                                             as cac_eur,

    -- Spend in a month that acquired nobody. Real money, no customers.
    case when s.acquisition_spend_eur is not null and coalesce(g.new_merchants, 0) = 0
         then round(s.acquisition_spend_eur, 2)
         else 0
    end                                             as unattributed_spend_eur,

    (s.acquisition_spend_eur is not null
     and coalesce(g.new_merchants, 0) > 0)          as is_acquiring_month,
    (s.acquisition_spend_eur is not null)           as has_spend_data
from {{ ref('dim_date') }} d
left join spend   s on d.date_month = s.date_month
left join signups g on d.date_month = g.date_month
order by d.date_month
