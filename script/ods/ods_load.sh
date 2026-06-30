#!/bin/bash
# ===================================================
# ODS 层装载总脚本
# 用途：统一调用日志和业务数据的 ODS 装载
# 参数: $1 - 日期（可选，默认 T-1）
# ===================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source ${SCRIPT_DIR}/../common/date_util.sh

DO_DATE=$(get_do_date "$1")

echo "============================================"
echo " ODS 层数据装载"
echo " 日期: ${DO_DATE}"
echo "============================================"

# 日志 ODS
bash ${SCRIPT_DIR}/../collect/hdfs_to_ods_log.sh ${DO_DATE}

# 业务 ODS
bash ${SCRIPT_DIR}/../collect/hdfs_to_ods_db.sh ${DO_DATE}

echo "[INFO] ODS 层全部装载完成"
