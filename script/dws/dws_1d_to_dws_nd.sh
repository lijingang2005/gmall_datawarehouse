#!/bin/bash
# ===================================================
# DWS nd 层计算脚本：DWS 1d → DWS nd
# 用途：将 1 日汇总聚合为 N 日（7/30）窗口汇总
# 参数: $1 - 日期（可选，默认 T-1）
# 使用示例: bash dws_1d_to_dws_nd.sh 2022-06-08
# ===================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source ${SCRIPT_DIR}/../common/env.sh
source ${SCRIPT_DIR}/../common/date_util.sh
source ${SCRIPT_DIR}/../common/hive_util.sh

DO_DATE=$(get_do_date "$1")

echo "============================================"
echo " DWS nd 层计算：DWS 1d → DWS nd"
echo " 日期: ${DO_DATE}"
echo "============================================"

# 此处执行 N 日窗口计算（7 日和 30 日汇总）

${HIVE_HOME}/bin/hive --hiveconf do_date="${DO_DATE}" << EOF

USE ${HIVE_DB};

-- ==================== 交易域：用户商品粒度 7/30 日汇总 ====================
INSERT OVERWRITE TABLE dws_trade_user_sku_order_nd PARTITION (dt = '${DO_DATE}')
SELECT
    user_id,
    sku_id,
    sku_name,
    category1_id,
    category1_name,
    category2_id,
    category2_name,
    category3_id,
    category3_name,
    tm_id,
    tm_name,
    sum(IF(dt >= date_sub('${DO_DATE}', 6), order_count_1d, 0)) order_count_7d,
    sum(IF(dt >= date_sub('${DO_DATE}', 6), order_num_1d, 0)) order_num_7d,
    sum(IF(dt >= date_sub('${DO_DATE}', 6), order_original_amount_1d, 0)) order_original_amount_7d,
    sum(IF(dt >= date_sub('${DO_DATE}', 6), activity_reduce_amount_1d, 0)) activity_reduce_amount_7d,
    sum(IF(dt >= date_sub('${DO_DATE}', 6), coupon_reduce_amount_1d, 0)) coupon_reduce_amount_7d,
    sum(IF(dt >= date_sub('${DO_DATE}', 6), order_total_amount_1d, 0)) order_total_amount_7d,
    sum(order_count_1d) order_count_30d,
    sum(order_num_1d) order_num_30d,
    sum(order_original_amount_1d) order_original_amount_30d,
    sum(activity_reduce_amount_1d) activity_reduce_amount_30d,
    sum(coupon_reduce_amount_1d) coupon_reduce_amount_30d,
    sum(order_total_amount_1d) order_total_amount_30d
FROM dws_trade_user_sku_order_1d
WHERE dt >= date_sub('${DO_DATE}', 29) AND dt <= '${DO_DATE}'
GROUP BY user_id, sku_id, sku_name, category1_id, category1_name, category2_id, category2_name, category3_id, category3_name, tm_id, tm_name;

-- ==================== 交易域：省份粒度 7/30 日汇总 ====================
INSERT OVERWRITE TABLE dws_trade_province_order_nd PARTITION (dt = '${DO_DATE}')
SELECT
    province_id,
    province_name,
    area_code,
    iso_code,
    iso_3166_2,
    sum(IF(dt >= date_sub('${DO_DATE}', 6), order_count_1d, 0)) order_count_7d,
    sum(IF(dt >= date_sub('${DO_DATE}', 6), order_original_amount_1d, 0)) order_original_amount_7d,
    sum(IF(dt >= date_sub('${DO_DATE}', 6), activity_reduce_amount_1d, 0)) activity_reduce_amount_7d,
    sum(IF(dt >= date_sub('${DO_DATE}', 6), coupon_reduce_amount_1d, 0)) coupon_reduce_amount_7d,
    sum(IF(dt >= date_sub('${DO_DATE}', 6), order_total_amount_1d, 0)) order_total_amount_7d,
    sum(order_count_1d) order_count_30d,
    sum(order_original_amount_1d) order_original_amount_30d,
    sum(activity_reduce_amount_1d) activity_reduce_amount_30d,
    sum(coupon_reduce_amount_1d) coupon_reduce_amount_30d,
    sum(order_total_amount_1d) order_total_amount_30d
FROM dws_trade_province_order_1d
WHERE dt >= date_sub('${DO_DATE}', 29) AND dt <= '${DO_DATE}'
GROUP BY province_id, province_name, area_code, iso_code, iso_3166_2;

EOF

echo "[INFO] DWS nd 层计算完成"
