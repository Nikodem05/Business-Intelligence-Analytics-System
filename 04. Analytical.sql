
-- ANALYTICAL QUERIES - SalesBI

USE SalesBI;
GO


-- Revenue YTD vs previous year

;WITH monthly_revenue AS (
    SELECT
        d.year_number,
        d.month_number,
        d.month_name,
        SUM(f.net_revenue) AS monthly_revenue,
        SUM(f.gross_profit) AS monthly_profit
    FROM dbo.fact_sales f
    LEFT JOIN dbo.dim_date d ON f.date_key = d.date_key
    WHERE d.is_weekend = 0
    GROUP BY d.year_number, d.month_number, d.month_name
)
SELECT
    year_number,
    month_name,
    monthly_revenue,
    monthly_profit,
    ROUND(monthly_profit / NULLIF(monthly_revenue, 0) * 100, 2) AS profit_margin_pct,
    LAG(monthly_revenue) OVER (PARTITION BY month_number ORDER BY year_number) AS prev_year_revenue,
    ROUND((monthly_revenue - LAG(monthly_revenue) OVER (PARTITION BY month_number ORDER BY year_number))
    / NULLIF(LAG(monthly_revenue) OVER (PARTITION BY month_number ORDER BY year_number), 0) * 100, 2) AS yoy_growth_pct,
    SUM(monthly_revenue) OVER (PARTITION BY year_number ORDER BY month_number ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS ytd_revenue
FROM monthly_revenue
ORDER BY year_number, month_number;
GO


-- Product Category ABC Analysis

;WITH category_sales AS (
    SELECT
        p.category,
        p.subcategory,
        COUNT(DISTINCT f.order_id) AS order_count,
        SUM(f.quantity) AS units_sold,
        SUM(f.net_revenue) AS total_revenue,
        SUM(f.gross_profit) AS total_profit,
        ROUND(AVG(f.discount_pct) * 100, 2) AS avg_discount_pct
    FROM dbo.fact_sales f
    LEFT JOIN dbo.dim_product p ON f.product_key = p.product_key
    WHERE p.is_current = 1
    GROUP BY p.category, p.subcategory
),
ranked AS (
    SELECT *,
        SUM(total_revenue) OVER () AS grand_total,
        SUM(total_revenue) OVER (ORDER BY total_revenue DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total
    FROM category_sales
)
SELECT
    category,
    subcategory,
    order_count,
    units_sold,
    ROUND(total_revenue, 2) AS total_revenue,
    ROUND(total_profit, 2) AS total_profit,
    avg_discount_pct,
    ROUND(total_revenue / grand_total * 100, 2) AS revenue_share_pct,
    ROUND(running_total / grand_total * 100, 2) AS cumulative_pct,
    CASE
        WHEN running_total / grand_total <= 0.80 THEN 'A'
        WHEN running_total / grand_total <= 0.95 THEN 'B'
        ELSE 'C'
    END AS abc_class
FROM ranked
ORDER BY total_revenue DESC;
GO


-- Salesperson Performance Scorecard

;WITH sp_metrics AS (
    SELECT
        sp.full_name AS salesperson,
        sp.region,
        COUNT(DISTINCT f.order_id) AS orders_handled,
        COUNT(DISTINCT f.customer_key) AS unique_customers,
        SUM(f.quantity) AS total_units,
        SUM(f.net_revenue) AS total_revenue,
        SUM(f.gross_profit)  AS total_profit,
        AVG(f.net_revenue) AS avg_order_value,
        MAX(f.net_revenue) AS max_single_sale,
        SUM(CASE WHEN f.return_flag = 1 THEN 1 ELSE 0 END) AS returns
    FROM dbo.fact_sales f
    JOIN dbo.dim_salesperson sp ON f.salesperson_key = sp.salesperson_key
    WHERE sp.is_active = 1
    GROUP BY sp.full_name, sp.region
)
SELECT
    salesperson,
    region,
    orders_handled,
    unique_customers,
    total_units,
    ROUND(total_revenue, 2) AS total_revenue,
    ROUND(total_profit, 2) AS total_profit,
    ROUND(total_profit / NULLIF(total_revenue, 0) * 100, 2) AS margin_pct,
    ROUND(avg_order_value, 2) AS avg_order_value,
    ROUND(max_single_sale, 2) AS max_single_sale,
    returns,
    ROUND(returns * 1.0 / NULLIF(orders_handled, 0) * 100, 2) AS return_rate_pct,
    RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank,
    RANK() OVER (ORDER BY total_profit  DESC) AS profit_rank,
    PERCENT_RANK() OVER (ORDER BY total_revenue) AS revenue_percentile
FROM sp_metrics
ORDER BY total_revenue DESC;
GO


-- Customer Segmentation 

;WITH rfm_base AS (
    SELECT
        f.customer_key,
        c.full_name,
        c.segment,
        c.city,
        MAX(d.full_date) AS last_purchase_date,
        COUNT(DISTINCT f.order_id) AS frequency,
        SUM(f.net_revenue) AS monetary
    FROM dbo.fact_sales f
    JOIN dbo.dim_customer c ON f.customer_key  = c.customer_key
    JOIN dbo.dim_date d ON f.date_key = d.date_key
    WHERE c.is_current = 1
    GROUP BY f.customer_key, c.full_name, c.segment, c.city
),
rfm_scored AS (
    SELECT *,
        DATEDIFF(DAY, last_purchase_date, CAST(GETDATE() AS DATE)) AS recency_days,
        NTILE(5) OVER (ORDER BY DATEDIFF(DAY, last_purchase_date, GETDATE()) ASC)  AS r_score,
        NTILE(5) OVER (ORDER BY frequency DESC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary DESC) AS m_score
    FROM rfm_base
)
SELECT
    customer_key,
    full_name,
    segment,
    city,
    last_purchase_date,
    recency_days,
    frequency,
    ROUND(monetary, 2) AS monetary,
    r_score, 
    f_score, 
    m_score,
    (r_score + f_score + m_score) AS rfm_total_score,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score <= 2 THEN 'Recent Customers'
        WHEN r_score <= 2 AND f_score >= 4 THEN 'At Risk'
        WHEN r_score <= 2 AND f_score <= 2 THEN 'Lost'
        ELSE 'Potentials'
    END AS rfm_segment
FROM rfm_scored
ORDER BY rfm_total_score DESC;
GO


-- Quarterly Revenue PIVOT by Category

SELECT *
FROM (
    SELECT
        p.category,
        d.year_number,
        d.quarter_name,
        CAST(d.year_number AS NVARCHAR(4)) + '-' + d.quarter_name AS period,
        f.net_revenue
    FROM dbo.fact_sales f
    JOIN dbo.dim_date d ON f.date_key = d.date_key
    JOIN dbo.dim_product p ON f.product_key = p.product_key
) AS src
PIVOT (
    SUM(net_revenue)
    FOR period IN (
        [2022-Q1],[2022-Q2],[2022-Q3],[2022-Q4],
        [2023-Q1],[2023-Q2],[2023-Q3],[2023-Q4],
        [2024-Q1],[2024-Q2],[2024-Q3],[2024-Q4]
    )
) AS pvt
ORDER BY category;
GO


-- QUERY 6: 30-day Rolling Average Revenue

;WITH daily_sales AS (
    SELECT
        d.full_date,
        d.year_number,
        d.month_name,
        SUM(f.net_revenue)  AS daily_revenue,
        COUNT(f.sale_key) AS transactions
    FROM dbo.fact_sales f
    JOIN dbo.dim_date   d ON f.date_key = d.date_key
    GROUP BY d.full_date, d.year_number, d.month_name
)
SELECT
    full_date,
    year_number,
    month_name,
    ROUND(daily_revenue, 2) AS daily_revenue,
    transactions,
    ROUND(AVG(daily_revenue) OVER (ORDER BY full_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW), 2) AS rolling_30d_avg,
    ROUND(SUM(daily_revenue) OVER (ORDER BY full_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 2) AS rolling_7d_sum
FROM daily_sales
ORDER BY full_date;
GO
