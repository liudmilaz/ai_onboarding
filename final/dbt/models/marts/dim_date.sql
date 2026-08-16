-- Conformed date dimension at MONTH grain - the grain every fact in this
-- warehouse shares. Day grain would be false precision: subscriptions are
-- billed monthly and every cost table reports monthly.

select
    month_start                                  as date_month,
    extract(year    from month_start)::int       as year,
    extract(quarter from month_start)::int       as quarter,
    extract(month   from month_start)::int       as month_of_year,
    to_char(month_start, 'YYYY-MM')              as year_month,
    to_char(month_start, 'Mon YYYY')             as month_label,
    (extract(year from month_start)::int
        || '-Q' || extract(quarter from month_start)::int) as year_quarter
from {{ ref('int_months') }}
