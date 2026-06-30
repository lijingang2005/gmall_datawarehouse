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

# 执行 N 日汇总 HQL（可拆分为独立 SQL 文件）
${HIVE_HOME}/bin/hive --hiveconf do_date="${DO_DATE}" << EOF

USE ${HIVE_DB};

-- ==================== 流量域 N 日汇总 ====================

-- ==================== 交易域：品牌粒度 7/30 日汇总 ====================
INSERT OVERWRITE TABLE dws_trade_order_tm_nd PARTITION (dt = '${DO_DATE}')
SELECT
    tm_id,
    tm_name,
    COUNT(DISTINCT order_id)           AS order_count,
    COUNT(DISTINCT user_id)            AS user_count,
    SUM(split_total_amount)            AS order_amount
FROM dws_trade_order_1d
WHERE dt >= DATE_SUB('${DO_DATE}', 6)   -- 最近 7 天
  AND dt <= '${DO_DATE}'
  AND tm_id IS NOT NULL
GROUP BY tm_id, tm_name;

EOF

echo "[INFO] DWS nd 层计算完成"
