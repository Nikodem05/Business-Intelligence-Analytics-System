
-- SalesBI - Business Intelligence Analytics System

USE master;
GO

BEGIN
    CREATE DATABASE SalesBI
    COLLATE Polish_CI_AS;
END
GO

USE SalesBI;
GO

-- DIMENSION TABLES

-- DIM: Calendar
IF OBJECT_ID('dbo.dim_date', 'U') IS NOT NULL DROP TABLE dbo.dim_date;
CREATE TABLE dbo.dim_date (
    date_key INT NOT NULL PRIMARY KEY,
    full_date DATE NOT NULL,
    day_of_week TINYINT NOT NULL,
    day_name NVARCHAR(20) NOT NULL,
    day_of_month TINYINT NOT NULL,
    day_of_year SMALLINT NOT NULL,
    week_of_year TINYINT NOT NULL,
    month_number TINYINT NOT NULL,
    month_name NVARCHAR(20) NOT NULL,
    quarter_number TINYINT NOT NULL,
    quarter_name NCHAR(2) NOT NULL,
    year_number SMALLINT NOT NULL,
    is_weekend BIT NOT NULL DEFAULT 0,
    is_holiday BIT NOT NULL DEFAULT 0,
    fiscal_year SMALLINT NOT NULL,
    fiscal_quarter TINYINT NOT NULL
);
GO

-- DIM: Product
IF OBJECT_ID('dbo.dim_product', 'U') IS NOT NULL DROP TABLE dbo.dim_product;
CREATE TABLE dbo.dim_product (
    product_key INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
    product_id NVARCHAR(20) NOT NULL UNIQUE,
    product_name NVARCHAR(150) NOT NULL,
    category NVARCHAR(80) NOT NULL,
    subcategory NVARCHAR(80) NOT NULL,
    brand NVARCHAR(80) NOT NULL,
    unit_cost DECIMAL(10,2) NOT NULL,
    list_price DECIMAL(10,2) NOT NULL,
    is_active BIT NOT NULL DEFAULT 1,
    valid_from DATE NOT NULL DEFAULT GETDATE(),
    valid_to DATE NULL,
    is_current BIT NOT NULL DEFAULT 1
);
GO

-- DIM: Customer
IF OBJECT_ID('dbo.dim_customer', 'U') IS NOT NULL DROP TABLE dbo.dim_customer;
CREATE TABLE dbo.dim_customer (
    customer_key INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
    customer_id NVARCHAR(20) NOT NULL,
    full_name NVARCHAR(200) NOT NULL,
    segment NVARCHAR(50) NOT NULL,
    region NVARCHAR(80) NOT NULL,
    country NVARCHAR(80) NOT NULL DEFAULT 'Poland',
    city NVARCHAR(80) NOT NULL,
    acquisition_date DATE NULL,
    valid_from DATE NOT NULL DEFAULT GETDATE(),
    valid_to DATE NULL,
    is_current BIT NOT NULL DEFAULT 1
);
GO

-- DIM: Salesperson
IF OBJECT_ID('dbo.dim_salesperson', 'U') IS NOT NULL DROP TABLE dbo.dim_salesperson;
CREATE TABLE dbo.dim_salesperson (
    salesperson_key INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
    employee_id NVARCHAR(20) NOT NULL UNIQUE,
    full_name NVARCHAR(200) NOT NULL,
    department NVARCHAR(80) NOT NULL,
    region NVARCHAR(80) NOT NULL,
    hire_date DATE NOT NULL,
    is_active BIT NOT NULL DEFAULT 1
);
GO

-- Fact table

IF OBJECT_ID('dbo.fact_sales', 'U') IS NOT NULL DROP TABLE dbo.fact_sales;
CREATE TABLE dbo.fact_sales (
    sale_key BIGINT NOT NULL IDENTITY(1,1) PRIMARY KEY,
    date_key INT NOT NULL REFERENCES dbo.dim_date(date_key),
    product_key INT NOT NULL REFERENCES dbo.dim_product(product_key),
    customer_key INT NOT NULL REFERENCES dbo.dim_customer(customer_key),
    salesperson_key INT NOT NULL REFERENCES dbo.dim_salesperson(salesperson_key),
    order_id NVARCHAR(30) NOT NULL,
    order_line SMALLINT NOT NULL,
    quantity INT NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    discount_pct DECIMAL(5,4) NOT NULL DEFAULT 0,
    gross_revenue AS (quantity * unit_price) PERSISTED,
    discount_amount AS (quantity * unit_price * discount_pct) PERSISTED,
    net_revenue AS (quantity * unit_price * (1 - discount_pct)) PERSISTED,
    unit_cost  DECIMAL(10,2)  NOT NULL,
    total_cost AS (quantity * unit_cost)               PERSISTED,
    gross_profit AS (quantity * (unit_price - unit_cost)) PERSISTED,
    return_flag BIT NOT NULL DEFAULT 0,
    return_date_key INT NULL REFERENCES dbo.dim_date(date_key)
);
GO

-- INDEXES (performance for analytical queries)

CREATE NONCLUSTERED INDEX IX_fact_sales_date
    ON dbo.fact_sales(date_key) INCLUDE (net_revenue, gross_profit, quantity);

CREATE NONCLUSTERED INDEX IX_fact_sales_product
    ON dbo.fact_sales(product_key) INCLUDE (net_revenue, quantity);

CREATE NONCLUSTERED INDEX IX_fact_sales_customer
    ON dbo.fact_sales(customer_key) INCLUDE (net_revenue, gross_profit);

CREATE NONCLUSTERED INDEX IX_fact_sales_order
    ON dbo.fact_sales(order_id, order_line);
GO
