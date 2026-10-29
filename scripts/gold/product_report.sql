
/*
===============================================================================
product performance report
===============================================================================
purpose:
    consolidates product-level sales performance, customer reach,
    revenue contribution, and product segmentation for business analytics.

sources:
    gold.dim_products
    gold.fact_sales

output:
    gold.report_products

granularity:
    one row per product

key metrics:
    - total orders and revenue
    - total quantity sold
    - total unique purchasing customers
    - first and last sale dates
    - product selling lifespan and recency
    - average order revenue
    - average monthly revenue
    - revenue-based product performance segmentation

business logic:
    - includes products without recorded sales.
    - calculates recency relative to the latest order date in the dataset.
    - classifies products using abc/pareto revenue contribution:
        high-performing: first 80% of cumulative revenue
        mid-performing: next 15% of cumulative revenue
        low-performing: remaining 5% of cumulative revenue
    - products with identical revenue receive the same classification.
    - products without sales are classified as low-performing.
    - undefined averages are represented by null.

===============================================================================
*/


create or replace view gold.report_product as 
with base_query as 
(
select
p.product_key,
p.product_number,
p.product_name,
p.category,
p.subcategory,
p.cost,
f.order_number,
f.customer_key,
f.order_date,
f.sales_amount,
f.quantity
from gold.dim_products p
left join gold.fact_sales f
on p.product_key = f.product_key
)

, product_aggregation as
(select
product_number,
product_name,
category,
subcategory,
cost,
count(distinct order_number) as total_orders,
coalesce(sum(sales_amount),0) as total_sales,
coalesce(sum(quantity),0) as total_quantity,
count(distinct customer_key) as total_customers,
min(order_date) as  first_sale_date,
max(order_date) as  last_sale_date,
(extract(year from age(max(order_date), min(order_date))) * 12
 + extract(month from age(max(order_date), min(order_date))))::int as lifespan_months,
(extract(year from age((select max(order_date) from gold.fact_sales), max(order_date))) * 12
+ extract(month from age((select max(order_date) from gold.fact_sales),max(order_date))))::int as recency_months,
round(coalesce(sum(sales_amount),0)::numeric/nullif(count(distinct order_number),0),2) as avg_order_revenue,
case
	when count(distinct order_number) = 0 then null
	else round(coalesce(sum(sales_amount),0)::numeric/greatest((extract(year from age(max(order_date), min(order_date))) * 12
 + extract(month from age(max(order_date), min(order_date))))::int,1),2)
 end as avg_monthly_revenue
from base_query
group by product_number,
product_name,
category,
subcategory,
cost)

, revenue_analysis as (
    select
    *,
    coalesce(sum(total_sales) over (order by total_sales desc groups between unbounded preceding and 1 preceding),0) as revenue_before_tier,
        sum(total_sales) over () as overall_revenue
    from product_aggregation
)

select
    product_number,
    product_name,
    category,
    subcategory,
    cost,
    total_orders,
    total_sales,
    total_quantity,
    total_customers,
    first_sale_date,
    last_sale_date,
    lifespan_months,
    recency_months,
    avg_order_revenue,
    avg_monthly_revenue,
    case
	    when total_sales = 0 then 'Low-Performing'
	    when 100.0 * revenue_before_tier/nullif(overall_revenue, 0) < 80 then 'High-Performing'	
	    when 100.0 * revenue_before_tier/nullif(overall_revenue, 0) < 95 then 'Mid-Performing'	
	    else 'Low-Performing'
end as product_segment
from revenue_analysis;
