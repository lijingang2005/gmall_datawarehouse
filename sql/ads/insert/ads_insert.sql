-- ===================================================
-- ADS 层数据装载：应用层 ETL
-- 参数：${do_date} — 日期，格式 yyyy-MM-dd
-- 幂等策略：SELECT * FROM old UNION SELECT ... new
-- ===================================================

-- -------------------------------------------------
-- 1. 各渠道流量统计
-- 来源：dws_traffic_session_page_view_1d
-- -------------------------------------------------
INSERT OVERWRITE TABLE gmall.ads_traffic_stats_by_channel
SELECT * FROM gmall.ads_traffic_stats_by_channel
UNION
SELECT
    '${do_date}',
    recent_days,
    channel,
    count(DISTINCT mid_id),
    avg(during_time_1d / 1000),
    avg(page_count_1d),
    count(DISTINCT session_id),
    sum(IF(page_count_1d = 1, 1, 0)) / count(DISTINCT session_id)
FROM (
    SELECT
        channel,
        mid_id,
        during_time_1d,
        page_count_1d,
        session_id,
        dt
    FROM gmall.dws_traffic_session_page_view_1d
    WHERE dt >= date_sub('${do_date}', 29) AND dt <= '${do_date}'
) t LATERAL VIEW explode(array(1, 7, 30)) tmp AS recent_days
WHERE dt >= date_sub('${do_date}', recent_days - 1) AND dt <= '${do_date}'
GROUP BY recent_days, channel;

-- -------------------------------------------------
-- 2. 页面路径分析
-- 来源：dwd_traffic_page_view_inc
-- -------------------------------------------------
INSERT OVERWRITE TABLE gmall.ads_page_path
SELECT * FROM gmall.ads_page_path
UNION
SELECT
    '${do_date}',
    source,
    target,
    count(*) AS path_count
FROM (
    SELECT
        concat('step-', rn, ':', page_id) AS source,
        concat('step-', rn + 1, ':', next_page) AS target
    FROM (
        SELECT
            page_id,
            lead(page_id, 1, 'out') OVER (PARTITION BY session_id ORDER BY view_time) AS next_page,
            row_number() OVER (PARTITION BY session_id ORDER BY view_time) AS rn
        FROM gmall.dwd_traffic_page_view_inc
        WHERE dt = '${do_date}'
    ) t
) t1
GROUP BY source, target;

-- -------------------------------------------------
-- 3. 用户变动统计
-- 来源：dws_user_user_login_td
-- -------------------------------------------------
INSERT OVERWRITE TABLE gmall.ads_user_change
SELECT * FROM gmall.ads_user_change
UNION
SELECT
    '${do_date}',
    user_churn_count,
    user_back_count
FROM (
    SELECT
        '${do_date}' AS dt,
        count(user_id) user_churn_count
    FROM gmall.dws_user_user_login_td
    WHERE dt = '${do_date}'
      AND login_date_last = date_sub('${do_date}', 7)
) t1
JOIN (
    SELECT
        '${do_date}' AS dt,
        count(a.user_id) user_back_count
    FROM (
        SELECT user_id
        FROM gmall.dws_user_user_login_td
        WHERE dt = '${do_date}'
          AND login_date_last = '${do_date}'
    ) a
    JOIN (
        SELECT user_id
        FROM gmall.dws_user_user_login_td
        WHERE dt = date_sub('${do_date}', 1)
          AND login_date_last <= date_sub('${do_date}', 8)
    ) b ON a.user_id = b.user_id
) t2 ON t1.dt = t2.dt;

-- -------------------------------------------------
-- 4. 用户留存率
-- 来源：dws_user_user_login_td
-- -------------------------------------------------
INSERT OVERWRITE TABLE gmall.ads_user_retention
SELECT * FROM gmall.ads_user_retention
UNION
SELECT
    '${do_date}' AS dt,
    login_date_first AS create_date,
    datediff('${do_date}', login_date_first) AS retention_day,
    sum(IF(login_date_last = '${do_date}', 1, 0)) AS retention_count,
    count(user_id) AS new_user_count,
    CAST(sum(IF(login_date_last = '${do_date}', 1, 0)) / count(*) * 100 AS DECIMAL(16, 2)) retention_rate
FROM gmall.dws_user_user_login_td
WHERE dt = '${do_date}'
  AND login_date_first >= date_sub('${do_date}', 7)
  AND login_date_first < '${do_date}'
GROUP BY login_date_first;

-- -------------------------------------------------
-- 5. 用户新增活跃统计
-- 来源：dws_user_user_login_td
-- -------------------------------------------------
INSERT OVERWRITE TABLE gmall.ads_user_stats
SELECT * FROM gmall.ads_user_stats
UNION
SELECT
    '${do_date}' AS dt,
    recent_days,
    CASE recent_days
        WHEN 1 THEN new_user_count_1d
        WHEN 7 THEN new_user_count_7d
        WHEN 30 THEN new_user_count_30d
    END AS new_user_count,
    CASE recent_days
        WHEN 1 THEN active_user_count_1d
        WHEN 7 THEN active_user_count_7d
        WHEN 30 THEN active_user_count_30d
    END AS active_user_count
FROM (
    SELECT
        sum(IF(login_date_first = '${do_date}', 1, 0)) AS new_user_count_1d,
        sum(IF(login_date_last = '${do_date}', 1, 0)) AS active_user_count_1d,
        sum(IF(login_date_first >= date_sub('${do_date}', 6) AND login_date_first <= '${do_date}', 1, 0)) AS new_user_count_7d,
        sum(IF(login_date_last >= date_sub('${do_date}', 6) AND login_date_last <= '${do_date}', 1, 0)) AS active_user_count_7d,
        sum(IF(login_date_first >= date_sub('${do_date}', 29) AND login_date_first <= '${do_date}', 1, 0)) AS new_user_count_30d,
        sum(IF(login_date_last >= date_sub('${do_date}', 29) AND login_date_last <= '${do_date}', 1, 0)) AS active_user_count_30d
    FROM gmall.dws_user_user_login_td
    WHERE dt = '${do_date}'
      AND login_date_last >= date_sub('${do_date}', 29)
      AND login_date_last <= '${do_date}'
) t LATERAL VIEW explode(array(1, 7, 30)) tmp AS recent_days;

-- -------------------------------------------------
-- 6. 用户行为漏斗分析
-- 来源：dws_traffic_page_visitor_page_view_1d + dws_trade_user_cart_add_1d
--       + dws_trade_user_order_1d + dws_trade_user_payment_1d
-- -------------------------------------------------
INSERT OVERWRITE TABLE gmall.ads_user_action
SELECT * FROM gmall.ads_user_action
UNION
SELECT
    pv.dt,
    home_count,
    good_detail_count,
    cart_count,
    order_count,
    payment_count
FROM (
    SELECT
        '${do_date}' AS dt,
        sum(IF(page_id = 'home', 1, 0)) AS home_count,
        sum(IF(page_id = 'good_detail', 1, 0)) AS good_detail_count
    FROM gmall.dws_traffic_page_visitor_page_view_1d
    WHERE dt = '${do_date}'
      AND (page_id = 'home' OR page_id = 'good_detail')
) pv
JOIN (
    SELECT '${do_date}' AS dt, count(*) AS cart_count
    FROM gmall.dws_trade_user_cart_add_1d
    WHERE dt = '${do_date}'
) cart ON pv.dt = cart.dt
JOIN (
    SELECT '${do_date}' AS dt, count(*) AS order_count
    FROM gmall.dws_trade_user_order_1d
    WHERE dt = '${do_date}'
) od ON COALESCE(pv.dt, cart.dt) = od.dt
JOIN (
    SELECT '${do_date}' AS dt, count(*) AS payment_count
    FROM gmall.dws_trade_user_payment_1d
    WHERE dt = '${do_date}'
) pay ON COALESCE(pv.dt, cart.dt, od.dt) = pay.dt;

-- -------------------------------------------------
-- 7. 新增下单用户统计
-- 来源：dws_trade_user_order_td
-- -------------------------------------------------
INSERT OVERWRITE TABLE gmall.ads_new_order_user_stats
SELECT * FROM gmall.ads_new_order_user_stats
UNION
SELECT
    '${do_date}',
    recent_days,
    CASE recent_days
        WHEN 1 THEN new_order_user_count_1d
        WHEN 7 THEN new_order_user_count_7d
        WHEN 30 THEN new_order_user_count_30d
    END AS new_order_user_count
FROM (
    SELECT
        count(IF(order_date_first = '${do_date}', user_id, NULL)) new_order_user_count_1d,
        count(IF(order_date_first >= date_sub('${do_date}', 6) AND order_date_first <= '${do_date}', user_id, NULL)) new_order_user_count_7d,
        count(user_id) new_order_user_count_30d
    FROM gmall.dws_trade_user_order_td
    WHERE dt = '${do_date}'
      AND order_date_first >= date_sub('${do_date}', 29)
      AND order_date_first <= '${do_date}'
) t LATERAL VIEW explode(array(1, 7, 30)) tmp AS recent_days;

-- -------------------------------------------------
-- 8. 连续三日下单用户统计
-- 来源：dws_trade_user_order_1d
-- -------------------------------------------------
INSERT OVERWRITE TABLE gmall.ads_order_continuously_user_count
SELECT * FROM gmall.ads_order_continuously_user_count
UNION
SELECT
    '${do_date}',
    7,
    count(DISTINCT user_id) AS order_continuously_user_count
FROM (
    SELECT
        user_id,
        datediff(dt, lead(dt, 2, '0000-00-00') OVER (PARTITION BY user_id ORDER BY dt DESC)) AS diff
    FROM gmall.dws_trade_user_order_1d
    WHERE dt >= date_sub('${do_date}', 6) AND dt <= '${do_date}'
) t
WHERE diff = 2;

-- -------------------------------------------------
-- 9. 各品牌复购率统计
-- 来源：dws_trade_user_sku_order_nd
-- -------------------------------------------------
INSERT OVERWRITE TABLE gmall.ads_repeat_purchase_by_tm
SELECT * FROM gmall.ads_repeat_purchase_by_tm
UNION
SELECT
    '${do_date}',
    30,
    tm_id,
    tm_name,
    CAST(sum(IF(tm_order_count_30d >= 2, 1, 0)) / sum(IF(tm_order_count_30d >= 1, 1, 0)) AS DECIMAL(16, 2)) AS order_repeat_rate
FROM (
    SELECT
        tm_id,
        tm_name,
        sum(order_count_30d) AS tm_order_count_30d
    FROM gmall.dws_trade_user_sku_order_nd
    WHERE dt = '${do_date}'
    GROUP BY user_id, tm_id, tm_name
) t
GROUP BY tm_id, tm_name;

-- -------------------------------------------------
-- 10. 各品牌交易统计
-- 来源：dws_trade_user_sku_order_1d + dws_trade_user_sku_order_nd
-- -------------------------------------------------
INSERT OVERWRITE TABLE gmall.ads_order_stats_by_tm
SELECT * FROM gmall.ads_order_stats_by_tm
UNION
SELECT
    '${do_date}' dt,
    recent_days,
    tm_id,
    tm_name,
    sum(order_count),
    count(DISTINCT IF(order_count > 0, user_id, NULL))
FROM (
    SELECT
        1 recent_days,
        tm_id,
        tm_name,
        sum(order_count_1d) order_count,
        user_id
    FROM gmall.dws_trade_user_sku_order_1d
    WHERE dt = '${do_date}'
    GROUP BY tm_id, tm_name, user_id
    UNION ALL
    SELECT
        recent_days,
        tm_id,
        tm_name,
        CASE recent_days
            WHEN 7 THEN order_count_7d
            WHEN 30 THEN order_count_30d
        END order_count,
        user_id
    FROM gmall.dws_trade_user_sku_order_nd
    LATERAL VIEW explode(array(7, 30)) tmp AS recent_days
    WHERE dt = '${do_date}'
) t
GROUP BY recent_days, tm_id, tm_name;

-- -------------------------------------------------
-- 11. 各品类商品下单统计
-- 来源：dws_trade_user_sku_order_1d + dws_trade_user_sku_order_nd
-- -------------------------------------------------
INSERT OVERWRITE TABLE gmall.ads_order_stats_by_cate
SELECT * FROM gmall.ads_order_stats_by_cate
UNION
SELECT
    '${do_date}' dt,
    recent_days,
    category1_id,
    category1_name,
    category2_id,
    category2_name,
    category3_id,
    category3_name,
    sum(order_count),
    count(DISTINCT IF(order_count > 0, user_id, NULL))
FROM (
    SELECT
        1 recent_days,
        category1_id, category1_name, category2_id, category2_name, category3_id, category3_name,
        sum(order_count_1d) order_count,
        user_id
    FROM gmall.dws_trade_user_sku_order_1d
    WHERE dt = '${do_date}'
    GROUP BY category1_id, category1_name, category2_id, category2_name, category3_id, category3_name, user_id
    UNION ALL
    SELECT
        recent_days,
        category1_id, category1_name, category2_id, category2_name, category3_id, category3_name,
        CASE recent_days WHEN 7 THEN order_count_7d WHEN 30 THEN order_count_30d END order_count,
        user_id
    FROM gmall.dws_trade_user_sku_order_nd
    LATERAL VIEW explode(array(7, 30)) tmp AS recent_days
    WHERE dt = '${do_date}'
) t
GROUP BY recent_days, category1_id, category1_name, category2_id, category2_name, category3_id, category3_name;

-- -------------------------------------------------
-- 12. 各省份交易统计
-- 来源：dws_trade_province_order_1d + dws_trade_province_order_nd
-- -------------------------------------------------
INSERT OVERWRITE TABLE gmall.ads_order_by_province
SELECT * FROM gmall.ads_order_by_province
UNION
SELECT
    dt, 1 recent_days, province_id, province_name, area_code, iso_code, iso_3166_2,
    order_count_1d, order_total_amount_1d
FROM gmall.dws_trade_province_order_1d
WHERE dt = '${do_date}'
UNION
SELECT
    dt, recent_days, province_id, province_name, area_code, iso_code, iso_3166_2,
    IF(recent_days = 7, order_count_7d, order_count_30d),
    IF(recent_days = 7, order_total_amount_7d, order_total_amount_30d)
FROM gmall.dws_trade_province_order_nd
LATERAL VIEW explode(array(7, 30)) tmp AS recent_days
WHERE dt = '${do_date}';

-- -------------------------------------------------
-- 13. 优惠券使用统计
-- 来源：dws_tool_user_coupon_coupon_used_1d
-- -------------------------------------------------
INSERT OVERWRITE TABLE gmall.ads_coupon_stats
SELECT * FROM gmall.ads_coupon_stats
UNION
SELECT
    '${do_date}' dt,
    coupon_id,
    coupon_name,
    CAST(sum(used_count_1d) AS BIGINT) used_count,
    CAST(count(user_id) AS BIGINT) used_user_count
FROM gmall.dws_tool_user_coupon_coupon_used_1d
WHERE dt = '${do_date}'
GROUP BY coupon_id, coupon_name;

-- -------------------------------------------------
-- 14. 各品类商品购物车存量Top3
-- 来源：dwd_trade_cart_full + dim_sku_full
-- -------------------------------------------------
INSERT OVERWRITE TABLE gmall.ads_sku_cart_num_top3_by_cate
SELECT * FROM gmall.ads_sku_cart_num_top3_by_cate
UNION
SELECT
    dt, category1_id, category1_name, category2_id, category2_name, category3_id, category3_name,
    sku_id, sku_name, cart_num, rk
FROM (
    SELECT
        '${do_date}' dt,
        category1_id, category1_name, category2_id, category2_name, category3_id, category3_name,
        sku_id, sku_name,
        sum(sku_num) cart_num,
        rank() OVER (PARTITION BY category3_id ORDER BY sum(sku_num) DESC) rk
    FROM (
        SELECT sku_id, sku_num FROM gmall.dwd_trade_cart_full WHERE dt = '${do_date}'
    ) cart
    LEFT JOIN (
        SELECT id, category1_id, category1_name, category2_id, category2_name, category3_id, category3_name, sku_name
        FROM gmall.dim_sku_full WHERE dt = '${do_date}'
    ) sku ON cart.sku_id = sku.id
    GROUP BY category1_id, category1_name, category2_id, category2_name, category3_id, category3_name, sku_id, sku_name
) t WHERE rk <= 3;

-- -------------------------------------------------
-- 15. 各品牌商品收藏次数Top3
-- 来源：dws_interaction_sku_favor_add_1d
-- -------------------------------------------------
INSERT OVERWRITE TABLE gmall.ads_sku_favor_count_top3_by_tm
SELECT * FROM gmall.ads_sku_favor_count_top3_by_tm
UNION
SELECT
    '${do_date}' dt, tm_id, tm_name, sku_id, sku_name, favor_add_count_1d, rk
FROM (
    SELECT
        tm_id, tm_name, sku_id, sku_name, favor_add_count_1d,
        rank() OVER (PARTITION BY tm_id ORDER BY favor_add_count_1d DESC) rk
    FROM gmall.dws_interaction_sku_favor_add_1d
    WHERE dt = '${do_date}'
) t1 WHERE rk <= 3;

-- -------------------------------------------------
-- 16. 下单到支付时间间隔平均值
-- 来源：dwd_trade_trade_flow_acc
-- -------------------------------------------------
INSERT OVERWRITE TABLE gmall.ads_order_to_pay_interval_avg
SELECT * FROM gmall.ads_order_to_pay_interval_avg
UNION
SELECT
    '${do_date}' dt,
    CAST(avg(unix_timestamp(payment_time) - unix_timestamp(order_time)) AS BIGINT)
FROM gmall.dwd_trade_trade_flow_acc
WHERE dt IN ('9999-12-31', '${do_date}')
  AND payment_date_id = '${do_date}';
