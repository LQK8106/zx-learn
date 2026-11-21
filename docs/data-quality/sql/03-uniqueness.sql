-- 03 唯一性：主键与业务键重复率
-- 口径：重复记录数 = 总行数 - 去重后键数；分母为总行数

WITH metrics AS (
    SELECT 'U01' AS rule_id, 'uniqueness' AS dimension, 'orders.order_id 重复' AS rule_name,
           (SELECT COUNT(*) - COUNT(DISTINCT order_id) FROM orders) AS numerator,
           (SELECT COUNT(*) FROM orders) AS denominator
    UNION ALL
    SELECT 'U02', 'uniqueness', 'customers.customer_id 重复',
           (SELECT COUNT(*) - COUNT(DISTINCT customer_id) FROM customers),
           (SELECT COUNT(*) FROM customers)
    UNION ALL
    SELECT 'U03', 'uniqueness', 'order_items 业务键 (order_id, order_item_id) 重复',
           (SELECT COUNT(*) - COUNT(DISTINCT (order_id, order_item_id)) FROM order_items),
           (SELECT COUNT(*) FROM order_items)
    UNION ALL
    SELECT 'U04', 'uniqueness', 'payments 业务键 (order_id, payment_sequential) 重复',
           (SELECT COUNT(*) - COUNT(DISTINCT (order_id, payment_sequential)) FROM payments),
           (SELECT COUNT(*) FROM payments)
    UNION ALL
    SELECT 'U05', 'uniqueness', 'reviews.review_id 重复',
           (SELECT COUNT(*) - COUNT(DISTINCT review_id) FROM reviews),
           (SELECT COUNT(*) FROM reviews)
    UNION ALL
    SELECT 'U06', 'uniqueness', 'products.product_id 重复',
           (SELECT COUNT(*) - COUNT(DISTINCT product_id) FROM products),
           (SELECT COUNT(*) FROM products)
)
SELECT rule_id, dimension, rule_name, numerator, denominator,
       ROUND(100.0 * numerator / NULLIF(denominator, 0), 4) AS violation_rate_pct
FROM metrics
ORDER BY rule_id;

-- 补充诊断 1：review_id 重复组的构成（行数、跨订单、跨评分）
WITH dup AS (
    SELECT review_id FROM reviews GROUP BY review_id HAVING COUNT(*) > 1
),
detail AS (
    SELECT r.review_id,
           COUNT(*) AS row_cnt,
           COUNT(DISTINCT r.order_id) AS order_cnt,
           COUNT(DISTINCT r.review_score) AS score_cnt
    FROM reviews r
    JOIN dup d ON d.review_id = r.review_id
    GROUP BY r.review_id
)
SELECT (SELECT COUNT(*) FROM dup) AS duplicate_review_ids,
       SUM(row_cnt) AS rows_in_duplicate_groups,
       SUM(row_cnt) - COUNT(*) AS extra_rows,
       COUNT(*) FILTER (WHERE order_cnt > 1) AS groups_with_multi_order,
       COUNT(*) FILTER (WHERE score_cnt > 1) AS groups_with_multi_score,
       COUNT(*) FILTER (WHERE order_cnt > 1 OR score_cnt > 1) AS groups_with_any_conflict,
       MAX(row_cnt) AS max_rows_per_review_id
FROM detail;

-- 补充诊断 2：每单评价条数分布（判断一对多是否为业务常态）
SELECT reviews_per_order, COUNT(*) AS order_count,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 4) AS pct
FROM (
    SELECT order_id, COUNT(*) AS reviews_per_order
    FROM reviews
    GROUP BY order_id
)
GROUP BY reviews_per_order
ORDER BY reviews_per_order;
