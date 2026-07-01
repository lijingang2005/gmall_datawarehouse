#!/bin/bash
# ===================================================
# 数据导出脚本：Hive ADS → MySQL
# 用途：通过 DataX 将 Hive ADS 层结果数据导出到 MySQL
#      供 Superset / Grafana 等 BI 工具可视化
# 参数: $1 - 日期（可选，默认 T-1）
# 使用示例: bash hdfs_to_mysql.sh 2022-06-08
# ===================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source ${SCRIPT_DIR}/../common/env.sh
source ${SCRIPT_DIR}/../common/date_util.sh

DO_DATE=$(get_do_date "$1")
DATAX_HOME="${DATAX_HOME:-/opt/module/datax}"

echo "============================================"
echo " 数据导出：Hive ADS → MySQL"
echo " 日期: ${DO_DATE}"
echo "============================================"

# ADS 导出配置目录
EXPORT_CONFIG_DIR="/opt/module/datax/job/export"

# -------------------------------------------------
# 导出单张 ADS 表到 MySQL
# -------------------------------------------------
export_table() {
    local table_name="$1"
    local config_file="${EXPORT_CONFIG_DIR}/gmall_report.${table_name}.json"

    if [ ! -f "$config_file" ]; then
        echo "[WARN] DataX 配置文件不存在，跳过: $config_file"
        return 0
    fi

    echo "[INFO] 正在导出: ${table_name}"

    python ${DATAX_HOME}/bin/datax.py \
        -p"-Ddt=${DO_DATE}" \
        "$config_file"

    echo "[INFO] 导出完成: ${table_name}"
}

# -------------------------------------------------
# ADS 表清单
# -------------------------------------------------
ADS_TABLES=(
    "ads_traffic_stats_by_channel"
    "ads_page_path"
    "ads_user_change"
    "ads_user_retention"
    "ads_user_stats"
    "ads_user_action"
    "ads_new_order_user_stats"
    "ads_order_continuously_user_count"
    "ads_repeat_purchase_by_tm"
    "ads_order_stats_by_tm"
    "ads_order_stats_by_cate"
    "ads_order_by_province"
    "ads_coupon_stats"
    "ads_sku_cart_num_top3_by_cate"
    "ads_sku_favor_count_top3_by_tm"
    "ads_order_to_pay_interval_avg"
)

for table in "${ADS_TABLES[@]}"; do
    export_table "$table"
done

echo "[INFO] ADS 数据导出到 MySQL 全部完成"
