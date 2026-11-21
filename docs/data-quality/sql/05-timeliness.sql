-- 05 及时性：先证明是否存在入库时间字段；不存在则不强行评分
-- T01 仅为“业务处理时长/快照新鲜度”上下文，不计入及时性得分

SELECT table_name, column_name
FROM information_schema.columns
WHERE table_name IN ('orders_raw', 'payments_raw', 'reviews_raw', 'order_items_raw')
  AND (
      LOWER(column_name) LIKE '%ingest%'
      OR LOWER(column_name) LIKE '%load%'
      OR LOWER(column_name) LIKE '%etl%'
      OR LOWER(column_name) LIKE '%created_at%'
      OR LOWER(column_name) LIKE '%updated_at%'
  )
ORDER BY table_name, column_name;

SELECT (SELECT MAX(order_purchase_timestamp) FROM orders) AS max_order_ts,
       (SELECT DATE_DIFF('day', MAX(order_purchase_timestamp), TIMESTAMP '2026-11-21 00:00:00') FROM orders) AS days_stale,
       COUNT(*) AS approved_orders,
       ROUND(AVG(DATE_DIFF('second', order_purchase_timestamp, order_approved_at) / 3600.0), 2) AS mean_approval_hours,
       ROUND(quantile_cont(DATE_DIFF('second', order_purchase_timestamp, order_approved_at) / 3600.0, 0.5), 2) AS p50_approval_hours,
       ROUND(quantile_cont(DATE_DIFF('second', order_purchase_timestamp, order_approved_at) / 3600.0, 0.95), 2) AS p95_approval_hours,
       SUM(CASE WHEN DATE_DIFF('second', order_purchase_timestamp, order_approved_at) > 86400 THEN 1 ELSE 0 END) AS approval_over_24h
FROM orders
WHERE order_approved_at IS NOT NULL
  AND order_purchase_timestamp IS NOT NULL;
