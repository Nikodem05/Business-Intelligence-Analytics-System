
-- SEED DATA: Calendar dimension + sample transactional data
USE SalesBI;
GO

-- 1. Populate dim_date (from 01-01-2022 to 31-12-2025)
SET NOCOUNT ON;

DECLARE @start DATE = '2022-01-01';
DECLARE @end   DATE = '2025-12-31';
DECLARE @d     DATE = @start;

WHILE @d <= @end
BEGIN
    INSERT INTO dbo.dim_date (
        date_key, full_date, day_of_week, day_name,
        day_of_month, day_of_year, week_of_year,
        month_number, month_name, quarter_number, quarter_name,
        year_number, is_weekend, is_holiday,
        fiscal_year, fiscal_quarter
    )
    VALUES (
        CONVERT(INT, FORMAT(@d, 'yyyyMMdd')),
        @d,
        DATEPART(WEEKDAY, @d),
        DATENAME(WEEKDAY, @d),
        DAY(@d),
        DATEPART(DAYOFYEAR, @d),
        DATEPART(WEEK, @d),
        MONTH(@d),
        DATENAME(MONTH, @d),
        DATEPART(QUARTER, @d),
        'Q' + CAST(DATEPART(QUARTER, @d) AS CHAR(1)),
        YEAR(@d),
        CASE 
            WHEN DATEPART(WEEKDAY, @d) IN (1,7) THEN 1 
            ELSE 0 
        END,
        0,  -- holidays can be updated separately
        CASE 
            WHEN MONTH(@d) >= 4 THEN YEAR(@d) 
            ELSE YEAR(@d) - 1 
        END,
        CASE -- naprawić to
            WHEN MONTH(@d) BETWEEN 4 AND 6  THEN 1
            WHEN MONTH(@d) BETWEEN 7 AND 9  THEN 2
            WHEN MONTH(@d) BETWEEN 10 AND 12 THEN 3
            ELSE 4
        END
    );
    SET @d = DATEADD(DAY, 1, @d);
END
GO

-- 2. Sample products

INSERT INTO dbo.dim_product (product_id, product_name, category, subcategory, brand, unit_cost, list_price)
VALUES
    ('PRD-001', 'UltraBook Pro 15', 'Electronics', 'Laptops', 'TechBrand', 2200.00, 3499.00),
    ('PRD-002', 'Wireless Headset X200', 'Electronics',  'Audio', 'SoundPlus', 120.00, 249.00),
    ('PRD-003', 'Ergonomic Office Chair', 'Furniture', 'Seating', 'ErgoDesk', 320.00, 699.00),
    ('PRD-004', 'Standing Desk 140cm', 'Furniture', 'Desks', 'ErgoDesk', 480.00, 999.00),
    ('PRD-005', 'Monitor 27" 4K', 'Electronics', 'Monitors', 'ViewMax',  600.00, 1199.00),
    ('PRD-006', 'USB-C Hub 10-in-1', 'Electronics', 'Accessories', 'TechBrand', 35.00, 89.00),
    ('PRD-007', 'Mechanical Keyboard TKL', 'Electronics', 'Peripherals', 'TypeMaster', 75.00, 169.00),
    ('PRD-008', 'Office Desk Lamp LED', 'Furniture', 'Lighting', 'BrightHome', 28.00, 69.00),
    ('PRD-009', 'SSD External 2TB', 'Electronics', 'Storage', 'DataVault', 80.00, 179.00),
    ('PRD-010', 'Webcam 4K Pro', 'Electronics', 'Video', 'ClearVision', 95.00, 219.00);
GO


-- 3. Sample customers

INSERT INTO dbo.dim_customer (customer_id, full_name, segment, region, country, city, acquisition_date)
VALUES
    ('CUS-001', 'Alfa Solutions Sp. z o.o.', 'Corporate', 'South', 'Poland', 'Kraków', '2021-03-15'),
    ('CUS-002', 'Beta Consulting S.A.', 'Corporate', 'Central', 'Poland', 'Warsaw', '2020-07-01'),
    ('CUS-003', 'Jan Kowalski', 'Consumer', 'South', 'Poland', 'Wrocław', '2022-01-10'),
    ('CUS-004', 'Maria Nowak', 'Consumer', 'North', 'Poland', 'Gdańsk', '2022-04-22'),
    ('CUS-005', 'Gamma Tech GmbH', 'Corporate', 'West', 'Germany','Berlin', '2021-11-05'),
    ('CUS-006', 'Delta Home Office', 'Home Office', 'Central', 'Poland', 'Łódź', '2023-01-18'),
    ('CUS-007', 'Epsilon Media Ltd', 'Corporate', 'East', 'Poland', 'Lublin', '2022-09-30'),
    ('CUS-008', 'Piotr Wiśniewski', 'Consumer', 'Central', 'Poland', 'Warsaw', '2023-06-14');
GO

-- 4. Smple salesperson

INSERT INTO dbo.dim_salesperson (employee_id, full_name, department, region, hire_date)
VALUES
    ('EMP-001', 'Anna Zielińska', 'Sales', 'Central', '2019-06-01'),
    ('EMP-002', 'Tomasz Dąbrowski', 'Sales', 'South', '2020-02-15'),
    ('EMP-003', 'Katarzyna Wójcik', 'Sales', 'North', '2021-09-01'),
    ('EMP-004', 'Marcin Lewandowski','Sales', 'West', '2022-03-10');
GO

-- 5. Sample fact data (300 rows via random generation)

DECLARE @i INT = 1;
DECLARE @order_counter INT = 1000;

WHILE @i <= 300
BEGIN
    DECLARE @rand_date DATE = DATEADD(DAY, ABS(CHECKSUM(NEWID())) % 1095, '2022-01-01');
    DECLARE @date_key_val INT = CONVERT(INT, FORMAT(@rand_date, 'yyyyMMdd'));
    DECLARE @prod_key INT = (ABS(CHECKSUM(NEWID())) % 10) + 1;
    DECLARE @cust_key INT = (ABS(CHECKSUM(NEWID())) % 8)  + 1;
    DECLARE @sp_key INT = (ABS(CHECKSUM(NEWID())) % 4)  + 1;
    DECLARE @qty INT = (ABS(CHECKSUM(NEWID())) % 10) + 1;
    DECLARE @disc DECIMAL(5,4) = ROUND((ABS(CHECKSUM(NEWID())) % 25) / 100.0, 2);
    DECLARE @price DECIMAL(10,2);
    DECLARE @cost DECIMAL(10,2);

    SELECT @price = list_price, @cost = unit_cost
    FROM dbo.dim_product WHERE product_key = @prod_key;

    IF @i % 5 = 0 SET @order_counter = @order_counter + 1;

    INSERT INTO dbo.fact_sales
        (date_key, product_key, customer_key, salesperson_key,
         order_id, order_line, quantity, unit_price, discount_pct, unit_cost)
    VALUES
        (@date_key_val, @prod_key, @cust_key, @sp_key,
         'ORD-' + RIGHT('0000' + CAST(@order_counter AS VARCHAR), 5),
         (@i % 5) + 1,
         @qty, @price, @disc, @cost);

    SET @i += 1;
END
GO
