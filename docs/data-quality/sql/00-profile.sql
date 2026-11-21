-- 00 画像：表规模、主键/业务键重复、空值 Top20、时间范围、枚举基数
-- 依赖 run_dq.py 创建的 *_raw 表与类型化视图

SELECT 'orders' AS table_name,
       (SELECT COUNT(*) FROM orders) AS row_count,
       (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'orders_raw') AS column_count,
       (SELECT COUNT(*) - COUNT(DISTINCT order_id) FROM orders) AS pk_duplicates,
       'order_id' AS pk_candidate
UNION ALL
SELECT 'customers', (SELECT COUNT(*) FROM customers),
       (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'customers_raw'),
       (SELECT COUNT(*) - COUNT(DISTINCT customer_id) FROM customers), 'customer_id'
UNION ALL
SELECT 'order_items', (SELECT COUNT(*) FROM order_items),
       (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'order_items_raw'),
       (SELECT COUNT(*) - COUNT(DISTINCT (order_id, order_item_id)) FROM order_items), '(order_id, order_item_id)'
UNION ALL
SELECT 'payments', (SELECT COUNT(*) FROM payments),
       (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'payments_raw'),
       (SELECT COUNT(*) - COUNT(DISTINCT (order_id, payment_sequential)) FROM payments), '(order_id, payment_sequential)'
UNION ALL
SELECT 'reviews', (SELECT COUNT(*) FROM reviews),
       (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'reviews_raw'),
       (SELECT COUNT(*) - COUNT(DISTINCT review_id) FROM reviews), 'review_id'
UNION ALL
SELECT 'products', (SELECT COUNT(*) FROM products),
       (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'products_raw'),
       (SELECT COUNT(*) - COUNT(DISTINCT product_id) FROM products), 'product_id'
UNION ALL
SELECT 'sellers', (SELECT COUNT(*) FROM sellers),
       (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'sellers_raw'),
       (SELECT COUNT(*) - COUNT(DISTINCT seller_id) FROM sellers), 'seller_id'
UNION ALL
SELECT 'category_translation', (SELECT COUNT(*) FROM category_translation),
       (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'category_translation_raw'),
       (SELECT COUNT(*) - COUNT(DISTINCT product_category_name) FROM category_translation), 'product_category_name';

WITH profile AS (
    SELECT 'orders' AS table_name, 'order_approved_at' AS column_name, COUNT(*) AS total,
           COUNT(*) FILTER (WHERE order_approved_at IS NULL) AS missing FROM orders
    UNION ALL SELECT 'orders', 'order_delivered_customer_date', COUNT(*),
           COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL) FROM orders
    UNION ALL SELECT 'orders', 'order_estimated_delivery_date', COUNT(*),
           COUNT(*) FILTER (WHERE order_estimated_delivery_date IS NULL) FROM orders
    UNION ALL SELECT 'order_items', 'shipping_limit_date', COUNT(*),
           COUNT(*) FILTER (WHERE shipping_limit_date IS NULL) FROM order_items
    UNION ALL SELECT 'order_items', 'price', COUNT(*),
           COUNT(*) FILTER (WHERE price IS NULL) FROM order_items
    UNION ALL SELECT 'order_items', 'freight_value', COUNT(*),
           COUNT(*) FILTER (WHERE freight_value IS NULL) FROM order_items
    UNION ALL SELECT 'payments', 'payment_type', COUNT(*),
           COUNT(*) FILTER (WHERE payment_type IS NULL OR TRIM(payment_type) = '') FROM payments
    UNION ALL SELECT 'payments', 'payment_installments', COUNT(*),
           COUNT(*) FILTER (WHERE payment_installments IS NULL) FROM payments
    UNION ALL SELECT 'payments', 'payment_value', COUNT(*),
           COUNT(*) FILTER (WHERE payment_value IS NULL) FROM payments
    UNION ALL SELECT 'reviews', 'review_comment_title', COUNT(*),
           COUNT(*) FILTER (WHERE review_comment_title IS NULL OR TRIM(review_comment_title) = '') FROM reviews
    UNION ALL SELECT 'reviews', 'review_comment_message', COUNT(*),
           COUNT(*) FILTER (WHERE review_comment_message IS NULL OR TRIM(review_comment_message) = '') FROM reviews
    UNION ALL SELECT 'reviews', 'review_creation_date', COUNT(*),
           COUNT(*) FILTER (WHERE review_creation_date IS NULL) FROM reviews
    UNION ALL SELECT 'reviews', 'review_answer_timestamp', COUNT(*),
           COUNT(*) FILTER (WHERE review_answer_timestamp IS NULL) FROM reviews
    UNION ALL SELECT 'products', 'product_category_name', COUNT(*),
           COUNT(*) FILTER (WHERE product_category_name IS NULL OR TRIM(product_category_name) = '') FROM products
    UNION ALL SELECT 'products', 'product_name_length', COUNT(*),
           COUNT(*) FILTER (WHERE product_name_length IS NULL) FROM products
    UNION ALL SELECT 'products', 'product_description_length', COUNT(*),
           COUNT(*) FILTER (WHERE product_description_length IS NULL) FROM products
    UNION ALL SELECT 'products', 'product_photos_qty', COUNT(*),
           COUNT(*) FILTER (WHERE product_photos_qty IS NULL) FROM products
    UNION ALL SELECT 'products', 'product_weight_g', COUNT(*),
           COUNT(*) FILTER (WHERE product_weight_g IS NULL) FROM products
    UNION ALL SELECT 'products', 'product_length_cm', COUNT(*),
           COUNT(*) FILTER (WHERE product_length_cm IS NULL) FROM products
    UNION ALL SELECT 'products', 'product_height_cm', COUNT(*),
           COUNT(*) FILTER (WHERE product_height_cm IS NULL) FROM products
    UNION ALL SELECT 'products', 'product_width_cm', COUNT(*),
           COUNT(*) FILTER (WHERE product_width_cm IS NULL) FROM products
    UNION ALL SELECT 'customers', 'customer_zip_code_prefix', COUNT(*),
           COUNT(*) FILTER (WHERE customer_zip_code_prefix IS NULL OR TRIM(customer_zip_code_prefix) = '') FROM customers
    UNION ALL SELECT 'customers', 'customer_city', COUNT(*),
           COUNT(*) FILTER (WHERE customer_city IS NULL OR TRIM(customer_city) = '') FROM customers
    UNION ALL SELECT 'customers', 'customer_state', COUNT(*),
           COUNT(*) FILTER (WHERE customer_state IS NULL OR TRIM(customer_state) = '') FROM customers
    UNION ALL SELECT 'sellers', 'seller_zip_code_prefix', COUNT(*),
           COUNT(*) FILTER (WHERE seller_zip_code_prefix IS NULL OR TRIM(seller_zip_code_prefix) = '') FROM sellers
    UNION ALL SELECT 'sellers', 'seller_city', COUNT(*),
           COUNT(*) FILTER (WHERE seller_city IS NULL OR TRIM(seller_city) = '') FROM sellers
    UNION ALL SELECT 'sellers', 'seller_state', COUNT(*),
           COUNT(*) FILTER (WHERE seller_state IS NULL OR TRIM(seller_state) = '') FROM sellers
)
SELECT table_name, column_name, total, missing,
       ROUND(100.0 * missing / NULLIF(total, 0), 2) AS missing_pct
FROM profile
ORDER BY missing_pct DESC
LIMIT 20;

SELECT 'orders.order_purchase_timestamp' AS metric,
       MIN(order_purchase_timestamp) AS min_ts, MAX(order_purchase_timestamp) AS max_ts FROM orders
UNION ALL
SELECT 'orders.order_approved_at', MIN(order_approved_at), MAX(order_approved_at) FROM orders
UNION ALL
SELECT 'orders.order_delivered_customer_date', MIN(order_delivered_customer_date), MAX(order_delivered_customer_date) FROM orders
UNION ALL
SELECT 'reviews.review_creation_date', MIN(review_creation_date), MAX(review_creation_date) FROM reviews;

SELECT 'order_status' AS field, COUNT(DISTINCT order_status) AS distinct_values FROM orders
UNION ALL
SELECT 'payment_type', COUNT(DISTINCT payment_type) FROM payments
UNION ALL
SELECT 'customer_state', COUNT(DISTINCT customer_state) FROM customers
UNION ALL
SELECT 'seller_state', COUNT(DISTINCT seller_state) FROM sellers;
