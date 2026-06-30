#!/bin/bash
# ===================================================
# ADS 层计算脚本：DWS → ADS
# 用途：从 DWS 汇总层生成 ADS 应用层报表
# 参数: $1 - 日期（可选，默认 T-1）
# 使用示例: bash dws_to_ads.sh 2022-06-08
# ===================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source ${SCRIPT_DIR}/../common/env.sh
source ${SCRIPT_DIR}/../common/date_util.sh
source ${SCRIPT_DIR}/../common/hive_util.sh

DO_DATE=$(get_do_date "$1")

echo "============================================"
echo " ADS 层计算：DWS → ADS"
echo " 日期: ${DO_DATE}"
echo "============================================"

SQL_FILE="${SCRIPT_DIR}/../../sql/ads/insert/ads_insert.sql"

execute_hive_sql "$SQL_FILE" "$DO_DATE"

echo "[INFO] ADS 层计算完成"
