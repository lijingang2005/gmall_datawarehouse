#!/bin/bash
# ===================================================
# DWD 层计算脚本：ODS → DWD
# 用途：清洗标准化 ODS 原始数据，生成 DWD 明细层
# 参数: $1 - 日期（可选，默认 T-1）
# 使用示例: bash ods_to_dwd.sh 2022-06-08
# ===================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source ${SCRIPT_DIR}/../common/env.sh
source ${SCRIPT_DIR}/../common/date_util.sh
source ${SCRIPT_DIR}/../common/hive_util.sh

DO_DATE=$(get_do_date "$1")

echo "============================================"
echo " DWD 层计算：ODS → DWD"
echo " 日期: ${DO_DATE}"
echo "============================================"

SQL_FILE="${SCRIPT_DIR}/../../sql/dwd/insert/dwd_insert.sql"

execute_hive_sql "$SQL_FILE" "$DO_DATE"

echo "[INFO] DWD 层计算完成"
