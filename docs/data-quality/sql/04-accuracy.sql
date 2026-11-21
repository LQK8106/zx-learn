-- 04 准确性：负值/零值、超出业务值域、未来日期、异常维度
-- 说明：A02 的零值支付多为 voucher/not_defined 拆分行，按“可疑值”计入并保留解释

WITH metrics AS (
    SELECT 'A01' AS rule_id, 'accuracy' AS dimension, 'order_items 金额为负' AS rule_name,
           COUNT(*) FILTER (WHERE price < 0 OR freight_value < 0) AS numerator,
           COUNT(*) AS denominator
    FROM order_items
    UNION ALL
    SELECT 'A02', 'accuracy', 'payments 支付金额 <= 0',
           COUNT(*) FILTER (WHERE payment_value <= 0),
           COUNT(*)
    FROM payments
    UNION ALL
    SELECT 'A03', 'accuracy', 'review_score 超出 1..5 或缺失',
           COUNT(*) FILTER (WHERE review_score IS NULL OR review_score NOT BETWEEN 1 AND 5),
           COUNT(*)
    FROM reviews
    UNION ALL
    SELECT 'A04', 'accuracy', '商品重量/尺寸超出合理值域（<=0 或 超上限）',
           COUNT(*) FILTER (
               WHERE (product_weight_g IS NOT NULL AND (product_weight_g <= 0 OR product_weight_g > 50000))
                  OR (product_length_cm IS NOT NULL AND (product_length_cm <= 0 OR product_length_cm > 200))
                  OR (product_height_cm IS NOT NULL AND (product_height_cm <= 0 OR product_height_cm > 200))
                  OR (product_width_cm IS NOT NULL AND (product_width_cm <= 0 OR product_width_cm > 200))
           ),
           COUNT(*)
    FROM products
    UNION ALL
    SELECT 'A05', 'accuracy', '下单时间晚于报告日（未来日期）',
           COUNT(*) FILTER (WHERE order_purchase_timestamp > TIMESTAMP '2026-11-21 23:59:59'),
           COUNT(*) FILTER (WHERE order_purchase_timestamp IS NOT NULL)
    FROM orders
    UNION ALL
    SELECT 'A06', 'accuracy', '分期数超出 0..24 或缺失',
           COUNT(*) FILTER (WHERE payment_installments IS NULL OR payment_installments < 0 OR payment_installments > 24),
           COUNT(*)
    FROM payments
)
SELECT rule_id, dimension, rule_name, numerator, denominator,
       ROUND(100.0 * numerator / NULLIF(denominator, 0), 4) AS violation_rate_pct
FROM metrics
ORDER BY rule_id;

-- 补充诊断 1：零值/负值支付的构成
SELECT payment_type, COUNT(*) AS row_count,
       ROUND(SUM(payment_value), 2) AS value_sum,
       COUNT(DISTINCT order_id) AS order_count
FROM payments
WHERE payment_value <= 0
GROUP BY payment_type
ORDER BY row_count DESC;

-- 补充诊断 2：重量/尺寸异常商品明细
SELECT product_id, product_category_name, product_weight_g,
       product_length_cm, product_height_cm, product_width_cm
FROM products
WHERE (product_weight_g IS NOT NULL AND (product_weight_g <= 0 OR product_weight_g > 50000))
   OR (product_length_cm IS NOT NULL AND (product_length_cm <= 0 OR product_length_cm > 200))
   OR (product_height_cm IS NOT NULL AND (product_height_cm <= 0 OR product_height_cm > 200))
   OR (product_width_cm IS NOT NULL AND (product_width_cm <= 0 OR product_width_cm > 200))
ORDER BY product_id;
