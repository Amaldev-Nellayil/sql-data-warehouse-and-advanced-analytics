
/*
===============================================================================
geographic sales performance report
===============================================================================
purpose:
    analyzes sales performance across customer countries to identify
    geographical revenue distribution, market contribution, and
    differences in purchasing activity.

sources:
    gold.fact_sales
    gold.dim_customers

output:
    gold.report_sales_geography

granularity:
    one row per customer country

key metrics:
    - country
    - total sales revenue
    - total distinct orders
    - total quantity sold
    - total unique purchasing customers
    - average order value
    - revenue contribution percentage
    - revenue ranking by country

business logic:
    - uses sales transactions as the base dataset.
    - left joins customer information to preserve sales records
      without matching customer details.
    - excludes transactions with null order dates.
    - assigns unmatched or null customer countries to 'Unknown'.
    - counts distinct order numbers to prevent double-counting
      orders containing multiple products.
    - counts distinct customer keys to measure unique buyers.
    - calculates average order value as total country revenue
      divided by the number of distinct orders.
    - calculates each country's percentage contribution
      to total revenue.
    - ranks countries by revenue using dense_rank(),
      assigning the same rank to countries with equal revenue.
    - returns null for undefined ratios when the
      denominator is zero.

assumptions and limitations:
    - geographic attribution is based on the customer's
      country, not the shipping or delivery destination.
    - each order is assumed to belong to one customer
      and therefore one country.
    - revenue contribution percentages are rounded to
      two decimal places and may not sum to exactly 100%.
    - missing or unmatched customer records are grouped
      under 'Unknown' rather than excluded.

===============================================================================
*/


create or replace view gold.report_sales_geography as
with base_query as (
    select
    f.order_number,
    f.customer_key,
    f.sales_amount,
    f.quantity,
    coalesce(c.cntry, 'Unknown') as country
    from gold.fact_sales f
    left join gold.dim_customers c
    on f.customer_key = c.customer_key
    where f.order_date is not null
),

country_aggregation as (
    select
    country,
    coalesce(sum(sales_amount), 0) as total_sales,
    count(distinct order_number) as total_orders,
    coalesce(sum(quantity), 0) as total_quantity,
    count(distinct customer_key) as total_customers
    from base_query
    group by country
)

select
country,
total_sales,
total_orders,
total_quantity,
total_customers,
round(total_sales::numeric/nullif(total_orders, 0),2) as avg_order_value,
round(100.0 * total_sales/nullif(sum(total_sales) over (), 0),2) as revenue_contribution_pct,
dense_rank() over (order by total_sales desc) as revenue_rank
from country_aggregation
order by revenue_rank, country;
