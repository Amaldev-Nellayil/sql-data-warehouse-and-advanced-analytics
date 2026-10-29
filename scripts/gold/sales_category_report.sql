
/*
===============================================================================
category sales performance report
===============================================================================
purpose:
    analyzes sales performance across product categories to identify
    revenue distribution, category contribution, purchasing activity,
    and differences in sales performance.

sources:
    gold.fact_sales
    gold.dim_products

output:
    gold.report_sales_category

granularity:
    one row per product category

key metrics:
    - product category
    - total sales revenue
    - total distinct orders
    - total quantity sold
    - total unique purchasing customers
    - average order value
    - revenue contribution percentage
    - revenue ranking by category

business logic:
    - uses sales transactions as the base dataset.
    - left joins product information to preserve sales records
      without matching product details.
    - excludes transactions with null order dates.
    - assigns unmatched or null product categories to 'Unknown'.
    - counts distinct order numbers to avoid double-counting
      orders containing multiple products.
    - counts distinct customer keys to identify unique buyers.
    - calculates average order value as total category revenue
      divided by the number of distinct orders containing
      products from that category.
    - calculates each category's percentage contribution
      to overall sales revenue.
    - ranks categories by revenue using dense_rank(),
      assigning equal ranks to categories with identical revenue.
    - returns null for undefined ratios when the
      denominator is zero.

assumptions and limitations:
    - product classifications are obtained from the Gold
      product dimension, which includes current product versions
      where prd_end_dt is null.
    - sales without a matching product are grouped under
      'Unknown' rather than excluded.
    - orders containing products from multiple categories
      are counted once in each relevant category.
      therefore, category-level order counts are not additive.
    - revenue contribution percentages are rounded to
      two decimal places and may not sum to exactly 100%.
    - revenue represents sales performance, not profitability.

===============================================================================
*/


create or replace view gold.report_sales_category as

with base_query as (
    select
    f.order_number,
    f.customer_key,
    f.sales_amount,
    f.quantity,
    coalesce(p.category, 'Unknown') as category
    from gold.fact_sales f
    left join gold.dim_products p
    on f.product_key = p.product_key
    where f.order_date is not null
),

category_aggregation as (
    select
    category,
    coalesce(sum(sales_amount), 0) as total_sales,
    count(distinct order_number) as total_orders,
    coalesce(sum(quantity), 0) as total_quantity,
    count(distinct customer_key) as total_customers
    from base_query
    group by category
)

select
category,
total_sales,
total_orders,
total_quantity,
total_customers,
round(total_sales::numeric/nullif(total_orders, 0),2) as avg_order_value,
round(100.0 * total_sales/nullif(sum(total_sales) over (), 0),2) as revenue_contribution_pct,
dense_rank() over (order by total_sales desc) as revenue_rank
from category_aggregation
order by revenue_rank, category;
