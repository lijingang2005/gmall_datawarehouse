#!/bin/bash
# ===================================================
# DWS 1d 层计算脚本：DWD → DWS 1d
# 用途：从 DWD 明细层汇总生成 DWS 1日窗口汇总表
# 参数: $1 - 日期（可选，默认 T-1）
# 使用示例: bash dwd_to_dws_1d.sh 2022-06-08
# ===================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source ${SCRIPT_DIR}/../common/env.sh
source ${SCRIPT_DIR}/../common/date_util.sh
source ${SCRIPT_DIR}/../common/hive_util.sh

DO_DATE=$(get_do_date "$1")

echo "============================================"
echo " DWS 1d 层计算：DWD → DWS 1d"
echo " 日期: ${DO_DATE}"
echo "============================================"

SQL_FILE="${SCRIPT_DIR}/../../sql/dws/insert/dws_insert.sql"

execute_hive_sql "$SQL_FILE" "$DO_DATE"

echo "[INFO] DWS 1d 层计算完成"
