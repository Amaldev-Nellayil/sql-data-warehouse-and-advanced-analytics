/*
===============================================================================
Data Quality Tests: Silver Layer
===============================================================================
Database: datawarehouse
Schema:   silver

Script Purpose:
    This script validates the quality and consistency of data loaded into
    the Silver layer after transformation from the Bronze layer.

Data Quality Checks:
    1. Key integrity:
       - Identify NULL or duplicate values in expected key columns.
       - Check relationships between CRM and ERP datasets.

    2. String quality:
       - Detect unwanted leading and trailing whitespace.
       - Verify standardized identifiers and categorical values.

    3. Data completeness:
       - Identify missing or NULL values in required fields.
       - Inspect fields where missing values were replaced or derived.

    4. Data consistency:
       - Validate product costs, sales amounts, quantities, and prices.
       - Investigate invalid or inconsistent dates.
       - Check product validity periods and derived attributes.

    5. Data standardization:
       - Inspect standardized gender, marital status, product-line,
         country, and other categorical values.

    6. Cross-system integrity:
       - Identify customer, product, and category references that
         do not match across related datasets.

Usage:
    Execute individual queries in DBeaver while connected to the
    'datawarehouse' PostgreSQL database.

Expected Results:
    Queries labeled "Expectation: No results" should return zero rows
    when their corresponding data-quality rule is satisfied.

    Queries inspecting DISTINCT values or sample records are intended
    for manual review and may return rows.

Notes:
    - These tests do not modify source or Silver-layer data.
    - Unmatched records and business-rule exceptions should be
      investigated before being classified as data-quality failures.
===============================================================================
*/

-- =====================================================================
-- SILVER LAYER - DATA QUALITY CHECKS
-- Database: datawarehouse
-- =====================================================================


-- =====================================================================
-- 1. CRM CUSTOMER INFORMATION
-- Table: silver.crm_cust_info
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1.1 Check for NULLs or duplicate customer IDs
-- Expectation: No results
-- ---------------------------------------------------------------------

SELECT
    cst_id,
    COUNT(*)
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1
    OR cst_id IS NULL;


-- ---------------------------------------------------------------------
-- 1.2 Check for NULLs or duplicate customer keys
-- Expectation: No results
-- ---------------------------------------------------------------------

SELECT
    cst_key,
    COUNT(*)
FROM silver.crm_cust_info
GROUP BY cst_key
HAVING COUNT(*) > 1
    OR cst_key IS NULL;


-- ---------------------------------------------------------------------
-- 1.3 Check for unwanted spaces in customer names
-- Expectation: No results
-- ---------------------------------------------------------------------

SELECT
    cst_id
FROM silver.crm_cust_info
WHERE TRIM(cst_firstname) != cst_firstname
   OR TRIM(cst_lastname) != cst_lastname;


-- ---------------------------------------------------------------------
-- 1.4 Inspect standardized gender values
-- ---------------------------------------------------------------------

SELECT DISTINCT
    cst_gndr
FROM silver.crm_cust_info;


-- ---------------------------------------------------------------------
-- 1.5 Inspect customer records
-- ---------------------------------------------------------------------

SELECT *
FROM silver.crm_cust_info
LIMIT 1000;



-- =====================================================================
-- 2. CRM PRODUCT INFORMATION
-- Table: silver.crm_prd_info
-- =====================================================================

-- ---------------------------------------------------------------------
-- 2.1 Inspect product transformations
-- ---------------------------------------------------------------------

SELECT
    prd_id,
    REPLACE(SUBSTR(prd_key, 1, 5), '-', '_') AS cat_id,
    SUBSTR(prd_key, 7, LENGTH(prd_key)) AS prd_key,
    prd_nm,
    COALESCE(prd_cost, 0) AS prd_cost,
    CASE UPPER(TRIM(prd_line))
        WHEN 'M' THEN 'Mountain'
        WHEN 'R' THEN 'Road'
        WHEN 'S' THEN 'Other Sales'
        WHEN 'T' THEN 'Touring'
        ELSE 'n/a'
    END AS prd_line,
    prd_start_dt,
    LEAD(prd_start_dt) OVER (
        PARTITION BY prd_key
        ORDER BY prd_start_dt ASC
    ) - 1 AS prd_end_dt
FROM silver.crm_prd_info
LIMIT 1000;


-- ---------------------------------------------------------------------
-- 2.2 Check for NULLs or duplicate product IDs
-- Expectation: No results
-- ---------------------------------------------------------------------

SELECT
    prd_id,
    COUNT(*)
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1
    OR prd_id IS NULL;


-- ---------------------------------------------------------------------
-- 2.3 Check for unwanted spaces in product names
-- Expectation: No results
-- ---------------------------------------------------------------------

SELECT
    prd_nm
FROM silver.crm_prd_info
WHERE TRIM(prd_nm) != prd_nm;


-- ---------------------------------------------------------------------
-- 2.4 Check for NULL or negative product costs
-- Expectation: No results
-- ---------------------------------------------------------------------

SELECT
    prd_id,
    prd_cost
FROM silver.crm_prd_info
WHERE prd_cost < 0
   OR prd_cost IS NULL;


-- ---------------------------------------------------------------------
-- 2.5 Inspect standardized product-line values
-- ---------------------------------------------------------------------

SELECT DISTINCT
    prd_line
FROM silver.crm_prd_info;


-- ---------------------------------------------------------------------
-- 2.6 Check product validity periods
-- Expectation: No results
-- ---------------------------------------------------------------------

SELECT
    prd_key,
    prd_start_dt
FROM silver.crm_prd_info
WHERE prd_end_dt < prd_start_dt;



-- =====================================================================
-- 3. CRM SALES DETAILS
-- Table: silver.crm_sales_details
-- =====================================================================

-- ---------------------------------------------------------------------
-- 3.1 Inspect sales transformations
-- ---------------------------------------------------------------------

SELECT
    sls_ord_num,
    sls_prd_key,
    sls_cust_id,

    CASE
        WHEN sls_order_dt <= 0
          OR LENGTH(sls_order_dt::TEXT) != 8
        THEN NULL
        ELSE TO_DATE(sls_order_dt::TEXT, 'YYYYMMDD')
    END AS sls_order_dt,

    CASE
        WHEN sls_ship_dt <= 0
          OR LENGTH(sls_ship_dt::TEXT) != 8
        THEN NULL
        ELSE TO_DATE(sls_ship_dt::TEXT, 'YYYYMMDD')
    END AS sls_ship_dt,

    CASE
        WHEN sls_due_dt <= 0
          OR LENGTH(sls_due_dt::TEXT) != 8
        THEN NULL
        ELSE TO_DATE(sls_due_dt::TEXT, 'YYYYMMDD')
    END AS sls_due_dt,

    CASE
        WHEN sls_sales <= 0
          OR sls_sales IS NULL
          OR sls_sales != ABS(sls_quantity * sls_price)
        THEN ABS(sls_quantity * sls_price)
        ELSE sls_sales
    END AS sls_sales,

    sls_quantity,

    CASE
        WHEN sls_price <= 0
          OR sls_price IS NULL
        THEN ABS(sls_sales / NULLIF(sls_quantity, 0))
        ELSE sls_price
    END AS sls_price

FROM silver.crm_sales_details
LIMIT 1000;


-- ---------------------------------------------------------------------
-- 3.2 Check customer references in sales
-- Expectation: No unmatched customer IDs
-- ---------------------------------------------------------------------

SELECT
    sls_cust_id
FROM silver.crm_sales_details
WHERE sls_cust_id NOT IN (
    SELECT
        cst_id
    FROM silver.crm_cust_info
);


-- ---------------------------------------------------------------------
-- 3.3 Check order numbers for unwanted spaces or NULLs
-- Expectation: No results
-- ---------------------------------------------------------------------

SELECT
    sls_ord_num
FROM silver.crm_sales_details
WHERE TRIM(sls_ord_num) != sls_ord_num
   OR sls_ord_num IS NULL;


-- ---------------------------------------------------------------------
-- 3.4 Check product references in sales
-- Expectation: No unmatched or NULL product keys
-- ---------------------------------------------------------------------

SELECT
    sls_prd_key
FROM silver.crm_sales_details
WHERE sls_prd_key NOT IN (
    SELECT
        prd_key
    FROM silver.crm_prd_info
)
OR sls_prd_key IS NULL;


-- ---------------------------------------------------------------------
-- 3.5 Original exploratory date check
-- Kept commented out from the original script
-- ---------------------------------------------------------------------

/*
SELECT
    sls_ord_num,
    sls_ship_dt
FROM silver.crm_sales_details
WHERE sls_ship_dt = 0
   OR LENGTH(CAST(sls_ship_dt AS VARCHAR)) != 8;
*/


-- ---------------------------------------------------------------------
-- 3.6 Check for NULL, zero, or negative prices
-- Expectation: No results
-- ---------------------------------------------------------------------

SELECT
    sls_ord_num,
    sls_price
FROM silver.crm_sales_details
WHERE sls_price IS NULL
   OR sls_price <= 0;


-- ---------------------------------------------------------------------
-- 3.7 Check for NULL, zero, or negative sales
-- Expectation: No results
-- ---------------------------------------------------------------------

SELECT
    sls_ord_num,
    sls_sales
FROM silver.crm_sales_details
WHERE sls_sales IS NULL
   OR sls_sales <= 0;



-- =====================================================================
-- 4. ERP CUSTOMER INFORMATION
-- Table: silver.erp_cust_az12
-- =====================================================================

-- ---------------------------------------------------------------------
-- 4.1 Inspect ERP customer transformations
-- ---------------------------------------------------------------------

SELECT
    RIGHT(cid, 10) AS cid,

    CASE
        WHEN bdate > CURRENT_DATE THEN NULL
        ELSE bdate
    END AS bdate,

    CASE
        WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
        WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
        ELSE 'n/a'
    END AS gen

FROM silver.erp_cust_az12
LIMIT 1000;


-- ---------------------------------------------------------------------
-- 4.2 Check for NULL customer IDs
-- Expectation: No results
-- ---------------------------------------------------------------------

SELECT
    cid
FROM silver.erp_cust_az12
WHERE cid IS NULL;


-- ---------------------------------------------------------------------
-- 4.3 Check for duplicate customer IDs
-- Expectation: No results
-- ---------------------------------------------------------------------

SELECT
    cid,
    COUNT(*)
FROM silver.erp_cust_az12
GROUP BY cid
HAVING COUNT(*) > 1;


-- ---------------------------------------------------------------------
-- 4.4 Check customer IDs for unwanted spaces/case differences
-- Expectation: No results
-- ---------------------------------------------------------------------

SELECT
    cid
FROM silver.erp_cust_az12
WHERE UPPER(TRIM(cid)) != cid;


-- ---------------------------------------------------------------------
-- 4.5 Inspect customer IDs with 13 characters
-- ---------------------------------------------------------------------

SELECT
    cid,
    RIGHT(cid, 10) AS test_cid
FROM silver.erp_cust_az12
WHERE LENGTH(cid) = 13;


-- ---------------------------------------------------------------------
-- 4.6 Check ERP customer IDs against CRM customer keys
-- Expectation: No unmatched customer IDs
-- ---------------------------------------------------------------------

SELECT
    cid,
    RIGHT(cid, 10) AS test_cid
FROM silver.erp_cust_az12
WHERE RIGHT(cid, 10) NOT IN (
    SELECT
        cst_key
    FROM silver.crm_cust_info
);


-- ---------------------------------------------------------------------
-- 4.7 Check for future birthdates
-- Expectation: No results
-- ---------------------------------------------------------------------

SELECT
    bdate
FROM silver.erp_cust_az12
WHERE bdate > CURRENT_DATE;


-- ---------------------------------------------------------------------
-- 4.8 Inspect gender standardization
-- ---------------------------------------------------------------------

SELECT DISTINCT
    gen,

    CASE
        WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
        WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
        ELSE 'n/a'
    END AS standardized_gen

FROM silver.erp_cust_az12;



-- =====================================================================
-- 5. ERP LOCATION INFORMATION
-- Table: silver.erp_loc_a101
-- =====================================================================

-- ---------------------------------------------------------------------
-- 5.1 Inspect ERP location transformations
-- ---------------------------------------------------------------------

SELECT
    REPLACE(cid, '-', '') AS cid,

    CASE
        WHEN UPPER(TRIM(cntry)) IN ('US', 'USA') THEN 'United States'
        WHEN UPPER(TRIM(cntry)) = 'DE' THEN 'Germany'
        WHEN cntry IS NULL OR TRIM(cntry) = '' THEN 'n/a'
        ELSE cntry
    END AS cntry

FROM bronze.erp_loc_a101
LIMIT 1000;


-- ---------------------------------------------------------------------
-- 5.2 Check for NULL customer IDs
-- Expectation: No results
-- ---------------------------------------------------------------------

SELECT
    cid
FROM silver.erp_loc_a101
WHERE cid IS NULL;


-- ---------------------------------------------------------------------
-- 5.3 Check for duplicate customer IDs
-- Expectation: No results
-- ---------------------------------------------------------------------

SELECT
    cid,
    COUNT(*)
FROM silver.erp_loc_a101
GROUP BY cid
HAVING COUNT(*) > 1;


-- ---------------------------------------------------------------------
-- 5.4 Check customer IDs against CRM customer keys
-- ---------------------------------------------------------------------

SELECT
    REPLACE(cid, '-', '') AS cid_test
FROM silver.erp_loc_a101
WHERE REPLACE(cid, '-', '') NOT IN (
    SELECT
        cst_key
    FROM silver.crm_cust_info
);


-- ---------------------------------------------------------------------
-- 5.5 Check standardized customer ID length
-- Expectation: No results
-- ---------------------------------------------------------------------

SELECT
    REPLACE(cid, '-', '') AS cid_test,
    LENGTH(REPLACE(cid, '-', '')) AS cid_length
FROM silver.erp_loc_a101
WHERE LENGTH(REPLACE(cid, '-', '')) != 10;


-- ---------------------------------------------------------------------
-- 5.6 Inspect distinct country values
-- ---------------------------------------------------------------------

SELECT DISTINCT
    cntry
FROM silver.erp_loc_a101;


-- ---------------------------------------------------------------------
-- 5.7 Inspect country standardization
-- ---------------------------------------------------------------------

SELECT
    cntry,

    CASE
        WHEN UPPER(TRIM(cntry)) IN ('US', 'USA') THEN 'United States'
        WHEN UPPER(TRIM(cntry)) = 'DE' THEN 'Germany'
        WHEN cntry IS NULL OR cntry = '' THEN 'n/a'
        ELSE cntry
    END AS cntry_test

FROM silver.erp_loc_a101;



-- =====================================================================
-- 6. ERP PRODUCT CATEGORY INFORMATION
-- Table: silver.erp_px_cat_g1v2
-- =====================================================================

-- ---------------------------------------------------------------------
-- 6.1 Inspect product category records
-- ---------------------------------------------------------------------

SELECT
    id,
    cat,
    subcat,
    maintenance
FROM silver.erp_px_cat_g1v2;


-- ---------------------------------------------------------------------
-- 6.2 Check for NULL category IDs
-- Expectation: No results
-- ---------------------------------------------------------------------

SELECT
    id
FROM silver.erp_px_cat_g1v2
WHERE id IS NULL;


-- ---------------------------------------------------------------------
-- 6.3 Check for duplicate category IDs
-- Expectation: No results
-- ---------------------------------------------------------------------

SELECT
    id,
    COUNT(*)
FROM silver.erp_px_cat_g1v2
GROUP BY id
HAVING COUNT(*) > 1;


-- ---------------------------------------------------------------------
-- 6.4 Check category IDs against CRM product categories
-- Investigate any unmatched categories
-- ---------------------------------------------------------------------

SELECT
    id
FROM silver.erp_px_cat_g1v2
WHERE id NOT IN (
    SELECT
        cat_id
    FROM silver.crm_prd_info
);


-- ---------------------------------------------------------------------
-- 6.5 Check for unwanted spaces in category attributes
-- Expectation: No results
-- ---------------------------------------------------------------------

SELECT
    cat,
    subcat,
    maintenance
FROM silver.erp_px_cat_g1v2
WHERE TRIM(cat) != cat
   OR TRIM(subcat) != subcat
   OR TRIM(maintenance) != maintenance;


-- ---------------------------------------------------------------------
-- 6.6 Inspect distinct maintenance values
-- ---------------------------------------------------------------------

SELECT DISTINCT
    maintenance
FROM silver.erp_px_cat_g1v2;


-- =====================================================================
-- END OF SILVER LAYER DATA QUALITY CHECKS
-- =====================================================================
