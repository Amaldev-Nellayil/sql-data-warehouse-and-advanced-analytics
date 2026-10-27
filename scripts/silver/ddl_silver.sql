
/*
===============================================================================
DDL Script: Create Silver Tables
===============================================================================
Database: datawarehouse
Schema:   silver

Script Purpose:
    This script creates the six tables in the Silver layer of the data warehouse.
    Existing tables are dropped and recreated to define the Silver-layer schema.

    Key differences from the Bronze layer:
    - Adds dwh_create_date to all six tables as a TIMESTAMP column with
      DEFAULT CURRENT_TIMESTAMP to record when rows are inserted into Silver.
    - Converts sales date columns (sls_order_dt, sls_ship_dt, sls_due_dt)
      from INTEGER in Bronze to DATE in Silver for analytical use.
    - Adds cat_id to crm_prd_info to store the product category identifier
      derived from the source product key during transformation.
    - Preserves suitable data types for the remaining columns.

    This script defines table structures only. Data cleaning, standardization,
    and loading are performed separately by silver.load_silver().

Execution:
    Run while connected to the 'datawarehouse' PostgreSQL database.
    Ensure the 'silver' schema already exists.

WARNING:
    This script drops and recreates the Silver tables.
    Any existing data in these tables will be permanently removed.
===============================================================================
*/



drop table if exists silver.crm_cust_info;
create table silver.crm_cust_info (
cst_id int,
cst_key varchar(50),
cst_firstname varchar(50),
cst_lastname varchar(50),
cst_marital_status varchar(50),
cst_gndr varchar(50),
cst_create_date date,
dwh_create_date timestamp default current_timestamp
);

drop table if exists silver.crm_prd_info;
create table silver.crm_prd_info(
prd_id int,
cat_id varchar(50),
prd_key varchar(50),
prd_nm varchar(50),
prd_cost int,
prd_line varchar(50),
prd_start_dt date,
prd_end_dt date,
dwh_create_date timestamp default current_timestamp
);

drop table if exists silver.crm_sales_details;
create table silver.crm_sales_details(
sls_ord_num varchar(50),
sls_prd_key varchar(50),
sls_cust_id int,
sls_order_dt date,
sls_ship_dt date,
sls_due_dt date,
sls_sales int,
sls_quantity int,
sls_price int,
dwh_create_date timestamp default current_timestamp
);

drop table if exists silver.erp_cust_az12;
create table silver.erp_cust_az12(
CID varchar(50),
BDATE date,
GEN varchar(50),
dwh_create_date timestamp default current_timestamp
);

drop table if exists silver.erp_loc_a101;
create table silver.erp_loc_a101(
CID varchar(50),
CNTRY varchar(50),
dwh_create_date timestamp default current_timestamp
);

drop table if exists silver.erp_px_cat_g1v2;
create table silver.erp_px_cat_g1v2(
ID varchar(50),
CAT varchar(50),
SUBCAT varchar(50),
MAINTENANCE varchar(50),
dwh_create_date timestamp default current_timestamp
);
