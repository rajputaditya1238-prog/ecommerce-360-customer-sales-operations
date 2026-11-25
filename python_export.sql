--fact_orders.csv
SELECT o.*, c.state AS customer_state
FROM dw.fact_orders AS o
JOIN dw.dim_customers AS c ON c.customer_id = o.customer_id;


--order_items_enriched.csv
SELECT i.order_id, i.order_item_id, i.price, i.freight_value, i.seller_id,
       p.category_en, o.is_sale, o.is_late, o.is_delivery_valid, o.review_score,
       c.state AS customer_state
FROM dw.fact_order_items AS i
JOIN dw.fact_orders      AS o ON o.order_id    = i.order_id
JOIN dw.dim_products     AS p ON p.product_id  = i.product_id
JOIN dw.dim_customers    AS c ON c.customer_id = o.customer_id;


--order_items_enriched.csv
SELECT * FROM dw.v_customer_sales;

--seller_sales.csv
SELECT * FROM dw.v_seller_sales;




