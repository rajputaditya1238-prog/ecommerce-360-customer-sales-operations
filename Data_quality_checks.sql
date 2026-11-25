SELECT
    SUM(CASE WHEN order_approved_at IS NULL THEN 1 ELSE 0 END)            AS missing_approved,
    SUM(CASE WHEN order_delivered_carrier_date IS NULL THEN 1 ELSE 0 END) AS missing_carrier,
    SUM(CASE WHEN order_delivered_customer_date IS NULL THEN 1 ELSE 0 END) AS missing_customer
FROM dbo.orders



SELECT * FROM dbo.category_translation
WHERE product_category_name = 'product_category_name'

DELETE FROM dbo.category_translation
WHERE product_category_name = 'product_category_name'

SELECT COUNT(*) AS total_rows FROM dbo.category_translation



SELECT check_name, result, expected,
       CASE WHEN result = expected THEN 'OK' ELSE 'CHECK' END AS status
FROM (
    SELECT 'orders: distinct order_id' AS check_name,
           (SELECT COUNT(DISTINCT order_id) FROM dbo.orders) AS result, 99441 AS expected
    UNION ALL SELECT 'customers: distinct customer_unique_id',
           (SELECT COUNT(DISTINCT customer_unique_id) FROM dbo.customers), 96096
    UNION ALL SELECT 'order_items: duplicate (order_id, order_item_id)',
           (SELECT COUNT(*) FROM (SELECT order_id, order_item_id FROM dbo.order_items
                                  GROUP BY order_id, order_item_id HAVING COUNT(*) > 1) d), 0
    UNION ALL SELECT 'payments: duplicate (order_id, payment_sequential)',
           (SELECT COUNT(*) FROM (SELECT order_id, payment_sequential FROM dbo.payments
                                  GROUP BY order_id, payment_sequential HAVING COUNT(*) > 1) d), 0
    UNION ALL SELECT 'reviews: orders with more than one review',
           (SELECT COUNT(*) FROM (SELECT order_id FROM dbo.reviews
                                  GROUP BY order_id HAVING COUNT(*) > 1) d), 547
    UNION ALL SELECT 'orders without any item',
           (SELECT COUNT(*) FROM dbo.orders o
            WHERE NOT EXISTS (SELECT 1 FROM dbo.order_items i WHERE i.order_id = o.order_id)), 775
    UNION ALL SELECT 'delivered orders with no customer delivery date',
           (SELECT COUNT(*) FROM dbo.orders
            WHERE order_status = 'delivered' AND order_delivered_customer_date IS NULL), 8
    UNION ALL SELECT 'carrier date earlier than purchase date',
           (SELECT COUNT(*) FROM dbo.orders
            WHERE TRY_CAST(order_delivered_carrier_date AS DATETIME2(0))
                < TRY_CAST(order_purchase_timestamp AS DATETIME2(0))), 166
    UNION ALL SELECT 'delivered orders with no payment',
           (SELECT COUNT(*) FROM dbo.orders o
            WHERE o.order_status = 'delivered'
              AND NOT EXISTS (SELECT 1 FROM dbo.payments p WHERE p.order_id = o.order_id)), 1
    UNION ALL SELECT 'products with missing category',
           (SELECT COUNT(*) FROM dbo.products WHERE product_category_name IS NULL), 610
    UNION ALL SELECT 'orphan: orders -> customers',
           (SELECT COUNT(*) FROM dbo.orders o
            WHERE NOT EXISTS (SELECT 1 FROM dbo.customers c WHERE c.customer_id = o.customer_id)), 0
    UNION ALL SELECT 'orphan: order_items -> orders',
           (SELECT COUNT(*) FROM dbo.order_items i
            WHERE NOT EXISTS (SELECT 1 FROM dbo.orders o WHERE o.order_id = i.order_id)), 0
    UNION ALL SELECT 'orphan: order_items -> products',
           (SELECT COUNT(*) FROM dbo.order_items i
            WHERE NOT EXISTS (SELECT 1 FROM dbo.products p WHERE p.product_id = i.product_id)), 0
    UNION ALL SELECT 'orphan: order_items -> sellers',
           (SELECT COUNT(*) FROM dbo.order_items i
            WHERE NOT EXISTS (SELECT 1 FROM dbo.sellers s WHERE s.seller_id = i.seller_id)), 0
    UNION ALL SELECT 'orphan: payments -> orders',
           (SELECT COUNT(*) FROM dbo.payments p
            WHERE NOT EXISTS (SELECT 1 FROM dbo.orders o WHERE o.order_id = p.order_id)), 0
    UNION ALL SELECT 'orphan: reviews -> orders',
           (SELECT COUNT(*) FROM dbo.reviews r
            WHERE NOT EXISTS (SELECT 1 FROM dbo.orders o WHERE o.order_id = r.order_id)), 0
    UNION ALL SELECT 'geolocation: fully duplicated rows',
           (SELECT COUNT(*) FROM dbo.geolocation)
         - (SELECT COUNT(*) FROM (SELECT DISTINCT * FROM dbo.geolocation) d), 261831
) AS scorecard