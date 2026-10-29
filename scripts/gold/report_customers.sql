/*
===============================================================================
customer behavior report
===============================================================================
purpose:
    provides customer-level purchasing metrics, segmentation, and
    behavioral indicators for business reporting and analytics.

source:
    gold.dim_customers
    gold.fact_sales

output:
    gold.report_customers

granularity:
    one row per customer

key metrics:
    - total orders and revenue
    - total quantity and unique products
    - first and last order dates
    - customer lifespan and recency
    - average order value and average monthly spend
    - customer segmentation

===============================================================================
*/


create or replace view gold.report_customers as
select
c.customer_number,
concat(coalesce(c.first_name, ''),' ',coalesce(c.last_name, '')) as customer_name,
c.cntry,
extract(year from age(current_date, c.birthdate))::int as age,
count(distinct f.order_number) as total_orders,
coalesce(sum(f.sales_amount),0) as total_sales,
coalesce(sum(f.quantity),0) as total_quantity,
count(distinct f.product_key) as total_products,
min(f.order_date) as first_order_date,
max(f.order_date) as last_order_date,
(extract(year from age(max(f.order_date), min(f.order_date)))*12 + extract(month from age(max(f.order_date), min(f.order_date))))::int as lifespan_month,
(extract(year from age((select max(order_date) from gold.fact_sales), max(f.order_date)))*12 + extract(month from age((select max(order_date) from gold.fact_sales), max(f.order_date))))::int as recency_months,
round(1.0*coalesce(sum(f.sales_amount),0)/nullif(count(distinct f.order_number),0),2) as avg_order_value,
case
	when count(distinct f.order_number) = 0 then null
	else round(coalesce(sum(f.sales_amount),0)::numeric/greatest((extract(year from age(max(f.order_date), min(f.order_date)))*12 + extract(month from age(max(f.order_date), min(f.order_date))))::int,1),2)
end as avg_monthly_spend,
case
	when count(distinct f.order_number) = 0 then 'No Purchases'
	when (extract(year from age(max(f.order_date), min(f.order_date)))*12 + extract(month from age(max(f.order_date), min(f.order_date))))::int >= 12 and coalesce(sum(f.sales_amount),0) > 5000 then 'VIP'
	when (extract(year from age(max(f.order_date), min(f.order_date)))*12 + extract(month from age(max(f.order_date), min(f.order_date))))::int >= 12 and coalesce(sum(f.sales_amount),0) <= 5000 then 'Regular'
	else 'New'
end as customer_segment
from gold.dim_customers as c
left join gold.fact_sales as f
on c.customer_key = f.customer_key
group by
    c.customer_key,
    c.customer_number,
    c.first_name,
    c.last_name,
    c.cntry,
    c.birthdate;
