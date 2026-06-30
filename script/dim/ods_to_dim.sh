#!/bin/bash
# ===================================================
# DIM 层计算脚本：ODS → DIM
# 用途：从 ODS 层数据生成维度表（用户/商品/省份/日期/优惠券）
# 参数: $1 - 日期（可选，默认 T-1）
# 使用示例: bash ods_to_dim.sh 2022-06-08
# ===================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source ${SCRIPT_DIR}/../common/env.sh
source ${SCRIPT_DIR}/../common/date_util.sh
source ${SCRIPT_DIR}/../common/hive_util.sh

DO_DATE=$(get_do_date "$1")

echo "============================================"
echo " DIM 层计算：ODS → DIM"
echo " 日期: ${DO_DATE}"
echo "============================================"

SQL_FILE="${SCRIPT_DIR}/../../sql/dim/insert/dim_insert.sql"

execute_hive_sql "$SQL_FILE" "$DO_DATE"

echo "[INFO] DIM 层计算完成"
