-- ===================================================
-- ADS 层数据装载：应用层 ETL
-- 参数：${do_date} — 日期，格式 yyyy-MM-dd
-- ===================================================

-- ----------------------------
-- 各渠道流量统计
-- 来源：dws_traffic_session_page_view_1d
-- ----------------------------
INSERT OVERWRITE TABLE gmall.ads_traffic_stats_by_channel
SELECT
    '${do_date}'                                     AS dt,
    1                                                  AS recent_days,
    channel,
    COUNT(DISTINCT mid)                               AS uv_count,
    CAST(AVG(during_time_sec) AS BIGINT)              AS avg_duration_sec,
    CAST(AVG(page_count) AS BIGINT)                   AS avg_page_count,
    COUNT(DISTINCT session_id)                        AS sv_count,
    CAST(SUM(IF(page_count = 1, 1, 0)) * 100.0
         / COUNT(DISTINCT session_id) AS DECIMAL(16,2)) AS bounce_rate
FROM gmall.dws_traffic_session_page_view_1d
WHERE dt = '${do_date}'
GROUP BY channel
UNION ALL
-- 7 日汇总
SELECT
    '${do_date}',
    7,
    channel,
    COUNT(DISTINCT mid),
    CAST(AVG(during_time_sec) AS BIGINT),
    CAST(AVG(page_count) AS BIGINT),
    COUNT(DISTINCT session_id),
    CAST(SUM(IF(page_count = 1, 1, 0)) * 100.0
         / COUNT(DISTINCT session_id) AS DECIMAL(16,2))
FROM gmall.dws_traffic_session_page_view_1d
WHERE dt >= DATE_SUB('${do_date}', 6) AND dt <= '${do_date}'
GROUP BY channel
UNION ALL
-- 30 日汇总
SELECT
    '${do_date}',
    30,
    channel,
    COUNT(DISTINCT mid),
    CAST(AVG(during_time_sec) AS BIGINT),
    CAST(AVG(page_count) AS BIGINT),
    COUNT(DISTINCT session_id),
    CAST(SUM(IF(page_count = 1, 1, 0)) * 100.0
         / COUNT(DISTINCT session_id) AS DECIMAL(16,2))
FROM gmall.dws_traffic_session_page_view_1d
WHERE dt >= DATE_SUB('${do_date}', 29) AND dt <= '${do_date}'
GROUP BY channel;

-- ----------------------------
-- 用户行为漏斗分析
-- 来源：dwd_traffic_page_log_inc + dwd_trade_*
-- ----------------------------
INSERT INTO TABLE gmall.ads_user_action
SELECT
    '${do_date}'                                        AS dt,
    COUNT(DISTINCT IF(page_id = 'home', user_id, NULL)) AS home_count,
    COUNT(DISTINCT IF(page_id = 'good_detail', user_id, NULL)) AS good_detail_count,
    COUNT(DISTINCT cart.user_id)                         AS cart_count,
    COUNT(DISTINCT od.user_id)                           AS order_count,
    COUNT(DISTINCT pay.user_id)                          AS payment_count
FROM gmall.dwd_traffic_page_log_inc page
FULL OUTER JOIN (
    SELECT DISTINCT user_id FROM gmall.dwd_trade_cart_add_inc WHERE dt = '${do_date}'
) cart ON page.user_id = cart.user_id
FULL OUTER JOIN (
    SELECT DISTINCT user_id FROM gmall.dwd_trade_order_detail_inc WHERE dt = '${do_date}'
) od ON COALESCE(page.user_id, cart.user_id) = od.user_id
FULL OUTER JOIN (
    SELECT DISTINCT user_id FROM gmall.dwd_trade_pay_detail_inc WHERE dt = '${do_date}'
) pay ON COALESCE(page.user_id, cart.user_id, od.user_id) = pay.user_id
WHERE page.dt = '${do_date}';

-- ----------------------------
-- 各品牌交易统计（1日）
-- 来源：dws_trade_order_1d
-- ----------------------------
INSERT INTO TABLE gmall.ads_order_stats_by_tm
SELECT
    '${do_date}'      AS dt,
    1                 AS recent_days,
    tm_id,
    tm_name,
    COUNT(*)          AS order_count,
    SUM(split_total_amount) AS order_amount
FROM gmall.dws_trade_order_1d
WHERE dt = '${do_date}'
  AND tm_id IS NOT NULL
GROUP BY tm_id, tm_name;

-- ----------------------------
-- 用户留存率分析
-- 来源：dws_user_user_login_1d
-- 逻辑：计算某日新增用户在后续 n 天的留存
-- ----------------------------
INSERT INTO TABLE gmall.ads_user_retention
-- 留待实际用户登录表实现
SELECT
    '${do_date}' AS dt,
    '${do_date}' AS create_date,
    1            AS retention_day,
    0            AS retention_count,
    0            AS new_user_count,
    0.00         AS retention_rate;
