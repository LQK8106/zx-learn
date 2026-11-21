"""Olist 数据质量评估执行器。

用法：
    python run_dq.py

前置：data/ 下已放置 8 个 Olist CSV；首次运行会创建 olist.duckdb 并装载原始表。
说明：CSV 先以全 VARCHAR 装入 *_raw 表，再建立带类型转换的视图；
      这样既保留原始值，又能在 SQL 中做日期/数值校验。
"""
import csv
import os
import sys

import duckdb

ROOT = os.path.dirname(os.path.abspath(__file__))
DB = os.path.join(ROOT, "olist.duckdb")
SQL_DIR = os.path.join(ROOT, "sql")
RESULT_DIR = os.path.join(ROOT, "result")

TABLES = {
    "customers": "olist_customers_dataset.csv",
    "orders": "olist_orders_dataset.csv",
    "order_items": "olist_order_items_dataset.csv",
    "payments": "olist_order_payments_dataset.csv",
    "reviews": "olist_order_reviews_dataset.csv",
    "products": "olist_products_dataset.csv",
    "sellers": "olist_sellers_dataset.csv",
    "category_translation": "product_category_name_translation.csv",
}

VIEWS = [
    """CREATE OR REPLACE VIEW orders AS SELECT order_id, customer_id, order_status,
       TRY_CAST(order_purchase_timestamp AS TIMESTAMP) AS order_purchase_timestamp,
       TRY_CAST(order_approved_at AS TIMESTAMP) AS order_approved_at,
       TRY_CAST(order_delivered_carrier_date AS TIMESTAMP) AS order_delivered_carrier_date,
       TRY_CAST(order_delivered_customer_date AS TIMESTAMP) AS order_delivered_customer_date,
       TRY_CAST(order_estimated_delivery_date AS TIMESTAMP) AS order_estimated_delivery_date
       FROM orders_raw""",
    """CREATE OR REPLACE VIEW order_items AS SELECT order_id,
       TRY_CAST(order_item_id AS INTEGER) AS order_item_id, product_id, seller_id,
       TRY_CAST(shipping_limit_date AS TIMESTAMP) AS shipping_limit_date,
       TRY_CAST(price AS DECIMAL(12,2)) AS price,
       TRY_CAST(freight_value AS DECIMAL(12,2)) AS freight_value
       FROM order_items_raw""",
    """CREATE OR REPLACE VIEW payments AS SELECT order_id,
       TRY_CAST(payment_sequential AS INTEGER) AS payment_sequential, payment_type,
       TRY_CAST(payment_installments AS INTEGER) AS payment_installments,
       TRY_CAST(payment_value AS DECIMAL(12,2)) AS payment_value
       FROM payments_raw""",
    """CREATE OR REPLACE VIEW reviews AS SELECT review_id, order_id,
       TRY_CAST(review_score AS INTEGER) AS review_score, review_comment_title,
       review_comment_message,
       TRY_CAST(review_creation_date AS TIMESTAMP) AS review_creation_date,
       TRY_CAST(review_answer_timestamp AS TIMESTAMP) AS review_answer_timestamp
       FROM reviews_raw""",
    """CREATE OR REPLACE VIEW products AS SELECT product_id, product_category_name,
       TRY_CAST(product_name_lenght AS INTEGER) AS product_name_length,
       TRY_CAST(product_description_lenght AS INTEGER) AS product_description_length,
       TRY_CAST(product_photos_qty AS INTEGER) AS product_photos_qty,
       TRY_CAST(product_weight_g AS INTEGER) AS product_weight_g,
       TRY_CAST(product_length_cm AS INTEGER) AS product_length_cm,
       TRY_CAST(product_height_cm AS INTEGER) AS product_height_cm,
       TRY_CAST(product_width_cm AS INTEGER) AS product_width_cm
       FROM products_raw""",
    """CREATE OR REPLACE VIEW customers AS SELECT customer_id, customer_unique_id,
       customer_zip_code_prefix, customer_city, customer_state
       FROM customers_raw""",
    """CREATE OR REPLACE VIEW sellers AS SELECT seller_id, seller_zip_code_prefix,
       seller_city, seller_state FROM sellers_raw""",
    """CREATE OR REPLACE VIEW category_translation AS SELECT product_category_name,
       product_category_name_english FROM category_translation_raw""",
]

DIM_WEIGHTS = {
    "completeness": 0.25,
    "consistency": 0.25,
    "uniqueness": 0.15,
    "accuracy": 0.10,
    "validity": 0.15,
}


def load_raw(con):
    missing = []
    for name, filename in TABLES.items():
        path = os.path.join(ROOT, "data", filename)
        if not os.path.exists(path):
            missing.append(filename)
    if missing:
        print("缺少数据文件：" + ", ".join(missing))
        sys.exit(1)
    for name, filename in TABLES.items():
        path = os.path.join(ROOT, "data", filename).replace("\\", "/")
        con.execute(
            f"CREATE OR REPLACE TABLE {name}_raw AS "
            f"SELECT * FROM read_csv_auto('{path}', header=true, all_varchar=true)"
        )
    for view in VIEWS:
        con.execute(view)


def write_csv(path, columns, rows):
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(columns)
        for row in rows:
            writer.writerow(["" if value is None else value for value in row])


def run_sql_files(con):
    os.makedirs(RESULT_DIR, exist_ok=True)
    for old in os.listdir(RESULT_DIR):
        if old.endswith(".csv"):
            os.remove(os.path.join(RESULT_DIR, old))
    for filename in sorted(os.listdir(SQL_DIR)):
        if not filename.endswith(".sql"):
            continue
        path = os.path.join(SQL_DIR, filename)
        with open(path, "r", encoding="utf-8") as f:
            text = f.read()
        statements = duckdb.extract_statements(text)
        stem = os.path.splitext(filename)[0]
        for index, statement in enumerate(statements, start=1):
            result = con.execute(statement.query)
            columns = [desc[0] for desc in result.description]
            rows = result.fetchall()
            suffix = "" if index == 1 else f"-{index}"
            out_path = os.path.join(RESULT_DIR, f"{stem}{suffix}.csv")
            write_csv(out_path, columns, rows)
            print(f"{filename} [{index}/{len(statements)}] -> {out_path} ({len(rows)} rows)")


def read_dimension_csv(name):
    path = os.path.join(RESULT_DIR, f"{name}.csv")
    if not os.path.exists(path):
        return []
    with open(path, "r", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def compute_scores():
    summary = []
    for dimension, weight in DIM_WEIGHTS.items():
        rows = read_dimension_csv(
            {
                "completeness": "01-completeness",
                "consistency": "02-consistency",
                "uniqueness": "03-uniqueness",
                "accuracy": "04-accuracy",
                "validity": "06-validity",
            }[dimension]
        )
        rates = []
        for row in rows:
            value = row.get("violation_rate_pct", "")
            if value not in ("", None):
                rates.append(float(value))
        mean_rate = sum(rates) / len(rates) if rates else None
        score = None if mean_rate is None else round(100 - mean_rate, 2)
        summary.append(
            {
                "dimension": dimension,
                "rule_count": len(rows),
                "mean_violation_pct": "" if mean_rate is None else round(mean_rate, 4),
                "score": "" if score is None else score,
                "weight": weight,
            }
        )

    total_weight = sum(item["weight"] for item in summary if item["score"] != "")
    composite = None
    if total_weight:
        composite = round(
            sum(item["score"] * item["weight"] for item in summary if item["score"] != "")
            / total_weight,
            2,
        )
    summary.append(
        {
            "dimension": "timeliness",
            "rule_count": 0,
            "mean_violation_pct": "N/A",
            "score": "N/A",
            "weight": 0.10,
        }
    )
    summary.append(
        {
            "dimension": "COMPOSITE (timeliness excluded, weights renormalized)",
            "rule_count": sum(item["rule_count"] for item in summary),
            "mean_violation_pct": "",
            "score": "" if composite is None else composite,
            "weight": round(total_weight, 2),
        }
    )
    write_csv(
        os.path.join(RESULT_DIR, "score-summary.csv"),
        ["dimension", "rule_count", "mean_violation_pct", "score", "weight"],
        [[item[key] for key in ["dimension", "rule_count", "mean_violation_pct", "score", "weight"]] for item in summary],
    )
    print(f"\n综合得分（及时性不评分，权重归一化）: {composite}")


def main():
    con = duckdb.connect(DB)
    load_raw(con)
    run_sql_files(con)
    compute_scores()
    con.close()


if __name__ == "__main__":
    main()
