-- Sale ka flag add karo (Canceled aur bina item wale orders ko hata dega)
ALTER TABLE dw.fact_orders
ADD is_sale AS (CASE WHEN order_status NOT IN ('canceled', 'unavailable')
                      AND item_count > 0 THEN 1 ELSE 0 END);

-- Check karo ki kitne sale hue aur kitne cancel hue
SELECT is_sale, COUNT(*) AS orders 
FROM dw.fact_orders 
GROUP BY is_sale;


SELECT
    COUNT(*)                                             AS total_orders,
    SUM(items_revenue)                                   AS total_revenue,
    COUNT(DISTINCT customer_unique_id)                   AS unique_customers,
    CAST(SUM(items_revenue) / COUNT(*) AS DECIMAL(10,2)) AS avg_order_value
FROM dw.fact_orders
WHERE is_sale = 1;


-- 4.2 Monthly trend + month-on-month growth
WITH monthly AS (
    SELECT DATEFROMPARTS(YEAR(purchase_date), MONTH(purchase_date), 1) AS month_start,
           COUNT(*)           AS orders,
           SUM(items_revenue) AS revenue
    FROM dw.fact_orders
    WHERE is_sale = 1
    GROUP BY DATEFROMPARTS(YEAR(purchase_date), MONTH(purchase_date), 1)
)
SELECT month_start, orders, revenue,
       CAST(100.0 * (revenue - LAG(revenue) OVER (ORDER BY month_start))
            / NULLIF(LAG(revenue) OVER (ORDER BY month_start), 0) AS DECIMAL(10,1)) AS revenue_mom_pct
FROM monthly
ORDER BY month_start;


-- 4.3 Top 10 categories (revenue share)
SELECT TOP 10
       p.category_en,
       COUNT(*)     AS items_sold,
       CAST(SUM(i.price) AS DECIMAL(12,2)) AS revenue,
       CAST(100.0 * SUM(i.price) / SUM(SUM(i.price)) OVER () AS DECIMAL(5,2)) AS revenue_share_pct
FROM dw.fact_order_items AS i
JOIN dw.fact_orders
AS o ON o.order_id  = i.order_id
JOIN dw.dim_products     
AS p ON p.product_id = i.product_id
WHERE o.is_sale = 1
GROUP BY p.category_en
ORDER BY revenue DESC;


-- 4.4 Top 10 states (customer geography)
SELECT TOP 10
       c.state,
       COUNT(*)             AS orders,
       CAST(SUM(o.items_revenue) AS DECIMAL(12,2)) AS revenue,
       CAST(100.0 * SUM(o.items_revenue) / SUM(SUM(o.items_revenue)) OVER () AS DECIMAL(5,2)) 
                                                                    AS revenue_share_pct
FROM dw.fact_orders   AS o
JOIN dw.dim_customers AS c ON c.customer_id = o.customer_id
WHERE o.is_sale = 1
GROUP BY c.state
ORDER BY revenue DESC;


-- 4.5 Order status ka breakdown (saare orders)
SELECT order_status,
       COUNT(*) AS orders,
       CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS pct_of_orders
FROM dw.fact_orders
GROUP BY order_status
ORDER BY orders DESC;


-- =========================================================
-- 4B: DELIVERY PERFORMANCE & CUSTOMER SATISFACTION
-- =========================================================

-- 4.6 Overall Delivery KPIs (Average vs Median delivery days & Late Rate)
-- Logic: Calculating overall delivery health to set a baseline.
SELECT
    COUNT(*)                                             AS delivered_orders,
    CAST(AVG(delivery_days) AS DECIMAL(6,2))             AS avg_delivery_days,
    CAST(AVG(DATEDIFF(SECOND, purchase_ts, estimated_ts) / 86400.0) AS DECIMAL(6,2)) AS avg_estimated_days,
    SUM(is_late)                                         AS late_orders,
    CAST(100.0 * SUM(is_late) / COUNT(*) AS DECIMAL(5,2)) AS late_pct
FROM dw.fact_orders
WHERE is_delivery_valid = 1;

-- 4.6 (Bonus) Median Delivery Days (Robust metric against outliers)
SELECT DISTINCT
       CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY delivery_days) OVER () AS DECIMAL(6,2)) AS median_delivery_days
FROM dw.fact_orders
WHERE is_delivery_valid = 1;

-- 4.7 State-wise Late Delivery Rate (Logistics Bottlenecks)
-- Logic: Filtering states with >= 500 orders to ensure statistical significance.
SELECT TOP 8
       c.state,
       COUNT(*)       AS delivered_orders,
       SUM(o.is_late) AS late_orders,
       CAST(100.0 * SUM(o.is_late) / COUNT(*) AS DECIMAL(5,2)) AS late_pct
FROM dw.fact_orders   AS o
JOIN dw.dim_customers AS c ON c.customer_id = o.customer_id
WHERE o.is_delivery_valid = 1
GROUP BY c.state
HAVING COUNT(*) >= 500
ORDER BY late_pct DESC;

-- 4.8 Impact of Delay Severity on Review Scores (The Core Insight)
-- Logic: Bucketing delays (1-3 days, 4-7 days, 8+ days) to see exactly when customer satisfaction drops.
WITH bucketed AS (
    SELECT
        CASE WHEN days_vs_estimate >= 0  THEN '1_on_time_or_early'
             WHEN days_vs_estimate >= -3 THEN '2_late_1_3_days'
             WHEN days_vs_estimate >= -7 THEN '3_late_4_7_days'
             ELSE '4_late_8plus_days' END AS delivery_bucket,
        review_score
    FROM dw.fact_orders
    WHERE is_delivery_valid = 1 AND review_score IS NOT NULL
)
SELECT delivery_bucket,
       COUNT(*) AS reviewed_orders,
       CAST(AVG(CAST(review_score AS DECIMAL(10,4))) AS DECIMAL(4,2)) AS avg_review_score,
       CAST(100.0 * SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS low_score_pct
FROM bucketed
GROUP BY delivery_bucket
ORDER BY delivery_bucket;

-- 4.9 Overall Review Score Distribution (1 to 5 stars)
-- Logic: Understanding the overall sentiment of the customer base.
SELECT review_score,
       COUNT(*) AS orders,
       CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS pct
FROM dw.fact_orders
WHERE is_delivery_valid = 1 AND review_score IS NOT NULL
GROUP BY review_score
ORDER BY review_score;

-- 4.10 Lowest Rated Product Categories (Product Quality/Satisfaction)
-- Logic: Filtering categories with >= 1000 items to find consistently bad experiences.
SELECT TOP 6
       p.category_en,
       COUNT(*) AS items,
       CAST(AVG(CAST(o.review_score AS DECIMAL(10,4))) AS DECIMAL(4,2)) AS avg_review_score,
       CAST(100.0 * SUM(o.is_late) / COUNT(*) AS DECIMAL(5,2)) AS late_pct
FROM dw.fact_order_items AS i
JOIN dw.fact_orders      AS o ON o.order_id   = i.order_id
JOIN dw.dim_products     AS p ON p.product_id = i.product_id
WHERE o.is_delivery_valid = 1 AND o.review_score IS NOT NULL
GROUP BY p.category_en
HAVING COUNT(*) >= 1000
ORDER BY avg_review_score;




-- 4.11 Customer View (Ek customer ne total kitne order kiye aur kitna spend kiya)
CREATE OR ALTER VIEW dw.v_customer_sales AS
SELECT customer_unique_id,
       COUNT(*)           AS orders,
       SUM(items_revenue) AS revenue
FROM dw.fact_orders
WHERE is_sale = 1
GROUP BY customer_unique_id;



-- 4.17 Seller View (Ek seller ne total kitne order kiye aur kitna revenue diya)
CREATE OR ALTER VIEW dw.v_seller_sales AS
SELECT i.seller_id,
       COUNT(DISTINCT i.order_id) AS orders,
       SUM(i.price)               AS revenue
FROM dw.fact_order_items AS i
JOIN dw.fact_orders      AS o ON o.order_id = i.order_id
WHERE o.is_sale = 1
GROUP BY i.seller_id;


-- Check Row Counts
SELECT COUNT(*) AS total_customers_in_view FROM dw.v_customer_sales;
SELECT COUNT(*) AS total_sellers_in_view FROM dw.v_seller_sales;



-- ==========================================
-- 4C: CUSTOMER ANALYTICS
-- ==========================================

-- 4.12 Customers by number of orders
WITH bucketed AS (
    SELECT CASE WHEN orders >= 4 THEN '4+' ELSE CAST(orders AS VARCHAR(2)) END AS orders_per_customer,
           revenue
    FROM dw.v_customer_sales
)
SELECT orders_per_customer,
       COUNT(*) AS customers,
       CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS pct_customers,
       CAST(SUM(revenue) AS DECIMAL(14,2)) AS revenue,
       CAST(100.0 * SUM(revenue) / SUM(SUM(revenue)) OVER () AS DECIMAL(5,2)) AS pct_revenue
FROM bucketed
GROUP BY orders_per_customer
ORDER BY orders_per_customer;

-- 4.13 Repeat rate
SELECT COUNT(*) AS customers,
       SUM(CASE WHEN orders > 1 THEN 1 ELSE 0 END) AS repeat_customers,
       CAST(100.0 * SUM(CASE WHEN orders > 1 THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS repeat_rate_pct,
       CAST(AVG(orders * 1.0) AS DECIMAL(5,3)) AS avg_orders_per_customer
FROM dw.v_customer_sales;

-- 4.14 Time to second order
WITH ranked AS (
    SELECT customer_unique_id, purchase_ts,
           ROW_NUMBER() OVER (PARTITION BY customer_unique_id
                              ORDER BY purchase_ts, order_id) AS order_no
    FROM dw.fact_orders
    WHERE is_sale = 1
),
gaps AS (
    SELECT DATEDIFF(SECOND, a.purchase_ts, b.purchase_ts) / 86400.0 AS gap_days
    FROM ranked AS a
    JOIN ranked AS b ON b.customer_unique_id = a.customer_unique_id
    WHERE a.order_no = 1 AND b.order_no = 2
)
SELECT DISTINCT
       COUNT(*) OVER () AS repeat_customers,
       CAST(AVG(gap_days) OVER () AS DECIMAL(8,2)) AS avg_days_to_2nd_order,
       CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY gap_days) OVER () AS DECIMAL(8,2)) AS median_days_to_2nd_order
FROM gaps;

-- 4.15 Customer contribution (Top 10% spend)
WITH ranked AS (
    SELECT revenue, NTILE(10) OVER (ORDER BY revenue DESC) AS spend_decile
    FROM dw.v_customer_sales
)
SELECT spend_decile,
       COUNT(*) AS customers,
       CAST(SUM(revenue) AS DECIMAL(14,2)) AS revenue,
       CAST(100.0 * SUM(revenue) / SUM(SUM(revenue)) OVER () AS DECIMAL(5,2)) AS pct_revenue,
       CAST(100.0 * SUM(SUM(revenue)) OVER (ORDER BY spend_decile) / SUM(SUM(revenue)) OVER () AS DECIMAL(5,2)) AS cumulative_pct
FROM ranked
GROUP BY spend_decile
ORDER BY spend_decile;

-- 4.16 Customer segmentation (No RFM, Value based)
WITH thr AS (
    SELECT DISTINCT
           PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY revenue) OVER () AS p25,
           PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY revenue) OVER () AS p75
    FROM dw.v_customer_sales
    WHERE orders = 1
),
seg AS (
    SELECT c.revenue,
           CASE WHEN c.orders >= 2      THEN 'Repeat'
                WHEN c.revenue >= t.p75 THEN 'One-time high value'
                WHEN c.revenue <= t.p25 THEN 'One-time low value'
                ELSE 'One-time mid value' END AS segment
    FROM dw.v_customer_sales AS c
    CROSS JOIN thr AS t
)
SELECT segment, COUNT(*) AS customers,
       CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS pct_customers,
       CAST(SUM(revenue) AS DECIMAL(14,2)) AS revenue,
       CAST(100.0 * SUM(revenue) / SUM(SUM(revenue)) OVER () AS DECIMAL(5,2)) AS pct_revenue,
       CAST(AVG(revenue) AS DECIMAL(10,2)) AS avg_revenue_per_customer
FROM seg
GROUP BY segment
ORDER BY pct_revenue DESC;



-- ==========================================
-- 4D: SELLER, PRODUCT & PAYMENTS ANALYTICS
-- ==========================================

-- 4.18 Seller concentration (sellers ke 10 groups)
WITH ranked AS (
    SELECT revenue, NTILE(10) OVER (ORDER BY revenue DESC) AS revenue_decile
    FROM dw.v_seller_sales
)
SELECT revenue_decile,
       COUNT(*) AS sellers,
       CAST(SUM(revenue) AS DECIMAL(14,2)) AS revenue,
       CAST(100.0 * SUM(revenue) / SUM(SUM(revenue)) OVER () AS DECIMAL(5,2)) AS pct_revenue,
       CAST(100.0 * SUM(SUM(revenue)) OVER (ORDER BY revenue_decile)
            / SUM(SUM(revenue)) OVER () AS DECIMAL(5,2)) AS cumulative_pct
FROM ranked
GROUP BY revenue_decile
ORDER BY revenue_decile;

-- 4.19 Sabse kam rating waale sellers (kam se kam 100 orders)
SELECT TOP 6
       so.seller_id,
       COUNT(*) AS orders,
       CAST(AVG(CAST(o.review_score AS DECIMAL(10,4))) AS DECIMAL(4,2)) AS avg_review_score,
       CAST(100.0 * SUM(o.is_late) / COUNT(*) AS DECIMAL(5,2)) AS late_pct
FROM (SELECT DISTINCT seller_id, order_id FROM dw.fact_order_items) AS so
JOIN dw.fact_orders AS o ON o.order_id = so.order_id
WHERE o.is_delivery_valid = 1 AND o.review_score IS NOT NULL
GROUP BY so.seller_id
HAVING COUNT(*) >= 100
ORDER BY avg_review_score;

-- 4.20 Payment type breakdown (sale orders)
SELECT p.payment_type,
       COUNT(*)                   AS payment_records,
       COUNT(DISTINCT o.order_id) AS orders,
       CAST(SUM(CAST(p.payment_value AS DECIMAL(12,2))) AS DECIMAL(14,2)) AS payment_value,
       CAST(100.0 * SUM(CAST(p.payment_value AS DECIMAL(12,2)))
            / SUM(SUM(CAST(p.payment_value AS DECIMAL(12,2)))) OVER () AS DECIMAL(5,2)) AS pct_of_value
FROM dbo.payments   AS p
JOIN dw.fact_orders AS o ON o.order_id = CAST(p.order_id AS VARCHAR(32))
WHERE o.is_sale = 1
GROUP BY p.payment_type
ORDER BY payment_value DESC;

-- 4.21 Price vs volume: sabse mehngi categories (kam se kam 1,000 items)
SELECT TOP 6
       p.category_en,
       COUNT(*)                             AS items_sold,
       CAST(AVG(i.price) AS DECIMAL(10,2))  AS avg_item_price,
       CAST(SUM(i.price) AS DECIMAL(14,2))  AS revenue
FROM dw.fact_order_items AS i
JOIN dw.fact_orders      AS o ON o.order_id   = i.order_id
JOIN dw.dim_products     AS p ON p.product_id = i.product_id
WHERE o.is_sale = 1
GROUP BY p.category_en
HAVING COUNT(*) >= 1000
ORDER BY avg_item_price DESC;