-- 02 一致性：跨表金额勾稽、时间顺序、状态与时间戳冲突、同实体多记录属性冲突
-- 金额勾稽口径：同一 order 的 order_items.price+freight_value 之和 vs payments.payment_value 之和，容差 0.01

WITH totals AS (
    SELECT o.order_id,
           SUM(COALESCE(i.price, 0) + COALESCE(i.freight_value, 0)) AS item_total,
           (SELECT SUM(p.payment_value) FROM payments p WHERE p.order_id = o.order_id) AS pay_total
    FROM orders o
    JOIN order_items i ON i.order_id = o.order_id
    GROUP BY o.order_id
),
customer_groups AS (
    SELECT customer_unique_id, COUNT(*) AS n,
           COUNT(DISTINCT customer_state) AS state_cnt,
           COUNT(DISTINCT customer_city) AS city_cnt
    FROM customers
    GROUP BY customer_unique_id
    HAVING COUNT(*) > 1
),
metrics AS (
    SELECT 'K01' AS rule_id, 'consistency' AS dimension,
           '订单金额勾稽不一致（items 总额 vs payments 总额，容差 0.01）' AS rule_name,
           (SELECT COUNT(*) FROM totals WHERE pay_total IS NOT NULL AND ABS(item_total - pay_total) > 0.01) AS numerator,
           (SELECT COUNT(*) FROM totals WHERE pay_total IS NOT NULL) AS denominator
    UNION ALL
    SELECT 'K02', 'consistency', '审批时间早于下单时间',
           COUNT(*) FILTER (WHERE order_approved_at < order_purchase_timestamp),
           COUNT(*) FILTER (WHERE order_approved_at IS NOT NULL AND order_purchase_timestamp IS NOT NULL)
    FROM orders
    UNION ALL
    SELECT 'K03', 'consistency', '签收时间早于承运商揽收时间',
           COUNT(*) FILTER (WHERE order_delivered_customer_date < order_delivered_carrier_date),
           COUNT(*) FILTER (WHERE order_delivered_customer_date IS NOT NULL AND order_delivered_carrier_date IS NOT NULL)
    FROM orders
    UNION ALL
    SELECT 'K04', 'consistency', '状态与签收时间冲突（delivered 无签收 / canceled 有签收）',
           COUNT(*) FILTER (
               WHERE (order_status = 'delivered' AND order_delivered_customer_date IS NULL)
                  OR (order_status = 'canceled' AND order_delivered_customer_date IS NOT NULL)
           ),
           COUNT(*)
    FROM orders
    WHERE order_status IN ('delivered', 'canceled')
    UNION ALL
    SELECT 'K05', 'consistency', '同一 customer_unique_id 多记录的城市/州冲突',
           COUNT(*) FILTER (WHERE state_cnt > 1 OR city_cnt > 1),
           COUNT(*)
    FROM customer_groups
    UNION ALL
    SELECT 'K06', 'consistency', '评价答复时间早于评价创建时间',
           COUNT(*) FILTER (WHERE review_answer_timestamp < review_creation_date),
           COUNT(*) FILTER (WHERE review_answer_timestamp IS NOT NULL AND review_creation_date IS NOT NULL)
    FROM reviews
)
SELECT rule_id, dimension, rule_name, numerator, denominator,
       ROUND(100.0 * numerator / NULLIF(denominator, 0), 4) AS violation_rate_pct
FROM metrics
ORDER BY rule_id;

-- 补充诊断 1：订单金额勾稽差异分布（报告第 6 节引用）
WITH totals AS (
    SELECT o.order_id,
           SUM(COALESCE(i.price, 0) + COALESCE(i.freight_value, 0)) AS item_total,
           (SELECT SUM(p.payment_value) FROM payments p WHERE p.order_id = o.order_id) AS pay_total
    FROM orders o
    JOIN order_items i ON i.order_id = o.order_id
    GROUP BY o.order_id
)
SELECT CASE
           WHEN pay_total IS NULL THEN 'no_payment_record'
           WHEN ABS(item_total - pay_total) <= 0.01 THEN 'matched_le_0.01'
           WHEN ABS(item_total - pay_total) <= 1 THEN 'diff_0.01_1'
           WHEN ABS(item_total - pay_total) <= 10 THEN 'diff_1_10'
           WHEN ABS(item_total - pay_total) <= 100 THEN 'diff_10_100'
           ELSE 'diff_gt_100'
       END AS diff_bucket,
       COUNT(*) AS order_count,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 4) AS pct_of_orders_with_items,
       ROUND(SUM(ABS(item_total - pay_total)), 2) AS abs_diff_sum
FROM totals
GROUP BY diff_bucket
ORDER BY order_count DESC;

-- 补充诊断 2：金额不一致订单的构成（方向、支付笔数、voucher、明细数、差额）
WITH totals AS (
    SELECT o.order_id,
           SUM(COALESCE(i.price, 0) + COALESCE(i.freight_value, 0)) AS item_total,
           (SELECT SUM(p.payment_value) FROM payments p WHERE p.order_id = o.order_id) AS pay_total
    FROM orders o
    JOIN order_items i ON i.order_id = o.order_id
    GROUP BY o.order_id
),
mismatch AS (
    SELECT * FROM totals
    WHERE pay_total IS NOT NULL AND ABS(item_total - pay_total) > 0.01
),
payment_stats AS (
    SELECT order_id,
           COUNT(*) AS payment_rows,
           COUNT(*) FILTER (WHERE payment_type = 'voucher') AS voucher_rows
    FROM payments
    GROUP BY order_id
),
item_stats AS (
    SELECT order_id, COUNT(*) AS item_rows FROM order_items GROUP BY order_id
)
SELECT COUNT(*) AS mismatch_orders,
       COUNT(*) FILTER (WHERE m.item_total > m.pay_total) AS item_exceeds_payment,
       COUNT(*) FILTER (WHERE m.item_total < m.pay_total) AS payment_exceeds_item,
       COUNT(*) FILTER (WHERE ps.payment_rows > 1) AS multi_payment_orders,
       COUNT(*) FILTER (WHERE ps.voucher_rows > 0) AS orders_with_voucher,
       COUNT(*) FILTER (WHERE its.item_rows > 1) AS multi_item_orders,
       ROUND(SUM(ABS(m.item_total - m.pay_total)), 2) AS total_abs_diff,
       ROUND(MAX(ABS(m.item_total - m.pay_total)), 2) AS max_abs_diff
FROM mismatch m
JOIN payment_stats ps ON ps.order_id = m.order_id
JOIN item_stats its ON its.order_id = m.order_id;
