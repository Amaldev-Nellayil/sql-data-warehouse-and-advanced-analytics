/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze → Silver)
===============================================================================
Database:  datawarehouse
Schema:    silver
Procedure: silver.load_silver()

Script Purpose:
    This stored procedure performs ETL operations to transform, clean,
    standardize, and load data from the Bronze layer into the Silver layer.

Actions Performed:
    - Truncates existing Silver tables before each full refresh to prevent
      duplicate records from repeated loads.
    - Uses INSERT INTO ... SELECT to transform and load data from Bronze.
    - Cleans and standardizes customer names, gender, marital status,
      product categories, product lines, and country names.
    - Removes duplicate CRM customer records using ROW_NUMBER(),
      retaining the most recent record by creation date.
    - Handles missing product costs and derives product end dates using
      LEAD() to establish product validity periods.
    - Converts numeric sales dates into PostgreSQL DATE values and applies
      correction rules to sales and pricing data.
    - Standardizes ERP customer identifiers and removes invalid future
      birthdates.
    - Loads ERP product-category reference data into the Silver layer.
    - Displays progress messages using RAISE NOTICE.
    - Measures individual table-loading durations and overall ETL duration
      using clock_timestamp().
    - Handles errors by reporting SQLERRM and SQLSTATE and re-raising
      the original exception.

Parameters:
    None. The procedure accepts no parameters and returns no values.

Execution:
    1. Connect to the 'datawarehouse' PostgreSQL database.
    2. Ensure Bronze data is loaded and all Silver tables exist.
    3. Execute this script to create or replace the procedure.
    4. Run the procedure separately using:

       CALL silver.load_silver();

WARNING:
    This procedure truncates and reloads all six Silver tables.
    Previously loaded Silver data will be replaced.

    Data corrections follow the transformation rules defined in this
    tutorial and should be validated against business requirements.
===============================================================================
*/

create or replace procedure silver.load_silver()
language plpgsql
as $$
declare
	start_time timestamp;
	end_time timestamp;
	batch_start_time timestamp;
	batch_end_time timestamp;
begin
	batch_start_time:= clock_timestamp();
	raise notice '====================================';
	raise notice 'Loading Silver Layer';
	raise notice '====================================';
	
	raise notice '------------------------------------';
	raise notice 'Loading CRM Tables';
	raise notice '------------------------------------';
	-- CRM cust_info
	start_time:= clock_timestamp();
	raise notice 'Truncating table: crm_cust_info';
	truncate table silver.crm_cust_info;
	raise notice 'Inserting data into crm_cust_info';
	insert into silver.crm_cust_info (
	cst_id,
	cst_key,
	cst_firstname,
	cst_lastname,
	cst_marital_status,
	cst_gndr,
	cst_create_date
	)
	select
	cst_id,
	cst_key,
	trim(cst_firstname) as cst_firstname,
	trim(cst_lastname) as cst_lastname,
	case 
		when upper(trim(cst_marital_status)) = 'M'then 'Married'
		when upper(trim(cst_marital_status)) = 'S' then 'Single'
		else 'n/a'
	end as cst_marital_status,
	case 
		when upper(trim(cst_gndr)) = 'M'then 'Male'
		when upper(trim(cst_gndr)) = 'F' then 'Female'
		else 'n/a'
	end as cst_gndr,
	cst_create_date
	from
	(
	select
	*,
	row_number() over (partition by cst_id order by cst_create_date desc nulls last) as flag_last
	from bronze.crm_cust_info
	where cst_id is not null 
	) t
	where flag_last = 1;
	
	end_time:=clock_timestamp();
	raise notice 'Load duration: % seconds',
		extract(epoch from(end_time - start_time));
		
	raise notice '------------------------------------';
	
	-- CRM prd_info
	start_time:= clock_timestamp();
	raise notice 'Truncating table: crm_prd_info';
	truncate table silver.crm_prd_info;
	raise notice 'Inserting data into crm_prd_info';
	insert into silver.crm_prd_info(
	prd_id,
	cat_id,
	prd_key,
	prd_nm,
	prd_cost,
	prd_line,
	prd_start_dt,
	prd_end_dt
	)
	select 
	prd_id,
	replace(substr(prd_key,1,5),'-','_') as cat_id,
	substr(prd_key,7,length(prd_key)) as prd_key,
	prd_nm,
	coalesce(prd_cost,0) as prd_cost,
	case upper(trim(prd_line))
		when 'M' then 'Mountain'
		when 'R' then 'Road'
		when 'S' then 'Other Sales'
		when 'T' then 'Touring'
		else 'n/a'
	end as prd_line,
	prd_start_dt,
	lead(prd_start_dt) over(partition by prd_key order by prd_start_dt asc)-1 as prd_end_dt
	from bronze.crm_prd_info;
	
	end_time:=clock_timestamp();
	raise notice 'Load duration: % seconds',
		extract(epoch from(end_time - start_time));
	
	raise notice '------------------------------------';
	
	-- CRM sales_details
	start_time:= clock_timestamp();
	raise notice 'Truncating table: crm_sales_details';
	truncate table silver.crm_sales_details;
	raise notice 'Inserting data into crm_sales_details';
	insert into silver.crm_sales_details(
	sls_ord_num,
	sls_prd_key,
	sls_cust_id,
	sls_order_dt,
	sls_ship_dt,
	sls_due_dt,
	sls_sales,
	sls_quantity,
	sls_price
	)
	select
	sls_ord_num,
	sls_prd_key,
	sls_cust_id,
	case
	    when sls_order_dt <= 0 or length(sls_order_dt::text) != 8
	    then null
	    else to_date(sls_order_dt::text, 'yyyymmdd')
	end as sls_order_dt,
	case
	    when sls_ship_dt <= 0 or length(sls_ship_dt::text) != 8
	    then null
	    else to_date(sls_ship_dt::text, 'yyyymmdd')
	end as sls_ship_dt,
	case
	    when sls_due_dt <= 0 or length(sls_due_dt::text) != 8
	    then null
	    else to_date(sls_due_dt::text, 'yyyymmdd')
	end as sls_due_dt,
	case 
		when sls_sales<=0 or sls_sales is null or sls_sales != abs(sls_quantity*sls_price) then abs(sls_quantity*sls_price)
		else sls_sales
	end as sls_sales,
	sls_quantity,
	case 
		when sls_price<=0 or sls_price is null then abs(sls_sales/nullif(sls_quantity,0))
		else sls_price
	end
	as sls_price
	from bronze.crm_sales_details;
	
	end_time:=clock_timestamp();
	raise notice 'Load duration: % seconds',
		extract(epoch from(end_time - start_time));
	
	raise notice '------------------------------------';
	raise notice 'Loading ERP Tables';
	raise notice '------------------------------------';
	
	-- ERP cust_az12
	start_time:= clock_timestamp();
	raise notice 'Truncating table: erp_cust_az12';
	truncate table silver.erp_cust_az12;
	raise notice 'Inserting data into erp_cust_az12';
	insert into silver.erp_cust_az12(
	CID,
	BDATE,
	GEN
	)
	select
	right(cid,10) as CID,
	case 
		when bdate > current_date then null
		else bdate
	end
	as BDATE,
	case 
		when upper(trim(GEN)) in ('F','FEMALE') then 'Female'
		when upper(trim(GEN)) in ('M','MALE') then 'Male'
		else 'n/a'
	end as GEN
	from bronze.erp_cust_az12;
	
	end_time:=clock_timestamp();
	raise notice 'Load duration: % seconds',
		extract(epoch from(end_time - start_time));
	
	raise notice '------------------------------------';
	
	-- ERP loc_a101
	start_time:= clock_timestamp();
	raise notice 'Truncating table: erp_loc_a101';
	truncate table silver.erp_loc_a101;
	raise notice 'Inserting data into erp_loc_a101';
	insert into silver.erp_loc_a101(
	CID,
	CNTRY
	)
	select
	replace(cid,'-','') as cid,
	case 
		when upper(trim(cntry)) in ('US','USA') then 'United States'
		when upper(trim(cntry)) ='DE' then 'Germany'
		when cntry is null or trim(cntry) = '' then 'n/a'
		else cntry
	end as cntry
	from bronze.erp_loc_a101;
	
	end_time:=clock_timestamp();
	raise notice 'Load duration: % seconds',
		extract(epoch from(end_time - start_time));
	
	raise notice '------------------------------------';
	
	-- ERP px_cat_g1v2
	start_time:= clock_timestamp();
	raise notice 'Truncating table: erp_px_cat_g1v2';
	truncate table silver.erp_px_cat_g1v2;
	raise notice 'Inserting data into erp_px_cat_g1v2';
	insert into silver.erp_px_cat_g1v2(
	ID,
	CAT,
	SUBCAT,
	MAINTENANCE
	)
	select
	ID,
	CAT,
	SUBCAT,
	MAINTENANCE
	from bronze.erp_px_cat_g1v2;
	
	end_time:=clock_timestamp();
	raise notice 'Load duration: % seconds',
		extract(epoch from(end_time - start_time));
		
	batch_end_time:= clock_timestamp();
	
	raise notice '====================================';
	raise notice 'Loading Bronze layer is completed';
	raise notice 'Total load duration: % seconds',
		extract(epoch from(batch_end_time - batch_start_time));
	raise notice '===================================='; 

	exception
		when others then 
			raise notice '====================================';
			raise notice 'Error occurred during Silver Loading';
			raise notice 'Error Message: %', sqlerrm;
			raise notice 'Error Code: %', sqlstate;
			raise notice '===================================='; 
		
	raise;
	
end;
$$;
