
-- STORED PROCEDURES - SalesBI

USE SalesBI;
GO


-- PROC 1: GetSalesSummary - Returns a KPI summary for a given date range

CREATE OR ALTER PROCEDURE dbo.GetSalesSummary
    @date_from DATE,
    @date_to DATE,
    @region NVARCHAR(80) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Input validation
    IF @date_from > @date_to
    BEGIN
        RAISERROR('date_from cannot be later than date_to.', 16, 1);
        RETURN;
    END

    SELECT
        COUNT(DISTINCT f.order_id) AS total_orders,
        COUNT(DISTINCT f.customer_key) AS total_customers,
        SUM(f.quantity) AS units_sold,
        ROUND(SUM(f.gross_revenue), 2) AS gross_revenue,
        ROUND(SUM(f.discount_amount), 2) AS total_discounts,
        ROUND(SUM(f.net_revenue), 2) AS net_revenue,
        ROUND(SUM(f.total_cost), 2) AS total_cost,
        ROUND(SUM(f.gross_profit), 2) AS gross_profit,
        ROUND(SUM(f.gross_profit) / NULLIF(SUM(f.net_revenue), 0) * 100, 2) AS profit_margin_pct,
        ROUND(SUM(f.net_revenue) / NULLIF(COUNT(DISTINCT f.order_id), 0), 2) AS avg_order_value,
        SUM(CASE 
               WHEN f.return_flag = 1 THEN 1 
               ELSE 0 
            END) AS returns,
        ROUND(SUM(CASE 
                    WHEN f.return_flag = 1 THEN 1.0 
                    ELSE 0 
                  END) / NULLIF(COUNT(f.sale_key), 0) * 100, 2) AS return_rate_pct
    FROM dbo.fact_sales f
    JOIN dbo.dim_date d  ON f.date_key = d.date_key
    JOIN dbo.dim_customer c ON f.customer_key  = c.customer_key
    WHERE d.full_date BETWEEN @date_from AND @date_to AND (@region IS NULL OR c.region = @region);
END
GO


-- PROC 2: TopProducts - Returns top N products by revenue for a given period

CREATE OR ALTER PROCEDURE dbo.TopProducts
    @date_from DATE,
    @date_to DATE,
    @top_n INT = 10
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@top_n)
        p.product_id,
        p.product_name,
        p.category,
        p.subcategory,
        COUNT(DISTINCT f.order_id) AS order_count,
        SUM(f.quantity) AS units_sold,
        ROUND(SUM(f.net_revenue),   2) AS net_revenue,
        ROUND(SUM(f.gross_profit),  2) AS gross_profit,
        ROUND(AVG(f.discount_pct) * 100, 2) AS avg_discount_pct,
        ROUND(SUM(f.gross_profit) / NULLIF(SUM(f.net_revenue), 0) * 100, 2) AS margin_pct,
        RANK() OVER (ORDER BY SUM(f.net_revenue) DESC) AS revenue_rank
    FROM dbo.fact_sales f
    JOIN dbo.dim_date d ON f.date_key    = d.date_key
    JOIN dbo.dim_product p ON f.product_key = p.product_key
    WHERE d.full_date BETWEEN @date_from AND @date_to
      AND p.is_current = 1
    GROUP BY p.product_id, p.product_name, p.category, p.subcategory
    ORDER BY net_revenue DESC;
END
GO

-- PROC 3: CustomerLifetimeValue - Calculates CLV metrics per customer

CREATE OR ALTER PROCEDURE dbo.CustomerLifetimeValue
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH clv AS (
        SELECT
            c.customer_key,
            c.full_name,
            c.segment,
            c.city,
            c.acquisition_date,
            MIN(d.full_date) AS first_purchase,
            MAX(d.full_date) AS last_purchase,
            DATEDIFF(DAY, MIN(d.full_date), MAX(d.full_date)) AS customer_lifespan_days,
            COUNT(DISTINCT f.order_id) AS total_orders,
            SUM(f.net_revenue) AS total_revenue,
            SUM(f.gross_profit) AS total_profit
        FROM dbo.fact_sales  f
        JOIN dbo.dim_customer c ON f.customer_key = c.customer_key
        JOIN dbo.dim_date d ON f.date_key = d.date_key
        WHERE c.is_current = 1
        GROUP BY c.customer_key, c.full_name, c.segment, c.city, c.acquisition_date
    )
    SELECT
        customer_key,
        full_name,
        segment,
        city,
        acquisition_date,
        first_purchase,
        last_purchase,
        customer_lifespan_days,
        total_orders,
        ROUND(total_revenue, 2) AS total_revenue,
        ROUND(total_profit,  2) AS total_profit,
        ROUND(total_revenue / NULLIF(total_orders, 0), 2) AS avg_purchase_value,
        ROUND(total_orders * 1.0 / NULLIF(customer_lifespan_days / 30.0, 0), 2) AS purchase_frequency_monthly
    FROM clv
    ORDER BY total_revenue DESC;
END
GO
