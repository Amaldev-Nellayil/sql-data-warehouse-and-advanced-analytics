
# Data Dictionary for Gold Layer

## Overview

The Gold Layer is the business-level representation of the data warehouse, designed to support analytical reporting, business intelligence, and data-driven decision-making.

It integrates cleansed and standardized CRM and ERP data from the Silver Layer into a **star schema**, consisting of two dimension views and one fact view.

The Gold Layer contains:

- **gold.dim_customers:** Customer information enriched with demographic and geographical attributes.
- **gold.dim_products:** Product information enriched with category, subcategory, and maintenance details.
- **gold.fact_sales:** Transactional sales information linked to customer and product dimensions.

All three objects are implemented as PostgreSQL views rather than physical tables.

---

## 1. gold.dim_customers

**Purpose:** Provides a consolidated customer dimension by integrating CRM customer information with ERP demographic and location data.

**Source tables:**

- `silver.crm_cust_info`
- `silver.erp_cust_az12`
- `silver.erp_loc_a101`

**Columns:**

| Column Name | Data Type | Description |
|---|---|---|
| customer_key | BIGINT | Surrogate customer key generated using `ROW_NUMBER()` to identify customer records within the view. |
| customer_id | INTEGER | Unique numerical customer identifier originating from the CRM system. |
| customer_number | VARCHAR(50) | Alphanumeric customer identifier used to integrate CRM and ERP customer records. |
| first_name | VARCHAR(50) | Customer's first name, standardized in the Silver Layer. |
| last_name | VARCHAR(50) | Customer's last name, standardized in the Silver Layer. |
| cntry | VARCHAR(50) | Customer's country, obtained from ERP location information. |
| marital_status | VARCHAR(50) | Standardized marital status, such as Married, Single, or n/a. |
| gender | VARCHAR(50) | Customer's gender, prioritizing CRM information and using ERP information when CRM gender is n/a. |
| birthdate | DATE | Customer's date of birth, sourced from ERP demographic information. |
| create_date | DATE | Date when the customer record was created in the CRM system. |

**Key Relationships:**

- `customer_key` is the generated surrogate key used to link customers with `gold.fact_sales`.
- `customer_id` corresponds to `sls_cust_id` in Silver sales records.
- `customer_number` corresponds to customer identifiers in the ERP datasets.

---

## 2. gold.dim_products

**Purpose:** Provides descriptive product information enriched with product categories, classifications, costs, and maintenance requirements.

**Source tables:**

- `silver.crm_prd_info`
- `silver.erp_px_cat_g1v2`

**Columns:**

| Column Name | Data Type | Description |
|---|---|---|
| product_key | BIGINT | Surrogate product key generated using `ROW_NUMBER()` to identify product records within the view. |
| product_id | INTEGER | Numerical identifier assigned to the product record in the CRM system. |
| product_number | VARCHAR(50) | Alphanumeric product identifier used for matching products with sales records. |
| product_name | VARCHAR(50) | Descriptive product name, including information such as type, size, or color. |
| category_id | VARCHAR(50) | Category identifier derived from the CRM product key and used to integrate ERP category information. |
| category | VARCHAR(50) | High-level product classification, such as Bikes or Components. |
| subcategory | VARCHAR(50) | More detailed product classification within the main category. |
| maintenance | VARCHAR(50) | Indicates whether maintenance is required for the product, based on ERP category information. |
| cost | INTEGER | Product cost recorded in the CRM product dataset, with missing values replaced during Silver transformation. |
| product_line | VARCHAR(50) | Standardized product-line classification, such as Mountain, Road, Touring, or Other Sales. |
| start_date | DATE | Date on which the product record became effective. |

**Key Relationships:**

- `product_key` is the generated surrogate key used to link products with `gold.fact_sales`.
- `product_number` corresponds to `sls_prd_key` in Silver sales records.
- `category_id` is used to integrate ERP product-category attributes.

**Business Rule:**

Only product records where `prd_end_dt IS NULL` are included in this view, representing the latest active product versions according to the Silver-layer validity logic.

---

## 3. gold.fact_sales

**Purpose:** Provides transactional sales information for business analysis, reporting, and calculation of sales performance metrics.

**Source tables and views:**

- `silver.crm_sales_details`
- `gold.dim_customers`
- `gold.dim_products`

**Columns:**

| Column Name | Data Type | Description |
|---|---|---|
| order_number | VARCHAR(50) | Alphanumeric sales order identifier. An order may contain multiple line items. |
| product_key | BIGINT | Surrogate key referencing the corresponding product record in `gold.dim_products`. |
| customer_key | BIGINT | Surrogate key referencing the corresponding customer record in `gold.dim_customers`. |
| order_date | DATE | Date when the sales order was placed. |
| shipping_date | DATE | Date when the order was shipped. |
| due_date | DATE | Due date associated with the order, used for delivery and scheduling analysis. |
| sales_amount | INTEGER | Monetary value of the sales transaction line, following Silver-layer correction rules. |
| quantity | INTEGER | Number of product units associated with the transaction line. |
| price | INTEGER | Unit price of the product associated with the transaction line. |

**Key Relationships:**

- `customer_key` links sales records to `gold.dim_customers`.
- `product_key` links sales records to `gold.dim_products`.
- These keys are obtained by joining Silver sales records with the corresponding Gold dimensions.

**Fact Table Grain:**

Each record represents a sales transaction line from `silver.crm_sales_details`. Multiple records may share the same order number.

**Business Measures:**

- **Sales Amount:** Revenue associated with a sales transaction line.
- **Quantity:** Number of product units sold.
- **Price:** Unit selling price.

These measures support calculations such as total sales, sales volume, average selling price, and sales performance by product, customer, or date.

---

## 4. Gold Layer Data Model

The Gold Layer follows a **star schema**, with `gold.fact_sales` as the central fact view and two descriptive dimension views.

| Dimension View | Relationship | Fact View |
|---|---|---|
| gold.dim_customers | customer_key | gold.fact_sales |
| gold.dim_products | product_key | gold.fact_sales |

**Relationship Cardinality:**

- One customer can be associated with multiple sales records.
- One product can be associated with multiple sales records.
- Each sales record is intended to reference one customer and one product.

These are logical relationships defined by the data model, not database-enforced foreign-key constraints.

---

## 5. Implementation Notes

- The Gold Layer is implemented using PostgreSQL views.
- Data is integrated from the Silver Layer through SQL joins and transformations.
- Column aliases provide business-friendly names for analytical consumption.
- Customer gender values are consolidated from CRM and ERP sources.
- Product categories and classifications are enriched using ERP reference data.
- Surrogate keys are generated dynamically using `ROW_NUMBER()` and may change when the underlying data changes.
- The use of `LEFT JOIN` allows fact records to remain present even when matching dimension records are unavailable, resulting in NULL surrogate keys.
- Because the Gold objects are standard views, their results reflect the underlying Silver data when queried.

---

## 6. Intended Analytical Applications

The Gold Layer supports:

- Customer segmentation and demographic analysis.
- Product category and product-line performance analysis.
- Sales trends across different reporting periods.
- Revenue and sales-volume analysis.
- Geographical sales analysis.
- Business intelligence dashboards and management reporting.

