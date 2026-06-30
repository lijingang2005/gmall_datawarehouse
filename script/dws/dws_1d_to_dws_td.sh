#!/bin/bash
# ===================================================
# DWS td 层计算脚本：DWS 1d → DWS td
# 用途：将 1 日汇总聚合为历史累计汇总
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

-- ==================== 交易域用户累计汇总 ====================
-- INSERT OVERWRITE TABLE dws_trade_user_order_td PARTITION (dt = '${DO_DATE}')
-- 累计用户维度的下单统计...

EOF

echo "[INFO] DWS td 层计算完成"
