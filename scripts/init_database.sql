-- =====================================================
-- Initialize Data Warehouse (PostgreSQL)
-- =====================================================

-- STEP 1: Run while connected to the 'postgres'
-- database. Skip if 'datawarehouse' already exists.

CREATE DATABASE datawarehouse;

-- STEP 2: Connect to 'datawarehouse' in DBeaver.
-- Then execute the following statements to set up three schemas within the database

CREATE SCHEMA IF NOT EXISTS bronze;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;
  
