/*
===============================================================================
Stored Procedure: Load Bronze Layer (Source → Bronze)
===============================================================================
Database: datawarehouse
Schema:   bronze
Procedure: bronze.load_bronze()

Purpose:
    This stored procedure loads raw CRM and ERP data from CSV files
    into the Bronze layer of the data warehouse.

    It performs the following operations:
    - Truncates existing Bronze tables before loading fresh data,
      preventing duplicate records from repeated full loads.
    - Uses PostgreSQL's COPY command to import data from CSV files.
    - Displays progress messages for each table-loading operation.
    - Measures and displays the loading duration of each table.
    - Measures and displays the overall Bronze-layer loading duration.
    - Handles errors by displaying the error message and SQLSTATE code,
      then re-raising the error.

Parameters:
    None. The procedure does not accept parameters or return values.

Execution:
    1. Connect to the 'datawarehouse' database.
    2. Replace all six placeholder paths with actual CSV locations.
    3. Execute this script to create the stored procedure.
    4. Run CALL bronze.load_bronze(); to load the data.

    PostgreSQL's server process must have permission to
    access the specified CSV files.

Usage:
    CALL bronze.load_bronze();

WARNING:
    This procedure replaces existing Bronze-layer data on every run.
===============================================================================
*/



create or replace procedure bronze.load_bronze()
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
	raise notice 'Loading Bronze Layer';
	raise notice '====================================';
	
	raise notice '------------------------------------';
	raise notice 'Loading CRM Tables';
	raise notice '------------------------------------';
	
	-- CRM cust_info
	start_time:= clock_timestamp();
	raise notice 'Truncating table: crm_cust_info';
	truncate table bronze.crm_cust_info;
	raise notice 'Inserting data into crm_cust_info';
	copy bronze.crm_cust_info
	from '/path/to/cust_info.csv'
	with (
		format csv,
		header true,
		delimiter ','
	);
	end_time:=clock_timestamp();
	raise notice 'Load duration: % seconds',
		extract(epoch from(end_time - start_time));
		
	raise notice '------------------------------------';
	
	-- CRM prd_info
	start_time:= clock_timestamp();
	raise notice 'Truncating table: crm_prd_info';
	truncate table bronze.crm_prd_info;
	raise notice 'Inserting data into crm_prd_info';
	copy bronze.crm_prd_info
	from '/path/to/prd_info.csv'
	with (
		format csv,
		header true,
		delimiter ','
	);
	end_time:=clock_timestamp();
	raise notice 'Load duration: % seconds',
		extract(epoch from(end_time - start_time));
	
	raise notice '------------------------------------';
	
	-- CRM sales_details
	start_time:= clock_timestamp();
	raise notice 'Truncating table: crm_sales_details';
	truncate table bronze.crm_sales_details;
	raise notice 'Inserting data into crm_sales_details';
	copy bronze.crm_sales_details
	from '/path/to/sales_details.csv'
	with (
		format csv,
		header true,
		delimiter ','
	);
	end_time:=clock_timestamp();
	raise notice 'Load duration: % seconds',
		extract(epoch from(end_time - start_time));
	
	raise notice '------------------------------------';
	raise notice 'Loading ERP Tables';
	raise notice '------------------------------------';
	
	-- ERP cust_az12
	start_time:= clock_timestamp();
	raise notice 'Truncating table: erp_cust_az12';
	truncate table bronze.erp_cust_az12;
	raise notice 'Inserting data into erp_cust_az12';
	copy bronze.erp_cust_az12
	from '/path/to/CUST_AZ12.csv'
	with (
		format csv,
		header true,
		delimiter ','
	);
	end_time:=clock_timestamp();
	raise notice 'Load duration: % seconds',
		extract(epoch from(end_time - start_time));
	
	raise notice '------------------------------------';
	
	-- ERP loc_a101
	start_time:= clock_timestamp();
	raise notice 'Truncating table: erp_loc_a101';
	truncate table bronze.erp_loc_a101;
	raise notice 'Inserting data into erp_loc_a101';
	copy bronze.erp_loc_a101
	from '/path/to/LOC_A101.csv'
	with (
		format csv,
		header true,
		delimiter ','
	);
	end_time:=clock_timestamp();
	raise notice 'Load duration: % seconds',
		extract(epoch from(end_time - start_time));
	
	raise notice '------------------------------------';
	
	-- ERP px_cat_g1v2
	start_time:= clock_timestamp();
	raise notice 'Truncating table: erp_px_cat_g1v2';
	truncate table bronze.erp_px_cat_g1v2;
	raise notice 'Inserting data into erp_px_cat_g1v2';
	copy bronze.erp_px_cat_g1v2
	from '/path/to/PX_CAT_G1V2.csv'
	with (
		format csv,
		header true,
		delimiter ','
	);
	end_time:=clock_timestamp();
	raise notice 'Load duration: % seconds',
		extract(epoch from(end_time - start_time));
	
	raise notice '------------------------------------';
	
	batch_end_time:= clock_timestamp();
	
	raise notice '====================================';
	raise notice 'Loading Bronze layer is completed';
	raise notice 'Total load duration: % seconds',
		extract(epoch from(batch_end_time - batch_start_time));
	raise notice '===================================='; 
	
	exception
		when others then 
			raise notice '====================================';
			raise notice 'Error occurred during Bronze Loading';
			raise notice 'Error Message: %', sqlerrm;
			raise notice 'Error Code: %', sqlstate;
			raise notice '===================================='; 
		
	raise;
	
	
end;
$$;

