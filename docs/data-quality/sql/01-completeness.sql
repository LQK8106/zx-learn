-- 01 完整性：记录缺失率 + 引用完整性孤儿率
-- 口径：分母为“应存在的记录数”，分子为该范围内缺失/孤儿的记录数

WITH metrics AS (
    SELECT 'C01' AS rule_id, 'completeness' AS dimension,
           'delivered 订单缺少签收时间' AS rule_name,
           COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL) AS numerator,
           COUNT(*) AS denominator
    FROM orders
    WHERE order_status = 'delivered'
    UNION ALL
    SELECT 'C02', 'completeness', '已进入履约状态但缺少审批时间',
           COUNT(*) FILTER (WHERE order_approved_at IS NULL),
           COUNT(*)
    FROM orders
    WHERE order_status IN ('delivered', 'shipped', 'invoiced', 'processing', 'approved')
    UNION ALL
    SELECT 'C03', 'completeness', 'order_items 订单孤儿（order_id 不存在于 orders）',
           COUNT(*), (SELECT COUNT(*) FROM order_items)
    FROM order_items i
    LEFT JOIN orders o USING (order_id)
    WHERE o.order_id IS NULL
    UNION ALL
    SELECT 'C04', 'completeness', 'payments 订单孤儿',
           COUNT(*), (SELECT COUNT(*) FROM payments)
    FROM payments p
    LEFT JOIN orders o USING (order_id)
    WHERE o.order_id IS NULL
    UNION ALL
    SELECT 'C05', 'completeness', 'reviews 订单孤儿',
           COUNT(*), (SELECT COUNT(*) FROM reviews)
    FROM reviews r
    LEFT JOIN orders o USING (order_id)
    WHERE o.order_id IS NULL
    UNION ALL
    SELECT 'C06', 'completeness', 'orders 客户孤儿（customer_id 不存在于 customers）',
           COUNT(*), (SELECT COUNT(*) FROM orders)
    FROM orders o
    LEFT JOIN customers c USING (customer_id)
    WHERE c.customer_id IS NULL
    UNION ALL
    SELECT 'C07', 'completeness', 'products 类目缺失',
           COUNT(*) FILTER (WHERE product_category_name IS NULL OR TRIM(product_category_name) = ''),
           COUNT(*)
    FROM products
)
SELECT rule_id, dimension, rule_name, numerator, denominator,
       ROUND(100.0 * numerator / NULLIF(denominator, 0), 4) AS violation_rate_pct
FROM metrics
ORDER BY rule_id;
