/*
===============================================================================
analytics reporting — data quality and reconciliation checks
===============================================================================
purpose:
    validate gold-layer customer, product, monthly sales, seasonality,
    geographic sales, and category sales reporting views.

reports:
    gold.report_customers
    gold.report_product
    gold.report_sales_monthly
    gold.report_sales_seasonality
    gold.report_sales_geography
    gold.report_sales_category

usage:
    execute checks individually in dbeaver and review the results.
    these are diagnostic queries, not automated pass/fail assertions.

notes:
    - geography, category, monthly, and seasonality reports exclude sales
      with null order_date; reconcile them against the same dated fact subset.
    - customer and product reports use dimension-driven left joins, so their
      reported sales may omit fact records without matching dimension keys.
    - percentages are rounded in the reporting views and can total 99.99 or
      100.01 without indicating a problem.
===============================================================================
*/

-- 1. customer report: row count should match the customer dimension
select
    (select count(*) from gold.dim_customers) as dimension_rows,
    (select count(*) from gold.report_customers) as report_rows,
    (select count(*) - count(distinct customer_number)
     from gold.report_customers) as duplicate_or_null_customer_numbers;

-- 2. customer report: zero-purchase customers should have zero totals and
--    null purchase-based averages and dates; expected result: no rows
select *
from gold.report_customers
where total_orders = 0
  and (
      total_sales <> 0
      or total_quantity <> 0
      or total_products <> 0
      or first_order_date is not null
      or last_order_date is not null
      or avg_order_value is not null
      or avg_monthly_spend is not null
      or customer_segment <> 'No Purchases'
  );

-- 3. customer report: confirm segment distribution (diagnostic)
select 
customer_segment, count(*) as customer_count,
sum(total_sales) as total_sales
from gold.report_customers
group by customer_segment
order by customer_count desc;

-- 4. product report: row count should match product dimension
select
(select count(*) from gold.dim_products) as dimension_rows,
(select count(*) from gold.report_product) as report_rows,
(select count(*) - count(distinct product_number)
from gold.report_product) as duplicate_or_null_product_numbers;

-- 5. product report: identical revenue values must share a segment
--    expected result: no rows (if tie-aware groups framing was implemented)
select total_sales, count(distinct product_segment) as segments_at_same_revenue
from gold.report_product
group by total_sales
having count(distinct product_segment) > 1;

-- 6. product report: products with zero sales should be low-performing
--    and have no sale dates or revenue averages; expected result: no rows
select *
from gold.report_product
where total_orders = 0
  and (
      total_sales <> 0
      or total_quantity <> 0
      or total_customers <> 0
      or first_sale_date is not null
      or last_sale_date is not null
      or avg_order_revenue is not null
      or avg_monthly_revenue is not null
      or product_segment <> 'Low-Performing'
  );



-- 7. monthly sales: compare total revenue and quantity to dated fact sales
--    expected: differences = 0
select
    (select coalesce(sum(monthly_revenue), 0)
     from gold.report_sales_monthly)
    - (select coalesce(sum(sales_amount), 0)
       from gold.fact_sales where order_date is not null) as revenue_difference,
    (select coalesce(sum(total_quantity), 0)
     from gold.report_sales_monthly)
    - (select coalesce(sum(quantity), 0)
       from gold.fact_sales where order_date is not null) as quantity_difference;


-- 8. monthly sales: check missing calendar months
--    expected: no rows if each month is represented
with bounds as (
    select min(sales_month) as first_month, max(sales_month) as last_month
    from gold.report_sales_monthly
)
select gs.month_start::date as missing_month
from bounds b
cross join lateral generate_series(
    b.first_month::timestamp, b.last_month::timestamp, interval '1 month'
) as gs(month_start)
left join gold.report_sales_monthly m
    on m.sales_month = gs.month_start::date
where m.sales_month is null
order by missing_month;

-- 9. monthly sales: reconcile lag-based growth against adjacent reports
--    expected: no rows; tolerates 0.01 percentage-point rounding
with comparisons as (
    select
        sales_month,
        mom_growth_pct,
        yoy_growth_pct,
        lag(monthly_revenue) over (order by sales_month) as prev_month,
        lag(monthly_revenue, 12) over (order by sales_month) as prev_year,
        monthly_revenue
    from gold.report_sales_monthly
), expected as (
    select *,
        round(100.0 * (monthly_revenue - prev_month) /
              nullif(prev_month, 0), 2) as expected_mom,
        round(100.0 * (monthly_revenue - prev_year) /
              nullif(prev_year, 0), 2) as expected_yoy
    from comparisons
)
select sales_month, mom_growth_pct, expected_mom,
       yoy_growth_pct, expected_yoy
from expected
where mom_growth_pct is distinct from expected_mom
   or yoy_growth_pct is distinct from expected_yoy;

-- 10. seasonality: each year-month in monthly sales contributes exactly once
--     to its calendar-month group; expected: no rows
with observed as (
    select extract(month from sales_month)::int as month_number,
           count(*) as month_observations,
           round(avg(monthly_revenue), 2) as expected_average
    from gold.report_sales_monthly
    group by extract(month from sales_month)::int
)
select s.month_number, s.years_observed, o.month_observations,
       s.avg_monthly_revenue, o.expected_average
from gold.report_sales_seasonality s
join observed o using (month_number)
where s.years_observed <> o.month_observations
   or s.avg_monthly_revenue is distinct from o.expected_average;

-- 11. geography: report revenue equals dated sales fact revenue
--     expected: difference = 0 if dimension joins do not multiply fact rows
select
    (select coalesce(sum(total_sales), 0)
     from gold.report_sales_geography)
    - (select coalesce(sum(sales_amount), 0)
       from gold.fact_sales where order_date is not null) as revenue_difference;

-- 12. category: report revenue equals dated sales fact revenue
--     expected: difference = 0 if dimension joins do not multiply fact rows
select
    (select coalesce(sum(total_sales), 0)
     from gold.report_sales_category)
    - (select coalesce(sum(sales_amount), 0)
       from gold.fact_sales where order_date is not null) as revenue_difference;

-- 13. geography and category: sum of rounded contribution percentages
--     expected: approximately 100%, not necessarily exactly 100.00
select 'geography' as report,
       sum(revenue_contribution_pct) as summed_percentages
from gold.report_sales_geography
union all
select 'category', sum(revenue_contribution_pct)
from gold.report_sales_category;

-- 14. compare product/customer report revenue with fact sales:
--     differences may reflect unmatched dimension references, not report errors
select
    (select coalesce(sum(sales_amount), 0) from gold.fact_sales) as fact_revenue,
    (select coalesce(sum(total_sales), 0) from gold.report_customers)
        as customer_report_revenue,
    (select coalesce(sum(total_sales), 0) from gold.report_product)
        as product_report_revenue;

-- 15. inspect fact records with missing dimension matches
--     these can explain differences in customer/product report totals
select
    count(*) filter (where customer_key is null) as unmatched_customer_rows,
    count(*) filter (where product_key is null) as unmatched_product_rows,
    coalesce(sum(sales_amount) filter (where customer_key is null), 0)
        as unmatched_customer_revenue,
    coalesce(sum(sales_amount) filter (where product_key is null), 0)
        as unmatched_product_revenue
from gold.fact_sales;
