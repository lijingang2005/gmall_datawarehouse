#!/bin/bash
# ===================================================
# DWS td 层计算脚本：DWS 1d → DWS td
# 用途：将 1 日汇总与昨日累计合并为历史累计汇总
# 参数: $1 - 日期（可选，默认 T-1）
# 使用示例: bash dws_1d_to_dws_td.sh 2022-06-08
# ===================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source ${SCRIPT_DIR}/../common/env.sh
source ${SCRIPT_DIR}/../common/date_util.sh
source ${SCRIPT_DIR}/../common/hive_util.sh

DO_DATE=$(get_do_date "$1")

echo "============================================"
echo " DWS td 层计算：DWS 1d → DWS td"
echo " 日期: ${DO_DATE}"
echo "============================================"

# 执行累计汇总 HQL
${HIVE_HOME}/bin/hive --hiveconf do_date="${DO_DATE}" << EOF

USE ${HIVE_DB};

-- ==================== 交易域用户粒度订单历史至今汇总表 ====================
-- 首次装载（从1d表全量计算，仅首次执行）
-- INSERT OVERWRITE TABLE dws_trade_user_order_td PARTITION (dt = '${DO_DATE}')
-- SELECT
--     user_id,
--     min(dt) order_date_first,
--     max(dt) order_date_last,
--     sum(order_count_1d) order_count_td,
--     sum(order_num_1d) order_num_td,
--     sum(order_original_amount_1d) original_amount_td,
--     sum(activity_reduce_amount_1d) activity_reduce_amount_td,
--     sum(coupon_reduce_amount_1d) coupon_reduce_amount_td,
--     sum(order_total_amount_1d) total_amount_td
-- FROM dws_trade_user_order_1d
-- WHERE dt <= '${DO_DATE}'
-- GROUP BY user_id;

-- 每日装载（昨日累计 + 今日1d）
INSERT OVERWRITE TABLE dws_trade_user_order_td PARTITION (dt = '${DO_DATE}')
SELECT
    user_id,
    min(order_date_first),
    max(order_date_last),
    sum(order_count_td),
    sum(order_num_td),
    sum(original_amount_td),
    sum(activity_reduce_amount_td),
    sum(coupon_reduce_amount_td),
    sum(total_amount_td)
FROM (
    SELECT
        user_id,
        order_date_first,
        order_date_last,
        order_count_td,
        order_num_td,
        original_amount_td,
        activity_reduce_amount_td,
        coupon_reduce_amount_td,
        total_amount_td
    FROM dws_trade_user_order_td
    WHERE dt = date_sub('${DO_DATE}', 1)
    UNION ALL
    SELECT
        user_id,
        '${DO_DATE}',
        '${DO_DATE}',
        order_count_1d,
        order_num_1d,
        order_original_amount_1d,
        activity_reduce_amount_1d,
        coupon_reduce_amount_1d,
        order_total_amount_1d
    FROM dws_trade_user_order_1d
    WHERE dt = '${DO_DATE}'
) t
GROUP BY user_id;

-- ==================== 用户域用户粒度登录历史至今汇总表 ====================
INSERT OVERWRITE TABLE dws_user_user_login_td PARTITION (dt = '${DO_DATE}')
SELECT
    user_id,
    max(login_date_last) login_date_last,
    min(login_date_first) login_date_first,
    sum(login_count_td) login_count_td
FROM (
    SELECT
        user_id,
        login_date_last,
        login_date_first,
        login_count_td
    FROM dws_user_user_login_td
    WHERE dt = date_sub('${DO_DATE}', 1)
    UNION ALL
    SELECT
        user_id,
        '${DO_DATE}',
        '${DO_DATE}',
        count(*) login_count_td
    FROM dwd_user_login_inc
    WHERE dt = '${DO_DATE}'
    GROUP BY user_id
) t
GROUP BY user_id;

EOF

echo "[INFO] DWS td 层计算完成"
