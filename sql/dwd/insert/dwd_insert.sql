-- ===================================================
-- DWD 层数据装载：明细层 ETL
-- 参数：${do_date} — 日期，格式 yyyy-MM-dd
-- 核心处理：JSON 解析、维度退化、字段统一、数据清洗
-- ===================================================

-- ----------------------------
-- 页面浏览明细 ETL
-- 从 JSON 字符串解析为结构化列
-- ----------------------------
INSERT OVERWRITE TABLE gmall.dwd_traffic_page_log_inc PARTITION (dt = '${do_date}')
SELECT
    GET_JSON_OBJECT(common, '$.ar')          AS province_id,
    GET_JSON_OBJECT(common, '$.ba')          AS brand,
    GET_JSON_OBJECT(common, '$.ch')          AS channel,
    GET_JSON_OBJECT(common, '$.is_new')     AS is_new,
    GET_JSON_OBJECT(common, '$.md')          AS model,
    GET_JSON_OBJECT(common, '$.mid')         AS mid,
    GET_JSON_OBJECT(common, '$.os')          AS operate_system,
    GET_JSON_OBJECT(common, '$.uid')         AS user_id,
    GET_JSON_OBJECT(common, '$.vc')          AS version_code,
    CAST(GET_JSON_OBJECT(page, '$.during_time') AS BIGINT) AS during_time,
    GET_JSON_OBJECT(page, '$.item')          AS page_item,
    GET_JSON_OBJECT(page, '$.item_type')    AS page_item_type,
    GET_JSON_OBJECT(page, '$.last_page_id')  AS last_page_id,
    GET_JSON_OBJECT(page, '$.page_id')       AS page_id,
    GET_JSON_OBJECT(page, '$.from_pos_id')   AS from_pos_id,
    GET_JSON_OBJECT(page, '$.from_pos_seq')  AS from_pos_seq,
    GET_JSON_OBJECT(page, '$.refer_id')      AS refer_id,
    GET_JSON_OBJECT(page, '$.sourceType')    AS source_type,
    GET_JSON_OBJECT(common, '$.sid')         AS session_id,
    CAST(ts AS BIGINT)                       AS ts
FROM gmall.ods_log_inc
WHERE dt = '${do_date}'
  AND page IS NOT NULL
  AND GET_JSON_OBJECT(page, '$.page_id') IS NOT NULL;

-- ----------------------------
-- 下单明细 ETL
-- 关联 ODS 订单信息 + 订单明细，维度退化省份ID
-- ----------------------------
INSERT OVERWRITE TABLE gmall.dwd_trade_order_detail_inc PARTITION (dt = '${do_date}')
SELECT
    od.id,
    od.order_id,
    oi.user_id,
    od.sku_id,
    od.sku_name,
    oi.province_id,
    CAST(od.order_price AS DECIMAL(16,2))              AS order_price,
    CAST(od.sku_num AS BIGINT)                          AS sku_num,
    CAST(oi.total_amount AS DECIMAL(16,2))              AS total_amount,
    CAST(COALESCE(oi.activity_reduce_amount, '0') AS DECIMAL(16,2)) AS activity_reduce_amount,
    CAST(COALESCE(oi.coupon_reduce_amount, '0') AS DECIMAL(16,2))   AS coupon_reduce_amount,
    CAST(oi.original_total_amount AS DECIMAL(16,2))     AS original_total_amount,
    CAST(COALESCE(oi.feight_fee, '0') AS DECIMAL(16,2)) AS feight_fee,
    CAST(od.split_total_amount AS DECIMAL(16,2))        AS split_total_amount,
    od.create_time
FROM (
    SELECT
        data.id,
        data.order_id,
        data.sku_id,
        data.sku_name,
        data.order_price,
        data.sku_num,
        data.split_total_amount,
        data.create_time
    FROM gmall.ods_order_detail_inc
    WHERE dt = '${do_date}'
      AND type = 'insert'
) od
JOIN (
    SELECT
        data.id,
        data.user_id,
        data.province_id,
        data.total_amount,
        data.activity_reduce_amount,
        data.coupon_reduce_amount,
        data.original_total_amount,
        data.feight_fee
    FROM gmall.ods_order_info_inc
    WHERE dt = '${do_date}'
      AND type = 'insert'
) oi
ON od.order_id = oi.id;

-- ----------------------------
-- 支付明细 ETL
-- ----------------------------
INSERT OVERWRITE TABLE gmall.dwd_trade_pay_detail_inc PARTITION (dt = '${do_date}')
SELECT
    data.id,
    data.order_id,
    data.user_id,
    data.payment_type,
    data.trade_no,
    CAST(data.total_amount AS DECIMAL(16,2)) AS total_amount,
    data.payment_status,
    data.callback_time,
    data.create_time
FROM gmall.ods_payment_info_inc
WHERE dt = '${do_date}'
  AND type = 'insert';

-- ----------------------------
-- 加购明细 ETL
-- ----------------------------
INSERT OVERWRITE TABLE gmall.dwd_trade_cart_add_inc PARTITION (dt = '${do_date}')
SELECT
    data.id,
    data.user_id,
    data.sku_id,
    CAST(data.cart_price AS DECIMAL(16,2)) AS cart_price,
    CAST(data.sku_num AS BIGINT)           AS sku_num,
    data.sku_name,
    data.create_time
FROM gmall.ods_cart_info_inc
WHERE dt = '${do_date}'
  AND type = 'insert';
