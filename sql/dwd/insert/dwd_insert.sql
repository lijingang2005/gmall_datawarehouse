-- ===================================================
-- DWD 层数据装载：明细层 ETL
-- 参数：${do_date} — 日期，格式 yyyy-MM-dd
-- ===================================================

-- -------------------------------------------------
-- 1. 交易域加购事务事实表 ETL
-- 首日：bootstrap-insert 全部视为加购，动态分区
-- 每日：insert → 加购；update 且 sku_num 增加 → 加购
-- -------------------------------------------------
-- 首日数据装载（仅首次执行，type='bootstrap-insert'）
-- set hive.exec.dynamic.partition.mode=nonstrict;
-- INSERT OVERWRITE TABLE gmall.dwd_trade_cart_add_inc PARTITION (dt)
-- SELECT
--     data.`id`,
--     data.`user_id`,
--     data.`sku_id`,
--     date_format(data.`create_time`, 'yyyy-MM-dd') `date_id`,
--     data.`create_time`,
--     data.`sku_num`,
--     date_format(data.`create_time`, 'yyyy-MM-dd')
-- FROM gmall.ods_cart_info_inc
-- WHERE dt = '${do_date}'
--   AND type = 'bootstrap-insert';

-- 每日数据装载
INSERT OVERWRITE TABLE gmall.dwd_trade_cart_add_inc PARTITION (dt = '${do_date}')
SELECT
    data.`id`,
    data.`user_id`,
    data.`sku_id`,
    date_format(IF(type = 'insert', data.`create_time`, data.operate_time), 'yyyy-MM-dd') `date_id`,
    IF(type = 'insert', data.`create_time`, data.operate_time) create_time,
    IF(type = 'insert', data.`sku_num`, data.sku_num - CAST(old['sku_num'] AS BIGINT)) sku_num
FROM gmall.ods_cart_info_inc
WHERE dt = '${do_date}'
  AND (
    type = 'insert'
    OR (
      type = 'update'
      AND array_contains(map_keys(old), 'sku_num')
      AND data.sku_num > CAST(old['sku_num'] AS BIGINT)
    )
  );

-- -------------------------------------------------
-- 2. 交易域下单事务事实表 ETL
-- 关联 4 张表：order_detail + order_info + order_detail_coupon + order_detail_activity
-- 首日：bootstrap-insert，动态分区
-- 每日：insert，静态分区
-- -------------------------------------------------
-- 首日数据装载
-- set hive.exec.dynamic.partition.mode=nonstrict;
-- INSERT OVERWRITE TABLE gmall.dwd_trade_order_detail_inc PARTITION (dt)
-- SELECT
--     od.`id`,
--     `order_id`,
--     `user_id`,
--     `sku_id`,
--     `province_id`,
--     `activity_id`,
--     `activity_rule_id`,
--     `coupon_id`,
--     `date_id`,
--     `create_time`,
--     `sku_num`,
--     `split_original_amount`,
--     `split_activity_amount`,
--     `split_coupon_amount`,
--     `split_total_amount`,
--     date_id
-- FROM (
--     SELECT
--         data.`id`,
--         data.`order_id`,
--         data.`sku_id`,
--         data.`sku_num`,
--         data.order_price * data.`sku_num` AS split_original_amount,
--         nvl(data.`split_activity_amount`, 0.0) split_activity_amount,
--         nvl(data.`split_coupon_amount`, 0.0) split_coupon_amount,
--         data.`split_total_amount`
--     FROM gmall.ods_order_detail_inc
--     WHERE dt = '${do_date}' AND type = 'bootstrap-insert'
-- ) od
-- LEFT JOIN (
--     SELECT
--         data.id,
--         data.`user_id`,
--         data.`province_id`,
--         date_format(data.`create_time`, 'yyyy-MM-dd') `date_id`,
--         data.`create_time`
--     FROM gmall.ods_order_info_inc
--     WHERE dt = '${do_date}' AND type = 'bootstrap-insert'
-- ) oi ON od.order_id = oi.id
-- LEFT JOIN (
--     SELECT data.order_detail_id, data.`coupon_id`
--     FROM gmall.ods_order_detail_coupon_inc
--     WHERE dt = '${do_date}' AND type = 'bootstrap-insert'
-- ) coupon ON od.id = coupon.order_detail_id
-- LEFT JOIN (
--     SELECT data.order_detail_id, data.`activity_id`, data.`activity_rule_id`
--     FROM gmall.ods_order_detail_activity_inc
--     WHERE dt = '${do_date}' AND type = 'bootstrap-insert'
-- ) act ON od.id = act.order_detail_id;

-- 每日数据装载
INSERT OVERWRITE TABLE gmall.dwd_trade_order_detail_inc PARTITION (dt = '${do_date}')
SELECT
    od.`id`,
    `order_id`,
    `user_id`,
    `sku_id`,
    `province_id`,
    `activity_id`,
    `activity_rule_id`,
    `coupon_id`,
    `date_id`,
    `create_time`,
    `sku_num`,
    `split_original_amount`,
    `split_activity_amount`,
    `split_coupon_amount`,
    `split_total_amount`
FROM (
    SELECT
        data.`id`,
        data.`order_id`,
        data.`sku_id`,
        data.`sku_num`,
        data.order_price * data.`sku_num` AS split_original_amount,
        nvl(data.`split_activity_amount`, 0.0) split_activity_amount,
        nvl(data.`split_coupon_amount`, 0.0) split_coupon_amount,
        data.`split_total_amount`
    FROM gmall.ods_order_detail_inc
    WHERE dt = '${do_date}' AND type = 'insert'
) od
LEFT JOIN (
    SELECT
        data.id,
        data.`user_id`,
        data.`province_id`,
        date_format(data.`create_time`, 'yyyy-MM-dd') `date_id`,
        data.`create_time`
    FROM gmall.ods_order_info_inc
    WHERE dt = '${do_date}' AND type = 'insert'
) oi ON od.order_id = oi.id
LEFT JOIN (
    SELECT data.order_detail_id, data.`coupon_id`
    FROM gmall.ods_order_detail_coupon_inc
    WHERE dt = '${do_date}' AND type = 'insert'
) coupon ON od.id = coupon.order_detail_id
LEFT JOIN (
    SELECT data.order_detail_id, data.`activity_id`, data.`activity_rule_id`
    FROM gmall.ods_order_detail_activity_inc
    WHERE dt = '${do_date}' AND type = 'insert'
) act ON od.id = act.order_detail_id;

-- -------------------------------------------------
-- 3. 交易域支付成功事务事实表 ETL
-- 关联 6 张表 + 字典表
-- 首日：bootstrap-insert + payment_status='1602'，动态分区
-- 每日：跨天处理（today OR yesterday）+ type='update' + payment_status field changed to '1602'
-- -------------------------------------------------
-- 首日装载（略，同每日逻辑但 type='bootstrap-insert' 且 payment_status='1602'）

-- 每日数据装载（关注跨天支付 + update 类型）
INSERT OVERWRITE TABLE gmall.dwd_trade_pay_detail_suc_inc PARTITION (dt = '${do_date}')
SELECT
    od.`id`,
    od.`order_id`,
    `user_id`,
    `sku_id`,
    `province_id`,
    `activity_id`,
    `activity_rule_id`,
    `coupon_id`,
    `payment_type_code`,
    `payment_type_name`,
    `date_id`,
    `callback_time`,
    `sku_num`,
    `split_original_amount`,
    `split_activity_amount`,
    `split_coupon_amount`,
    `split_payment_amount`
FROM (
    SELECT
        data.`id`,
        data.`order_id`,
        data.`sku_id`,
        data.`sku_num`,
        data.order_price * data.`sku_num` AS split_original_amount,
        nvl(data.`split_activity_amount`, 0.0) split_activity_amount,
        nvl(data.`split_coupon_amount`, 0.0) split_coupon_amount,
        data.`split_total_amount`
    FROM gmall.ods_order_detail_inc
    WHERE (dt = '${do_date}' OR dt = date_sub('${do_date}', 1))
      AND (type = 'insert' OR type = 'bootstrap-insert')
) od
LEFT JOIN (
    SELECT
        data.id,
        data.`user_id`,
        data.`province_id`
    FROM gmall.ods_order_info_inc
    WHERE (dt = '${do_date}' OR dt = date_sub('${do_date}', 1))
      AND (type = 'insert' OR type = 'bootstrap-insert')
) oi ON od.order_id = oi.id
LEFT JOIN (
    SELECT data.order_detail_id, data.`coupon_id`
    FROM gmall.ods_order_detail_coupon_inc
    WHERE (dt = '${do_date}' OR dt = date_sub('${do_date}', 1))
      AND (type = 'insert' OR type = 'bootstrap-insert')
) coupon ON od.id = coupon.order_detail_id
LEFT JOIN (
    SELECT data.order_detail_id, data.`activity_id`, data.`activity_rule_id`
    FROM gmall.ods_order_detail_activity_inc
    WHERE (dt = '${do_date}' OR dt = date_sub('${do_date}', 1))
      AND (type = 'insert' OR type = 'bootstrap-insert')
) act ON od.id = act.order_detail_id
JOIN (
    SELECT
        data.order_id,
        data.payment_type AS payment_type_code,
        data.callback_time AS callback_time,
        data.total_amount AS split_payment_amount,
        date_format(data.callback_time, 'yyyy-MM-dd') AS date_id
    FROM gmall.ods_payment_info_inc
    WHERE dt = '${do_date}'
      AND type = 'update'
      AND array_contains(map_keys(old), 'payment_status')
      AND data.payment_status = '1602'
) pay ON od.order_id = pay.order_id
LEFT JOIN (
    SELECT dic_code, dic_name AS payment_type_name
    FROM gmall.ods_base_dic_full
    WHERE dt = '${do_date}' AND parent_code = '11'
) dic ON pay.payment_type_code = dic.dic_code;

-- -------------------------------------------------
-- 4. 交易域购物车周期快照事实表 ETL
-- 每天全量：取 ods_cart_info_full 中 is_ordered=0 的记录
-- -------------------------------------------------
INSERT OVERWRITE TABLE gmall.dwd_trade_cart_full PARTITION (dt = '${do_date}')
SELECT
    `id`,
    `user_id`,
    `sku_id`,
    `sku_name`,
    `sku_num`
FROM gmall.ods_cart_info_full
WHERE dt = '${do_date}'
  AND is_ordered = '0';

-- -------------------------------------------------
-- 5. 交易域交易流程累积快照事实表 ETL
-- 跟踪：下单→支付→确认收货
-- 首日：bootstrap-insert，动态分区
-- 每日：历史(9999-12-31) + 当日新增，更新支付/收货里程碑
-- -------------------------------------------------
-- 首日装载（略）

-- 每日数据装载
INSERT OVERWRITE TABLE gmall.dwd_trade_trade_flow_acc PARTITION (dt)
SELECT
    oi.`order_id`,
    `user_id`,
    `province_id`,
    `order_date_id`,
    `order_time`,
    IF(pay.payment_time IS NOT NULL, pay.payment_date_id, oi.order_date_id),
    IF(pay.`payment_time` IS NOT NULL, pay.`payment_time`, oi.`payment_time`),
    IF(log.finish_time IS NOT NULL, log.finish_date_id, oi.finish_date_id) `finish_date_id`,
    IF(log.finish_time IS NOT NULL, log.finish_time, oi.finish_time) `finish_time`,
    `order_original_amount`,
    `order_activity_amount`,
    `order_coupon_amount`,
    `order_total_amount`,
    IF(pay.payment_amount IS NOT NULL, pay.payment_amount, oi.payment_amount) `payment_amount`,
    IF(log.finish_date_id IS NOT NULL, log.finish_date_id, '9999-12-31')
FROM (
    -- 历史未完成订单
    SELECT
        `order_id`,
        `user_id`,
        `province_id`,
        `order_date_id`,
        `order_time`,
        `payment_date_id`,
        `payment_time`,
        `finish_date_id`,
        `finish_time`,
        `order_original_amount`,
        `order_activity_amount`,
        `order_coupon_amount`,
        `order_total_amount`,
        `payment_amount`
    FROM gmall.dwd_trade_trade_flow_acc
    WHERE dt = '9999-12-31'
    UNION
    -- 当日新增订单
    SELECT
        data.id `order_id`,
        data.`user_id`,
        data.`province_id`,
        date_format(data.create_time, 'yyyy-MM-dd') `order_date_id`,
        data.create_time `order_time`,
        NULL,
        NULL,
        NULL,
        NULL,
        data.original_total_amount `order_original_amount`,
        data.activity_reduce_amount `order_activity_amount`,
        data.coupon_reduce_amount `order_coupon_amount`,
        data.total_amount `order_total_amount`,
        NULL
    FROM gmall.ods_order_info_inc
    WHERE dt = '${do_date}' AND type = 'insert'
) oi
LEFT JOIN (
    SELECT
        data.order_id,
        date_format(data.callback_time, 'yyyy-MM-dd') payment_date_id,
        data.callback_time payment_time,
        data.total_amount payment_amount
    FROM gmall.ods_payment_info_inc
    WHERE dt = '${do_date}'
      AND type = 'update'
      AND array_contains(map_keys(old), 'payment_status')
      AND data.payment_status = '1602'
) pay ON oi.order_id = pay.order_id
LEFT JOIN (
    SELECT
        data.order_id,
        date_format(data.create_time, 'yyyy-MM-dd') finish_date_id,
        data.create_time finish_time
    FROM gmall.ods_order_status_log_inc
    WHERE dt = '${do_date}' AND data.order_status = '1004'
) log ON oi.order_id = log.order_id;

-- -------------------------------------------------
-- 6. 工具域优惠券使用（支付）事务事实表 ETL
-- 首日：bootstrap-insert + used_time IS NOT NULL，动态分区
-- 每日：type='update' + used_time 字段变更
-- -------------------------------------------------
-- 首日装载（略）

-- 每日数据装载
INSERT OVERWRITE TABLE gmall.dwd_tool_coupon_used_inc PARTITION (dt = '${do_date}')
SELECT
    data.`id`,
    data.`coupon_id`,
    data.`user_id`,
    data.`order_id`,
    date_format(data.used_time, 'yyyy-MM-dd') `date_id`,
    data.`used_time`
FROM gmall.ods_coupon_use_inc
WHERE dt = '${do_date}'
  AND type = 'update'
  AND array_contains(map_keys(old), 'used_time');

-- -------------------------------------------------
-- 7. 互动域收藏商品事务事实表 ETL
-- 首日：bootstrap-insert，动态分区
-- 每日：type='insert'
-- -------------------------------------------------
-- 首日装载（略）

-- 每日数据装载
INSERT OVERWRITE TABLE gmall.dwd_interaction_favor_add_inc PARTITION (dt = '${do_date}')
SELECT
    data.id,
    data.user_id,
    data.sku_id,
    date_format(data.create_time, 'yyyy-MM-dd') date_id,
    data.create_time
FROM gmall.ods_favor_info_inc
WHERE dt = '${do_date}'
  AND type = 'insert';

-- -------------------------------------------------
-- 8. 流量域页面浏览事务事实表 ETL
-- 来源：ods_log_inc（日志数据无历史，首日和每日逻辑相同）
-- 注意：ods_log_inc 使用 JsonSerDe，common/page 已是 STRUCT
-- 关闭 CBO 优化以避免 STRUCT 判空 BUG
-- -------------------------------------------------
set hive.cbo.enable=false;
INSERT OVERWRITE TABLE gmall.dwd_traffic_page_view_inc PARTITION (dt = '${do_date}')
SELECT
    common.ar province_id,
    common.ba brand,
    common.ch channel,
    common.is_new is_new,
    common.md model,
    common.mid mid_id,
    common.os operate_system,
    common.uid user_id,
    common.vc version_code,
    page.item page_item,
    page.item_type page_item_type,
    page.last_page_id,
    page.page_id,
    page.from_pos_id,
    page.from_pos_seq,
    page.refer_id,
    date_format(from_utc_timestamp(ts, 'GMT+8'), 'yyyy-MM-dd') date_id,
    date_format(from_utc_timestamp(ts, 'GMT+8'), 'yyyy-MM-dd HH:mm:ss') view_time,
    common.sid session_id,
    page.during_time
FROM gmall.ods_log_inc
WHERE dt = '${do_date}'
  AND page IS NOT NULL;
set hive.cbo.enable=true;

-- -------------------------------------------------
-- 9. 用户域用户注册事务事实表 ETL
-- 来源：ods_user_info_inc(type='insert') + ods_log_inc(page.page_id='register')
-- 首日：bootstrap-insert，动态分区
-- 每日：type='insert'
-- -------------------------------------------------
-- 首日装载（略）

-- 每日数据装载
INSERT OVERWRITE TABLE gmall.dwd_user_register_inc PARTITION (dt = '${do_date}')
SELECT
    ui.user_id,
    date_format(create_time, 'yyyy-MM-dd') date_id,
    create_time,
    channel,
    province_id,
    version_code,
    mid_id,
    brand,
    model,
    operate_system
FROM (
    SELECT
        data.id user_id,
        data.create_time
    FROM gmall.ods_user_info_inc
    WHERE dt = '${do_date}' AND type = 'insert'
) ui
LEFT JOIN (
    SELECT
        common.ar province_id,
        common.ba brand,
        common.ch channel,
        common.md model,
        common.mid mid_id,
        common.os operate_system,
        common.uid user_id,
        common.vc version_code
    FROM gmall.ods_log_inc
    WHERE dt = '${do_date}'
      AND page.page_id = 'register'
      AND common.uid IS NOT NULL
) log ON ui.user_id = log.user_id;

-- -------------------------------------------------
-- 10. 用户域用户登录事务事实表 ETL
-- 来源：ods_log_inc（uid IS NOT NULL，同一会话按 ts 排序取第一条）
-- 无首日/每日区别（日志数据无历史）
-- -------------------------------------------------
INSERT OVERWRITE TABLE gmall.dwd_user_login_inc PARTITION (dt = '${do_date}')
SELECT
    user_id,
    date_format(from_utc_timestamp(ts, 'GMT+8'), 'yyyy-MM-dd') date_id,
    date_format(from_utc_timestamp(ts, 'GMT+8'), 'yyyy-MM-dd HH:mm:ss') login_time,
    channel,
    province_id,
    version_code,
    mid_id,
    brand,
    model,
    operate_system
FROM (
    SELECT
        user_id,
        channel,
        province_id,
        version_code,
        mid_id,
        brand,
        model,
        operate_system,
        ts
    FROM (
        SELECT
            common.uid user_id,
            common.ch  channel,
            common.ar  province_id,
            common.vc  version_code,
            common.mid mid_id,
            common.ba  brand,
            common.md  model,
            common.os  operate_system,
            ts,
            row_number() OVER (PARTITION BY common.sid ORDER BY ts) rn
        FROM gmall.ods_log_inc
        WHERE dt = '${do_date}'
          AND page IS NOT NULL
          AND common.uid IS NOT NULL
    ) t1
    WHERE rn = 1
) t2;
