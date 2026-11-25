CREATE OR ALTER VIEW dw.v_customer_deciles AS
WITH ranked AS (
    SELECT revenue, NTILE(10) OVER (ORDER BY revenue DESC) AS spend_decile
    FROM dw.v_customer_sales
)
SELECT spend_decile,
       COUNT(*) AS customers,
       CAST(SUM(revenue) AS DECIMAL(14,2)) AS revenue,
       CAST(100.0 * SUM(revenue) / SUM(SUM(revenue)) OVER () AS DECIMAL(5,2)) AS pct_revenue
FROM ranked
GROUP BY spend_decile



CREATE OR ALTER VIEW dw.v_seller_deciles AS
WITH ranked AS (
    SELECT revenue, NTILE(10) OVER (ORDER BY revenue DESC) AS revenue_decile
    FROM dw.v_seller_sales
)
SELECT revenue_decile,
       COUNT(*) AS sellers,
       CAST(SUM(revenue) AS DECIMAL(14,2)) AS revenue,
       CAST(100.0 * SUM(revenue) / SUM(SUM(revenue)) OVER () AS DECIMAL(5,2)) AS pct_revenue
FROM ranked
GROUP BY revenue_decile