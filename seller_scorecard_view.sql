CREATE OR ALTER VIEW dw.v_seller_scorecard AS
SELECT so.seller_id,
       COUNT(*) AS delivered_reviewed_orders,
       CAST(AVG(CAST(o.review_score AS DECIMAL(10,4))) AS DECIMAL(4,2)) AS avg_review_score,
       CAST(100.0 * SUM(o.is_late) / COUNT(*) AS DECIMAL(5,2)) AS late_pct
FROM (SELECT DISTINCT seller_id, order_id FROM dw.fact_order_items) AS so
JOIN dw.fact_orders AS o ON o.order_id = so.order_id
WHERE o.is_delivery_valid = 1 AND o.review_score IS NOT NULL
GROUP BY so.seller_id


SELECT COUNT(*) FROM dw.v_seller_scorecard WHERE delivered_reviewed_orders >= 100