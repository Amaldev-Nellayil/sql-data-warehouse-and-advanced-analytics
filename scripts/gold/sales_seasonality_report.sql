
/*
===============================================================================
sales seasonality report
===============================================================================
purpose:
    analyzes historical sales performance across calendar months to
    identify recurring revenue patterns, seasonal fluctuations,
    and differences in sales activity throughout the year.

source:
    gold.fact_sales

output:
    gold.report_sales_seasonality

granularity:
    one row per calendar month (january through december)

key metrics:
    - calendar month number and name
    - number of years observed
    - average monthly revenue
    - average monthly orders
    - average monthly quantity sold
    - minimum monthly revenue
    - maximum monthly revenue

business logic:
    - excludes transactions with null order dates.
    - aggregates sales by year-month before performing
      seasonality analysis.
    - combines observations from the same calendar month
      across different years.
    - calculates average monthly revenue, orders, and quantity
      using available monthly observations.
    - identifies the minimum and maximum monthly revenue
      recorded for each calendar month.
    - counts distinct years represented for each month.

assumptions and limitations:
    - averages are calculated using observed months only.
    - incomplete years or partial months may distort
      seasonal comparisons.
    - missing months are not automatically treated as
      zero-revenue periods.
    - observed monthly patterns do not necessarily establish
      statistically significant seasonality.

===============================================================================
*/

create or replace view gold.report_sales_seasonality as
with monthly_sales as (
    select
    date_trunc('month', order_date)::date as sales_month,
    sum(sales_amount) as monthly_revenue,
    count(distinct order_number) as total_orders,
    sum(quantity) as total_quantity
    from gold.fact_sales
    where order_date is not null
    group by date_trunc('month', order_date)::date
)

select
extract(month from sales_month)::int as month_number,
to_char(sales_month, 'FMMonth') as month_name,count(distinct extract(year from sales_month)) as years_observed,
round(avg(monthly_revenue), 2) as avg_monthly_revenue,
round(avg(total_orders), 2) as avg_monthly_orders,
round(avg(total_quantity), 2) as avg_monthly_quantity,
min(monthly_revenue) as min_monthly_revenue,
max(monthly_revenue) as max_monthly_revenue
from monthly_sales
group by extract(month from sales_month), to_char(sales_month, 'FMMonth')
order by month_number;
