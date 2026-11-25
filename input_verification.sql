SELECT 'customers' AS table_name, COUNT(*) AS total_rows FROM dbo.customers
UNION ALL SELECT 'orders', COUNT(*) FROM dbo.orders
UNION ALL SELECT 'order_items', COUNT(*) FROM dbo.order_items
UNION ALL SELECT 'products', COUNT(*) FROM dbo.products
UNION ALL SELECT 'sellers', COUNT(*) FROM dbo.sellers
UNION ALL SELECT 'payments', COUNT(*) FROM dbo.payments
UNION ALL SELECT 'reviews', COUNT(*) FROM dbo.reviews
UNION ALL SELECT 'geolocation', COUNT(*) FROM dbo.geolocation
UNION ALL SELECT 'category_translation', COUNT(*) FROM dbo.category_translation;