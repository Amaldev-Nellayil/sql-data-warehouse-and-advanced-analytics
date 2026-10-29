
/*
===============================================================================
Data Quality Tests: Gold Layer
===============================================================================
Database: datawarehouse
Schema:   gold

Script Purpose:
    This script validates the data quality, consistency, and integrity
    of the Gold Layer views used for business analytics and reporting.

    The Gold Layer follows a star schema consisting of two dimension
    views (customers and products) and one sales fact view.

Data Quality Checks:

    1. Customer Dimension (gold.dim_customers):
       - Verify surrogate keys are unique and not NULL.
       - Check the uniqueness of customer identifiers.
       - Validate customer information integrated from CRM and ERP.

    2. Product Dimension (gold.dim_products):
       - Verify surrogate keys are unique and not NULL.
       - Check product identifier uniqueness.
       - Validate product information and category integration.

    3. Sales Fact (gold.fact_sales):
       - Check customer and product key relationships.
       - Identify missing or unmatched dimension references.
       - Verify that joins have not introduced duplicate sales records.
       - Compare record counts between Silver and Gold layers.
       - Check the completeness of sales measures.

    4. Star Schema Integrity:
       - Validate relationships between fact and dimension views.
       - Identify inconsistencies introduced during data integration.
       - Verify that Gold data is suitable for analytical reporting.

Usage:
    Execute individual queries in DBeaver while connected to the
    'datawarehouse' PostgreSQL database.

Expected Results:
    - Key uniqueness and referential integrity checks should return
      no rows when their rules are satisfied.
    - Record counts should remain consistent where no filtering or
      aggregation is intended.
    - Analytical inspection queries may return records for review.

Notes:
    - These checks validate existing Gold Layer data and do not
      modify the underlying Silver Layer tables.
    - Gold objects are PostgreSQL views rather than physical tables.
    - Surrogate keys are generated dynamically using ROW_NUMBER().
    - Unmatched references should be investigated before treating
      them as data-quality failures.
===============================================================================
*/


-- ============================================================
-- 1. GOLD CUSTOMER DIMENSION
-- ============================================================

-- Check for NULL or duplicate surrogate keys
-- Expectation: No results

SELECT
    customer_key,
    COUNT(*)
FROM gold.dim_customers
GROUP BY customer_key
HAVING COUNT(*) > 1
    OR customer_key IS NULL;


-- ============================================================
-- 2. GOLD PRODUCT DIMENSION
-- ============================================================

-- Check for NULL or duplicate surrogate keys
-- Expectation: No results

SELECT
    product_key,
    COUNT(*)
FROM gold.dim_products
GROUP BY product_key
HAVING COUNT(*) > 1
    OR product_key IS NULL;


-- ============================================================
-- 3. GOLD SALES FACT
-- ============================================================

-- Check whether joining dimensions duplicates sales rows
-- Expectation: Both counts should match

SELECT
    (SELECT COUNT(*) FROM silver.crm_sales_details) AS silver_sales_rows,
    (SELECT COUNT(*) FROM gold.fact_sales) AS gold_sales_rows;
