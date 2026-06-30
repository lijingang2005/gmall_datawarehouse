-- ===================================================
-- DWS 层数据装载：汇总层 ETL
-- 参数：${do_date} — 日期，格式 yyyy-MM-dd
-- ===================================================

-- ----------------------------
-- 流量域：会话粒度 1 日汇总
-- 来源：dwd_traffic_page_log_inc
-- 粒度：会话（session_id）
-- ----------------------------
INSERT OVERWRITE TABLE gmall.dws_traffic_session_page_view_1d PARTITION (dt = '${do_date}')
SELECT
    mid,
    MAX(user_id)                          AS user_id,
    MAX(province_id)                      AS province_id,
    MAX(channel)                          AS channel,
    MAX(is_new)                           AS is_new,
    MAX(version_code)                     AS version_code,
    SUM(during_time) / 1000               AS during_time_sec,
    COUNT(*)                              AS page_count,
    session_id
FROM gmall.dwd_traffic_page_log_inc
WHERE dt = '${do_date}'
GROUP BY mid, session_id;

-- ----------------------------
-- 交易域：订单粒度 1 日汇总
-- 来源：dwd_trade_order_detail_inc + dim_sku（维度关联获取品牌/品类）
-- ----------------------------
INSERT OVERWRITE TABLE gmall.dws_trade_order_1d PARTITION (dt = '${do_date}')
SELECT
    od.order_id,
    od.user_id,
    od.sku_id,
    od.sku_name,
    sku.tm_id,
    sku.tm_name,
    sku.category1_id,
    sku.category1_name,
    sku.category2_id,
    sku.category2_name,
    sku.category3_id,
    sku.category3_name,
    od.province_id,
    od.order_price,
    od.sku_num,
    od.split_total_amount,
    od.activity_reduce_amount,
    od.coupon_reduce_amount,
    od.original_total_amount
FROM gmall.dwd_trade_order_detail_inc od
LEFT JOIN gmall.dim_sku sku
    ON od.sku_id = sku.id
   AND sku.dt = '${do_date}'
WHERE od.dt = '${do_date}';
