#!/bin/bash
# ===================================================
# ODS 层装载脚本：用户行为日志 HDFS → ODS
# 用途：将 HDFS 上的日志原始数据 LOAD 到 Hive ODS 层
# 参数: $1 - 日期（可选，默认 T-1）
# 使用示例: bash hdfs_to_ods_log.sh 2022-06-08
# ===================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source ${SCRIPT_DIR}/../common/env.sh
source ${SCRIPT_DIR}/../common/date_util.sh
source ${SCRIPT_DIR}/../common/hive_util.sh

DO_DATE=$(get_do_date "$1")

echo "============================================"
echo " ODS 层装载：用户行为日志"
echo " 日期: ${DO_DATE}"
echo "============================================"

SQL_FILE="${SCRIPT_DIR}/../../sql/ods/load/ods_log_load.sql"

execute_hive_sql "$SQL_FILE" "$DO_DATE"

echo "[INFO] ODS 层日志数据装载完成"
