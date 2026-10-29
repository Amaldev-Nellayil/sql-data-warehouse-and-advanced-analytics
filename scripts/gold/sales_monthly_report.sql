
/*
===============================================================================
monthly sales performance and trends report
===============================================================================
purpose:
    analyzes monthly sales performance, revenue growth, and historical
    trends to support business performance monitoring and reporting.

source:
    gold.fact_sales

output:
    gold.report_sales_monthly

granularity:
    one row per calendar month (year-month)

key metrics:
    - monthly sales revenue
    - total distinct orders
    - total quantity sold
    - average order revenue
    - month-over-month (mom) revenue growth percentage
    - year-over-year (yoy) revenue growth percentage
    - cumulative sales revenue
    - 3-month moving average of revenue

business logic:
    - excludes transactions with null order dates.
    - groups transactions by calendar month using date_trunc().
    - counts distinct order numbers to avoid double-counting
      orders containing multiple products.
    - calculates average order revenue as monthly revenue
      divided by the number of distinct orders.
    - calculates mom growth using the previous month's revenue.
    - calculates yoy growth using revenue from 12 months earlier.
    - calculates cumulative revenue using a running sum.
    - calculates the 3-month moving average using the current
      month and up to two preceding months.
    - returns null for growth percentages when comparison
      revenue is missing or zero.

assumptions and limitations:
    - lag(1) and lag(12) assume consecutive monthly observations.
      missing calendar months require additional handling.
    - the first two moving-average values use fewer than
      three months of available data.
    - incomplete reporting months may affect comparisons.

===============================================================================
*/

create or replace view gold.report_sales_monthly as
with monthly_sales as
(
select
date_trunc('month', order_date)::date as sales_month,
sum(sales_amount) as monthly_revenue,
count(distinct order_number) as total_orders,
sum(quantity) as total_quantity,
round(sum(sales_amount)::numeric/count(distinct order_number),2) as avg_order_revenue
from gold.fact_sales
where order_date is not null
group by date_trunc('month', order_date)::date
order by sales_month
)

, sales_comparison as
(
select
*,
lag(monthly_revenue,1) over (order by sales_month) as previous_month_revenue,
lag(monthly_revenue,12) over (order by sales_month) as previous_year_revenue,
sum(monthly_revenue) over (order by sales_month rows between unbounded preceding and current row) as cumulative_revenue,
round(avg(monthly_revenue) over (order by sales_month rows between 2 preceding and current row),2) as moving_avg_3m
from monthly_sales
)

select
sales_month,
monthly_revenue,
total_orders,
total_quantity,
avg_order_revenue,
cumulative_revenue,
moving_avg_3m,
round(100.0 * (monthly_revenue - previous_month_revenue)/nullif(previous_month_revenue, 0),2) as mom_growth_pct,
round(100.0 * (monthly_revenue - previous_year_revenue)/nullif(previous_year_revenue, 0),2) as yoy_growth_pct
from sales_comparison
order by sales_month;

