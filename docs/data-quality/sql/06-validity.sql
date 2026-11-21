-- 06 有效性：枚举值域、格式规范、日期可解析性、码表对照
-- V04 主口径为“原始 5 位 CEP 前缀”；前导零补齐（LPAD）后的敏感性口径见第 2 条语句

WITH metrics AS (
    SELECT 'V01' AS rule_id, 'validity' AS dimension, 'order_status 不在业务枚举内' AS rule_name,
           COUNT(*) FILTER (
               WHERE order_status IS NULL OR order_status NOT IN
                 ('delivered', 'shipped', 'canceled', 'unavailable', 'invoiced', 'processing', 'created', 'approved')
           ) AS numerator,
           COUNT(*) AS denominator
    FROM orders
    UNION ALL
    SELECT 'V02', 'validity', 'payment_type 不在业务枚举内',
           COUNT(*) FILTER (
               WHERE payment_type IS NULL OR payment_type NOT IN
                 ('credit_card', 'boleto', 'voucher', 'debit_card', 'not_defined')
           ),
           COUNT(*)
    FROM payments
    UNION ALL
    SELECT 'V03', 'validity', 'customer_state 不是巴西 UF 两位代码',
           COUNT(*) FILTER (
               WHERE customer_state IS NULL OR customer_state NOT IN
                 ('AC','AL','AP','AM','BA','CE','DF','ES','GO','MA','MT','MS','MG','PA','PB','PR',
                  'PE','PI','RJ','RN','RS','RO','RR','SC','SP','SE','TO')
           ),
           COUNT(*)
    FROM customers
    UNION ALL
    SELECT 'V04', 'validity', 'customer CEP 前缀不是 5 位数字（原始格式）',
           COUNT(*) FILTER (
               WHERE customer_zip_code_prefix IS NULL
                  OR NOT regexp_matches(TRIM(customer_zip_code_prefix), '^[0-9]{5}$')
           ),
           COUNT(*)
    FROM customers
    UNION ALL
    SELECT 'V05', 'validity', '订单下单时间不可解析',
           COUNT(*) FILTER (
               WHERE TRIM(order_purchase_timestamp) <> ''
                 AND TRY_CAST(order_purchase_timestamp AS TIMESTAMP) IS NULL
           ),
           COUNT(*) FILTER (WHERE TRIM(order_purchase_timestamp) <> '')
    FROM orders_raw
    UNION ALL
    SELECT 'V06', 'validity', '商品类目不在翻译码表中',
           COUNT(*) FILTER (
               WHERE TRIM(p.product_category_name) <> '' AND t.product_category_name IS NULL
           ),
           COUNT(*)
    FROM products p
    LEFT JOIN category_translation t ON t.product_category_name = p.product_category_name
    UNION ALL
    SELECT 'V07', 'validity', 'seller_state 不是巴西 UF 两位代码',
           COUNT(*) FILTER (
               WHERE seller_state IS NULL OR seller_state NOT IN
                 ('AC','AL','AP','AM','BA','CE','DF','ES','GO','MA','MT','MS','MG','PA','PB','PR',
                  'PE','PI','RJ','RN','RS','RO','RR','SC','SP','SE','TO')
           ),
           COUNT(*)
    FROM sellers
)
SELECT rule_id, dimension, rule_name, numerator, denominator,
       ROUND(100.0 * numerator / NULLIF(denominator, 0), 4) AS violation_rate_pct
FROM metrics
ORDER BY rule_id;

SELECT 'V04-canonical' AS rule_id, 'validity' AS dimension,
       'customer CEP 前缀前导零补齐后仍不是 5 位数字（敏感性口径）' AS rule_name,
       COUNT(*) FILTER (
           WHERE customer_zip_code_prefix IS NULL
              OR NOT regexp_matches(LPAD(TRIM(customer_zip_code_prefix), 5, '0'), '^[0-9]{5}$')
       ) AS numerator,
       COUNT(*) AS denominator,
       ROUND(100.0 * COUNT(*) FILTER (
           WHERE customer_zip_code_prefix IS NULL
              OR NOT regexp_matches(LPAD(TRIM(customer_zip_code_prefix), 5, '0'), '^[0-9]{5}$')
       ) / NULLIF(COUNT(*), 0), 4) AS violation_rate_pct
FROM customers;

-- 补充诊断 1：CEP 长度分布（前导零丢失的直接证据）
SELECT entity, cep_len, row_count,
       ROUND(100.0 * row_count / SUM(row_count) OVER (PARTITION BY entity), 4) AS pct
FROM (
    SELECT 'customer' AS entity, LENGTH(TRIM(customer_zip_code_prefix)) AS cep_len, COUNT(*) AS row_count
    FROM customers
    GROUP BY 1, 2
    UNION ALL
    SELECT 'seller', LENGTH(TRIM(seller_zip_code_prefix)), COUNT(*)
    FROM sellers
    GROUP BY 1, 2
)
ORDER BY entity, cep_len;

-- 补充诊断 2：未命中翻译码表的类目明细
SELECT p.product_category_name, COUNT(*) AS product_count
FROM products p
LEFT JOIN category_translation t ON t.product_category_name = p.product_category_name
WHERE TRIM(p.product_category_name) <> '' AND t.product_category_name IS NULL
GROUP BY p.product_category_name
ORDER BY product_count DESC;
