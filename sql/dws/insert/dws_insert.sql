-- ===================================================
-- DWS 层数据装载：汇总层 ETL
-- 参数：${do_date} — 日期，格式 yyyy-MM-dd
-- ===================================================

-- ===================================================
-- 一、一日汇总表（1d）— 从 DWD 层聚合
-- ===================================================

-- -------------------------------------------------
-- 1. 交易域用户商品粒度订单最近1日汇总表
-- 来源：dwd_trade_order_detail_inc + dim_sku_full
-- -------------------------------------------------
INSERT OVERWRITE TABLE gmall.dws_trade_user_sku_order_1d PARTITION (dt = '${do_date}')
SELECT
    `user_id`,
    `sku_id`,
    `sku_name`,
    `category1_id`,
    `category1_name`,
    `category2_id`,
    `category2_name`,
    `category3_id`,
    `category3_name`,
    `tm_id`,
    `tm_name`,
    `order_count_1d`,
    `order_num_1d`,
    `order_original_amount_1d`,
    `activity_reduce_amount_1d`,
    `coupon_reduce_amount_1d`,
    `order_total_amount_1d`
FROM (
    SELECT
        user_id,
        sku_id,
        count(*) order_count_1d,
        sum(sku_num) order_num_1d,
        sum(split_original_amount) order_original_amount_1d,
        sum(nvl(split_activity_amount, 0.0)) activity_reduce_amount_1d,
        sum(nvl(split_coupon_amount, 0.0)) coupon_reduce_amount_1d,
        sum(split_total_amount) order_total_amount_1d
    FROM gmall.dwd_trade_order_detail_inc
    WHERE dt = '${do_date}'
    GROUP BY user_id, sku_id
) od
LEFT JOIN (
    SELECT
        id,
        sku_name,
        tm_id,
        tm_name,
        category1_id,
        category1_name,
        category2_id,
        category2_name,
        category3_id,
        category3_name
    FROM gmall.dim_sku_full
    WHERE dt = '${do_date}'
) sku ON od.sku_id = sku.id;

-- -------------------------------------------------
-- 2. 交易域用户粒度订单最近1日汇总表
-- 来源：dwd_trade_order_detail_inc
-- -------------------------------------------------
INSERT OVERWRITE TABLE gmall.dws_trade_user_order_1d PARTITION (dt = '${do_date}')
SELECT
    user_id,
    count(DISTINCT order_id),
    sum(sku_num),
    sum(split_original_amount),
    sum(nvl(split_activity_amount, 0.0)),
    sum(nvl(split_coupon_amount, 0.0)),
    sum(split_total_amount)
FROM gmall.dwd_trade_order_detail_inc
WHERE dt = '${do_date}'
GROUP BY user_id;

-- -------------------------------------------------
-- 3. 交易域用户粒度加购最近1日汇总表
-- 来源：dwd_trade_cart_add_inc
-- -------------------------------------------------
INSERT OVERWRITE TABLE gmall.dws_trade_user_cart_add_1d PARTITION (dt = '${do_date}')
SELECT
    user_id,
    count(*),
    sum(sku_num)
FROM gmall.dwd_trade_cart_add_inc
WHERE dt = '${do_date}'
GROUP BY user_id;

-- -------------------------------------------------
-- 4. 交易域用户粒度支付最近1日汇总表
-- 来源：dwd_trade_pay_detail_suc_inc
-- -------------------------------------------------
INSERT OVERWRITE TABLE gmall.dws_trade_user_payment_1d PARTITION (dt = '${do_date}')
SELECT
    user_id,
    count(DISTINCT order_id),
    sum(sku_num),
    sum(split_payment_amount)
FROM gmall.dwd_trade_pay_detail_suc_inc
WHERE dt = '${do_date}'
GROUP BY user_id;

-- -------------------------------------------------
-- 5. 交易域省份粒度订单最近1日汇总表
-- 来源：dwd_trade_order_detail_inc + dim_province_full
-- -------------------------------------------------
INSERT OVERWRITE TABLE gmall.dws_trade_province_order_1d PARTITION (dt = '${do_date}')
SELECT
    `province_id`,
    `province_name`,
    `area_code`,
    `iso_code`,
    `iso_3166_2`,
    `order_count_1d`,
    `order_original_amount_1d`,
    `activity_reduce_amount_1d`,
    `coupon_reduce_amount_1d`,
    `order_total_amount_1d`
FROM (
    SELECT
        province_id,
        count(DISTINCT order_id) AS order_count_1d,
        sum(split_original_amount) AS order_original_amount_1d,
        sum(nvl(split_activity_amount, 0.0)) AS activity_reduce_amount_1d,
        sum(nvl(split_coupon_amount, 0.0)) AS coupon_reduce_amount_1d,
        sum(split_total_amount) AS order_total_amount_1d
    FROM gmall.dwd_trade_order_detail_inc
    WHERE dt = '${do_date}'
    GROUP BY province_id
) od
LEFT JOIN (
    SELECT id, `province_name`, `area_code`, `iso_code`, `iso_3166_2`
    FROM gmall.dim_province_full
    WHERE dt = '${do_date}'
) prv ON od.province_id = prv.id;

-- -------------------------------------------------
-- 6. 工具域用户优惠券粒度优惠券使用(支付)最近1日汇总表
-- 来源：dwd_tool_coupon_used_inc + dim_coupon_full
-- -------------------------------------------------
INSERT OVERWRITE TABLE gmall.dws_tool_user_coupon_coupon_used_1d PARTITION (dt = '${do_date}')
SELECT
    `user_id`,
    `coupon_id`,
    `coupon_name`,
    `coupon_type_code`,
    `coupon_type_name`,
    `benefit_rule`,
    `used_count_1d`
FROM (
    SELECT
        user_id,
        coupon_id,
        count(*) used_count_1d
    FROM gmall.dwd_tool_coupon_used_inc
    WHERE dt = '${do_date}'
    GROUP BY user_id, coupon_id
) cu
LEFT JOIN (
    SELECT id, coupon_name, coupon_type_code, coupon_type_name, benefit_rule
    FROM gmall.dim_coupon_full
    WHERE dt = '${do_date}'
) cp ON cu.coupon_id = cp.id;

-- -------------------------------------------------
-- 7. 互动域商品粒度收藏商品最近1日汇总表
-- 来源：dwd_interaction_favor_add_inc + dim_sku_full
-- -------------------------------------------------
INSERT OVERWRITE TABLE gmall.dws_interaction_sku_favor_add_1d PARTITION (dt = '${do_date}')
SELECT
    `sku_id`,
    `sku_name`,
    `category1_id`,
    `category1_name`,
    `category2_id`,
    `category2_name`,
    `category3_id`,
    `category3_name`,
    `tm_id`,
    `tm_name`,
    `favor_add_count_1d`
FROM (
    SELECT
        sku_id,
        count(*) favor_add_count_1d
    FROM gmall.dwd_interaction_favor_add_inc
    WHERE dt = '${do_date}'
    GROUP BY sku_id
) fa
LEFT JOIN (
    SELECT id, `sku_name`, `category1_id`, `category1_name`, `category2_id`, `category2_name`, `category3_id`, `category3_name`, `tm_id`, `tm_name`
    FROM gmall.dim_sku_full
    WHERE dt = '${do_date}'
) sku ON fa.sku_id = sku.id;

-- -------------------------------------------------
-- 8. 流量域会话粒度页面浏览最近1日汇总表
-- 来源：dwd_traffic_page_view_inc
-- -------------------------------------------------
INSERT OVERWRITE TABLE gmall.dws_traffic_session_page_view_1d PARTITION (dt = '${do_date}')
SELECT
    `session_id`,
    `mid_id`,
    `brand`,
    `model`,
    `operate_system`,
    `version_code`,
    `channel`,
    sum(during_time) `during_time_1d`,
    count(*) `page_count_1d`
FROM gmall.dwd_traffic_page_view_inc
WHERE dt = '${do_date}'
GROUP BY session_id, mid_id, brand, model, operate_system, version_code, channel;

-- -------------------------------------------------
-- 9. 流量域访客页面粒度页面浏览最近1日汇总表
-- 来源：dwd_traffic_page_view_inc
-- -------------------------------------------------
INSERT OVERWRITE TABLE gmall.dws_traffic_page_visitor_page_view_1d PARTITION (dt = '${do_date}')
SELECT
    mid_id,
    brand,
    model,
    operate_system,
    page_id,
    sum(during_time),
    count(*)
FROM gmall.dwd_traffic_page_view_inc
WHERE dt = '${do_date}'
GROUP BY mid_id, brand, model, operate_system, page_id;

-- ===================================================
-- N日汇总（nd）和历史至今汇总（td）
-- 由独立脚本 dws_1d_to_dws_nd.sh 和 dws_1d_to_dws_td.sh 执行
-- 避免在同一 SQL 文件中重复执行
-- ===================================================
