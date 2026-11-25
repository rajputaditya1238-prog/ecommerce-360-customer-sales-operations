
-- PART 1: DATA TRANSFORMATION (BUILDING dw TABLES)
USE Ecommerce360;
GO


DROP TABLE IF EXISTS dw.fact_order_items;
DROP TABLE IF EXISTS dw.fact_orders;
DROP TABLE IF EXISTS dw.dim_products;
DROP TABLE IF EXISTS dw.dim_sellers;
DROP TABLE IF EXISTS dw.dim_customers;
IF SCHEMA_ID('dw') IS NULL EXEC('CREATE SCHEMA dw');
GO

-- 1. dim_customers
SELECT
    CAST(customer_id AS VARCHAR(32))        AS customer_id,
    CAST(customer_unique_id AS VARCHAR(32)) AS customer_unique_id,
    CAST(customer_zip_code_prefix AS INT)   AS zip_code_prefix,
    CAST(customer_city AS NVARCHAR(100))    AS city,
    CAST(customer_state AS CHAR(2))         AS state
INTO dw.dim_customers
FROM dbo.customers;
ALTER TABLE dw.dim_customers ALTER COLUMN customer_id VARCHAR(32) NOT NULL;
ALTER TABLE dw.dim_customers ADD CONSTRAINT pk_dim_customers PRIMARY KEY (customer_id);
GO

-- 2. dim_sellers
SELECT
    CAST(seller_id AS VARCHAR(32))        AS seller_id,
    CAST(seller_zip_code_prefix AS INT)   AS zip_code_prefix,
    CAST(seller_city AS NVARCHAR(100))    AS city,
    CAST(seller_state AS CHAR(2))         AS state
INTO dw.dim_sellers
FROM dbo.sellers;
ALTER TABLE dw.dim_sellers ALTER COLUMN seller_id VARCHAR(32) NOT NULL;
ALTER TABLE dw.dim_sellers ADD CONSTRAINT pk_dim_sellers PRIMARY KEY (seller_id);
GO

-- 3. dim_products
SELECT
    CAST(p.product_id AS VARCHAR(32)) AS product_id,
    CAST(COALESCE(p.product_category_name, 'unknown') AS VARCHAR(100)) AS category_pt,
    CAST(
        CASE
            WHEN p.product_category_name IS NULL THEN 'unknown'
            WHEN t.product_category_name_english IS NOT NULL THEN t.product_category_name_english
            WHEN p.product_category_name = 'pc_gamer' THEN 'pc_gamer'
            WHEN p.product_category_name = 'portateis_cozinha_e_preparadores_de_alimentos'
                THEN 'portable_kitchen_and_food_preparers'
            ELSE p.product_category_name
        END AS VARCHAR(100)) AS category_en
INTO dw.dim_products
FROM dbo.products AS p
LEFT JOIN dbo.category_translation AS t
       ON t.product_category_name = p.product_category_name;
ALTER TABLE dw.dim_products ALTER COLUMN product_id VARCHAR(32) NOT NULL;
ALTER TABLE dw.dim_products ADD CONSTRAINT pk_dim_products PRIMARY KEY (product_id);
GO


USE Ecommerce360;
GO

WITH items AS (
    SELECT CAST(order_id AS VARCHAR(32)) AS order_id,
           COUNT(*) AS item_count,
           SUM(CAST(price AS DECIMAL(12,2))) AS items_revenue,
           SUM(CAST(freight_value AS DECIMAL(12,2))) AS freight_total
    FROM dbo.order_items
    GROUP BY CAST(order_id AS VARCHAR(32))
),
pay AS (
    SELECT CAST(order_id AS VARCHAR(32)) AS order_id,
           COUNT(*) AS payment_records,
           SUM(CAST(payment_value AS DECIMAL(12,2))) AS payment_total
    FROM dbo.payments
    GROUP BY CAST(order_id AS VARCHAR(32))
),
latest_review AS (
    SELECT order_id, review_score
    FROM (
        SELECT CAST(order_id AS VARCHAR(32)) AS order_id,
               CAST(review_score AS INT) AS review_score,
               ROW_NUMBER() OVER (
                   PARTITION BY CAST(order_id AS VARCHAR(32))
                   ORDER BY TRY_CAST(review_answer_timestamp AS DATETIME2(0)) DESC,
                            TRY_CAST(review_creation_date AS DATETIME2(0)) DESC,
                            review_id DESC) AS rn
        FROM dbo.reviews
    ) AS ranked
    WHERE rn = 1
),
orders_typed AS (
    SELECT
        CAST(o.order_id AS VARCHAR(32)) AS order_id,
        CAST(o.customer_id AS VARCHAR(32)) AS customer_id,
        CAST(c.customer_unique_id AS VARCHAR(32)) AS customer_unique_id,
        CAST(o.order_status AS VARCHAR(20)) AS order_status,
        TRY_CAST(o.order_purchase_timestamp AS DATETIME2(0)) AS purchase_ts,
        TRY_CAST(o.order_approved_at AS DATETIME2(0)) AS approved_ts,
        TRY_CAST(o.order_delivered_carrier_date AS DATETIME2(0)) AS carrier_ts,
        TRY_CAST(o.order_delivered_customer_date AS DATETIME2(0)) AS delivered_ts,
        TRY_CAST(o.order_estimated_delivery_date AS DATETIME2(0)) AS estimated_ts
    FROM dbo.orders AS o
    LEFT JOIN dbo.customers AS c ON c.customer_id = o.customer_id
)
SELECT
    t.order_id, t.customer_id, t.customer_unique_id, t.order_status,
    t.purchase_ts, t.approved_ts, t.carrier_ts, t.delivered_ts, t.estimated_ts,
    CAST(t.purchase_ts AS DATE) AS purchase_date,
    CAST(ISNULL(i.item_count, 0) AS INT) AS item_count,
    CAST(ISNULL(i.items_revenue, 0) AS DECIMAL(12,2)) AS items_revenue,
    CAST(ISNULL(i.freight_total, 0) AS DECIMAL(12,2)) AS freight_total,
    CAST(ISNULL(p.payment_records, 0) AS INT) AS payment_records,
    CAST(ISNULL(p.payment_total, 0) AS DECIMAL(12,2)) AS payment_total,
    r.review_score,
    CASE WHEN t.order_status = 'delivered' AND t.delivered_ts IS NOT NULL THEN 1 ELSE 0 END AS is_delivery_valid,
    CASE WHEN t.order_status = 'delivered' AND t.delivered_ts IS NOT NULL
         THEN CAST(DATEDIFF(SECOND, t.purchase_ts, t.delivered_ts) / 86400.0 AS DECIMAL(8,2)) END AS delivery_days,
    CASE WHEN t.order_status = 'delivered' AND t.delivered_ts IS NOT NULL
         THEN CASE WHEN CAST(t.delivered_ts AS DATE) > CAST(t.estimated_ts AS DATE) THEN 1 ELSE 0 END END AS is_late,
    CASE WHEN t.order_status = 'delivered' AND t.delivered_ts IS NOT NULL
         THEN DATEDIFF(DAY, CAST(t.delivered_ts AS DATE), CAST(t.estimated_ts AS DATE)) END AS days_vs_estimate
INTO dw.fact_orders
FROM orders_typed AS t
LEFT JOIN items AS i ON i.order_id = t.order_id
LEFT JOIN pay AS p ON p.order_id = t.order_id
LEFT JOIN latest_review AS r ON r.order_id = t.order_id;
GO

ALTER TABLE dw.fact_orders ALTER COLUMN order_id VARCHAR(32) NOT NULL;
ALTER TABLE dw.fact_orders ADD CONSTRAINT pk_fact_orders PRIMARY KEY (order_id);
ALTER TABLE dw.fact_orders ADD CONSTRAINT fk_orders_customer
                        FOREIGN KEY (customer_id) REFERENCES dw.dim_customers (customer_id);
GO

ALTER TABLE dw.fact_orders ALTER COLUMN order_id VARCHAR(32) NOT NULL

ALTER TABLE dw.fact_orders ADD CONSTRAINT pk_fact_orders PRIMARY KEY (order_id)

ALTER TABLE dw.fact_orders ADD CONSTRAINT fk_orders_customer
                       FOREIGN KEY (customer_id) REFERENCES dw.dim_customers (customer_id);



USE Ecommerce360;
GO

SELECT
    CAST(order_id AS VARCHAR(32)) AS order_id,
    CAST(order_item_id AS INT) AS order_item_id,
    CAST(product_id AS VARCHAR(32)) AS product_id,
    CAST(seller_id AS VARCHAR(32)) AS seller_id,
    TRY_CAST(shipping_limit_date AS DATETIME2(0)) AS shipping_limit_ts,
    CAST(price AS DECIMAL(12,2)) AS price,
    CAST(freight_value AS DECIMAL(12,2)) AS freight_value
INTO dw.fact_order_items
FROM dbo.order_items;

ALTER TABLE dw.fact_order_items ALTER COLUMN order_id VARCHAR(32) NOT NULL;
ALTER TABLE dw.fact_order_items ALTER COLUMN order_item_id INT NOT NULL;
ALTER TABLE dw.fact_order_items ADD CONSTRAINT pk_fact_order_items PRIMARY KEY (order_id, order_item_id);
ALTER TABLE dw.fact_order_items ADD CONSTRAINT fk_items_order FOREIGN KEY (order_id) REFERENCES dw.fact_orders (order_id);
ALTER TABLE dw.fact_order_items ADD CONSTRAINT fk_items_product FOREIGN KEY (product_id) REFERENCES dw.dim_products (product_id);
ALTER TABLE dw.fact_order_items ADD CONSTRAINT fk_items_seller FOREIGN KEY (seller_id) REFERENCES dw.dim_sellers (seller_id);
GO




-- PART 2: VALIDATION (CHECKING ROW COUNTS AND REVENUE)


SELECT check_name, result, expected,
       CASE WHEN ABS(result - expected) < 0.02 THEN 'OK' ELSE 'CHECK' END AS status
FROM (
    SELECT 'fact_orders: rows' AS check_name,
           CAST(COUNT(*) AS DECIMAL(18,2)) AS result, CAST(99441 AS DECIMAL(18,2)) AS expected
    FROM dw.fact_orders
    UNION ALL SELECT 'dim_customers: rows', CAST(COUNT(*) AS DECIMAL(18,2)), 99441 FROM dw.dim_customers
    UNION ALL SELECT 'dim_sellers: rows',   CAST(COUNT(*) AS DECIMAL(18,2)), 3095  FROM dw.dim_sellers
    UNION ALL SELECT 'dim_products: rows',  CAST(COUNT(*) AS DECIMAL(18,2)), 32951 FROM dw.dim_products
    UNION ALL SELECT 'fact_order_items: rows', CAST(COUNT(*) AS DECIMAL(18,2)), 112650 FROM dw.fact_order_items
    UNION ALL SELECT 'revenue: fact_orders vs raw order_items',
           CAST((SELECT SUM(items_revenue) FROM dw.fact_orders) AS DECIMAL(18,2)),
           CAST((SELECT SUM(CAST(price AS DECIMAL(12,2))) FROM dbo.order_items) AS DECIMAL(18,2))
    UNION ALL SELECT 'revenue: expected 13591643.70',
           CAST((SELECT SUM(items_revenue) FROM dw.fact_orders) AS DECIMAL(18,2)), 13591643.70
    UNION ALL SELECT 'freight total',
           CAST((SELECT SUM(freight_total) FROM dw.fact_orders) AS DECIMAL(18,2)), 2251909.54
    UNION ALL SELECT 'payments: fact_orders vs raw payments',
           CAST((SELECT SUM(payment_total) FROM dw.fact_orders) AS DECIMAL(18,2)),
           CAST((SELECT SUM(CAST(payment_value AS DECIMAL(12,2))) FROM dbo.payments) AS DECIMAL(18,2))
    UNION ALL SELECT 'orders with no items',
           CAST((SELECT COUNT(*) FROM dw.fact_orders WHERE item_count = 0) AS DECIMAL(18,2)), 775
    UNION ALL SELECT 'orders with no payment',
           CAST((SELECT COUNT(*) FROM dw.fact_orders WHERE payment_records = 0) AS DECIMAL(18,2)), 1
    UNION ALL SELECT 'orders with a review score',
           CAST((SELECT COUNT(review_score) FROM dw.fact_orders) AS DECIMAL(18,2)), 98673
    UNION ALL SELECT 'avg review score (all orders with review)',
           CAST((SELECT ROUND(AVG(CAST(review_score AS DECIMAL(10,4))), 2) FROM dw.fact_orders) AS DECIMAL(18,2)), 4.09
    UNION ALL SELECT 'avg review score (delivered orders)',
           CAST((SELECT ROUND(AVG(CAST(review_score AS DECIMAL(10,4))), 2) FROM dw.fact_orders
                 WHERE order_status = 'delivered') AS DECIMAL(18,2)), 4.16
    UNION ALL SELECT 'delivery-valid orders',
           CAST((SELECT SUM(is_delivery_valid) FROM dw.fact_orders) AS DECIMAL(18,2)), 96470
    UNION ALL SELECT 'late orders',
           CAST((SELECT SUM(is_late) FROM dw.fact_orders) AS DECIMAL(18,2)), 6534
    UNION ALL SELECT 'late-delivery % (of delivery-valid orders)',
           CAST((SELECT ROUND(100.0 * SUM(is_late) / COUNT(is_late), 2) FROM dw.fact_orders) AS DECIMAL(18,2)), 6.77
    UNION ALL SELECT 'avg delivery days',
           CAST((SELECT ROUND(AVG(delivery_days), 2) FROM dw.fact_orders) AS DECIMAL(18,2)), 12.56
    UNION ALL SELECT 'products with category unknown',
           CAST((SELECT COUNT(*) FROM dw.dim_products WHERE category_en = 'unknown') AS DECIMAL(18,2)), 610
) AS v


-- PART 3: DOUBLE-COUNTING PROOF (INTERVIEW READY)
-- =====================================================
-- 1. WRONG WAY (Direct Join): Revenue double ho jayega
SELECT SUM(CAST(i.price AS DECIMAL(12,2))) AS wrong_revenue
FROM dbo.order_items AS i
JOIN dbo.payments  
AS p ON p.order_id = i.order_id;

-- 2. RIGHT WAY (Humara banaya hua Fact Table)
SELECT SUM(items_revenue) AS correct_revenue 
FROM dw.fact_orders;
