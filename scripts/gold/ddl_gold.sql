
/*
===============================================================================
DDL Script: Create Gold Layer Views
===============================================================================
Database: datawarehouse
Schema:   gold

Script Purpose:
    This script creates the Gold Layer views of the data warehouse,
    transforming and integrating Silver Layer data into a business-ready
    star schema for analytics and reporting.

    The Gold Layer consists of:
    - gold.dim_customers: Customer dimension enriched with demographic
      and geographical information from CRM and ERP systems.
    - gold.dim_products: Product dimension enriched with category,
      subcategory, maintenance, and product classification information.
    - gold.fact_sales: Sales fact view containing transactional measures
      and links to customer and product dimensions.

Key Operations:
    - Integrates data from multiple Silver Layer tables using LEFT JOIN.
    - Generates surrogate keys for customer and product dimensions
      using ROW_NUMBER().
    - Consolidates customer information and standardizes business fields.
    - Includes the latest product versions based on validity end dates.
    - Renames columns to provide business-friendly field names.
    - Establishes logical relationships between dimensions and facts.

Implementation:
    - Uses PostgreSQL CREATE OR REPLACE VIEW statements.
    - Views do not physically store separate copies of the data.
    - Data is retrieved dynamically from the underlying Silver tables.

Execution:
    Run while connected to the 'datawarehouse' PostgreSQL database.
    Ensure the 'gold' schema and required Silver tables already exist.

Usage:
    SELECT * FROM gold.dim_customers;
    SELECT * FROM gold.dim_products;
    SELECT * FROM gold.fact_sales;

Notes:
    Surrogate keys generated using ROW_NUMBER() are calculated
    dynamically and may change when the underlying data changes.

    CREATE OR REPLACE VIEW updates existing view definitions but may
    require DROP VIEW when changing existing column names or types.
===============================================================================
*/


-- =====================================================================
-- 1. CUSTOMER DIMENSION
-- View: gold.dim_customers
-- =====================================================================

CREATE OR REPLACE VIEW gold.dim_customers AS

SELECT
    ROW_NUMBER() OVER (ORDER BY ci.cst_id) AS customer_key,
    ci.cst_id AS customer_id,
    ci.cst_key AS customer_number,
    ci.cst_firstname AS first_name,
    ci.cst_lastname AS last_name,
    la.cntry,
    ci.cst_marital_status AS marital_status,

    -- Prioritize CRM gender; use ERP gender when unavailable
    CASE
        WHEN ci.cst_gndr != 'n/a' THEN ci.cst_gndr
        ELSE COALESCE(ca.gen, 'n/a')
    END AS gender,

    ca.bdate AS birthdate,
    ci.cst_create_date AS create_date

FROM silver.crm_cust_info ci

LEFT JOIN silver.erp_cust_az12 ca
    ON ca.cid = ci.cst_key

LEFT JOIN silver.erp_loc_a101 la
    ON la.cid = ci.cst_key;



-- =====================================================================
-- 2. PRODUCT DIMENSION
-- View: gold.dim_products
-- =====================================================================

CREATE OR REPLACE VIEW gold.dim_products AS

SELECT
    ROW_NUMBER() OVER (
        ORDER BY pi.prd_start_dt, pi.prd_key
    ) AS product_key,

    pi.prd_id AS product_id,
    pi.prd_key AS product_number,
    pi.prd_nm AS product_name,
    pi.cat_id AS category_id,
    pcg.cat AS category,
    pcg.subcat AS subcategory,
    pcg.maintenance AS maintenance,
    pi.prd_cost AS cost,
    pi.prd_line AS product_line,
    pi.prd_start_dt AS start_date

FROM silver.crm_prd_info pi

LEFT JOIN silver.erp_px_cat_g1v2 pcg
    ON pcg.id = pi.cat_id

-- Retain only the latest product versions
WHERE pi.prd_end_dt IS NULL;



-- =====================================================================
-- 3. SALES FACT
-- View: gold.fact_sales
-- =====================================================================

CREATE OR REPLACE VIEW gold.fact_sales AS

SELECT
    sd.sls_ord_num AS order_number,
    dp.product_key,
    dc.customer_key,
    sd.sls_order_dt AS order_date,
    sd.sls_ship_dt AS shipping_date,
    sd.sls_due_dt AS due_date,
    sd.sls_sales AS sales_amount,
    sd.sls_quantity AS quantity,
    sd.sls_price AS price

FROM silver.crm_sales_details sd

LEFT JOIN gold.dim_customers dc
    ON dc.customer_id = sd.sls_cust_id

LEFT JOIN gold.dim_products dp
    ON dp.product_number = sd.sls_prd_key;


-- =====================================================================
-- END OF GOLD LAYER VIEW DEFINITIONS
-- =====================================================================
