#!/bin/bash
# ===================================================
# DataX 全量同步脚本：MySQL → HDFS
# 用途：将 MySQL 中的配置维度表全量同步到 HDFS
# 参数: $1 - 表名（或 all）
#       $2 - 日期（可选，默认 T-1）
# 使用示例:
#   bash mysql_to_hdfs_full.sh all 2022-06-08
#   bash mysql_to_hdfs_full.sh base_province 2022-06-08
# ===================================================

set -e

source $(dirname $0)/../common/env.sh
source $(dirname $0)/../common/date_util.sh
source $(dirname $0)/../common/hdfs_util.sh

DATAX_HOME="${DATAX_HOME:-/opt/module/datax}"
DATAX_JOB_DIR="/opt/module/datax/job/import"
DO_DATE=$(get_do_date "$2")

# -------------------------------------------------
# 处理目标 HDFS 路径（不存在则创建）
# -------------------------------------------------
handle_targetdir() {
    local target_dir="$1"
    ensure_hdfs_dir "$target_dir"
}

# -------------------------------------------------
# 执行 DataX 同步任务
# -------------------------------------------------
import_data() {
    local config_file="$1"
    local target_dir="$2"

    echo "[INFO] 开始同步: $(basename $config_file) -> $target_dir"

    handle_targetdir "$target_dir"

    python ${DATAX_HOME}/bin/datax.py \
        -p"-Dtargetdir=$target_dir" \
        "$config_file"

    echo "[INFO] 同步完成: $target_dir"
}

# -------------------------------------------------
# 主逻辑：根据表名分发
# -------------------------------------------------
case $1 in
"activity_info")
    import_data ${DATAX_JOB_DIR}/gmall.activity_info.json ${ORIGIN_DATA_BASE}/db/activity_info_full/${DO_DATE}
    ;;
"activity_rule")
    import_data ${DATAX_JOB_DIR}/gmall.activity_rule.json ${ORIGIN_DATA_BASE}/db/activity_rule_full/${DO_DATE}
    ;;
"base_category1")
    import_data ${DATAX_JOB_DIR}/gmall.base_category1.json ${ORIGIN_DATA_BASE}/db/base_category1_full/${DO_DATE}
    ;;
"base_category2")
    import_data ${DATAX_JOB_DIR}/gmall.base_category2.json ${ORIGIN_DATA_BASE}/db/base_category2_full/${DO_DATE}
    ;;
"base_category3")
    import_data ${DATAX_JOB_DIR}/gmall.base_category3.json ${ORIGIN_DATA_BASE}/db/base_category3_full/${DO_DATE}
    ;;
"base_dic")
    import_data ${DATAX_JOB_DIR}/gmall.base_dic.json ${ORIGIN_DATA_BASE}/db/base_dic_full/${DO_DATE}
    ;;
"base_province")
    import_data ${DATAX_JOB_DIR}/gmall.base_province.json ${ORIGIN_DATA_BASE}/db/base_province_full/${DO_DATE}
    ;;
"base_region")
    import_data ${DATAX_JOB_DIR}/gmall.base_region.json ${ORIGIN_DATA_BASE}/db/base_region_full/${DO_DATE}
    ;;
"base_trademark")
    import_data ${DATAX_JOB_DIR}/gmall.base_trademark.json ${ORIGIN_DATA_BASE}/db/base_trademark_full/${DO_DATE}
    ;;
"cart_info")
    import_data ${DATAX_JOB_DIR}/gmall.cart_info.json ${ORIGIN_DATA_BASE}/db/cart_info_full/${DO_DATE}
    ;;
"coupon_info")
    import_data ${DATAX_JOB_DIR}/gmall.coupon_info.json ${ORIGIN_DATA_BASE}/db/coupon_info_full/${DO_DATE}
    ;;
"sku_attr_value")
    import_data ${DATAX_JOB_DIR}/gmall.sku_attr_value.json ${ORIGIN_DATA_BASE}/db/sku_attr_value_full/${DO_DATE}
    ;;
"sku_info")
    import_data ${DATAX_JOB_DIR}/gmall.sku_info.json ${ORIGIN_DATA_BASE}/db/sku_info_full/${DO_DATE}
    ;;
"sku_sale_attr_value")
    import_data ${DATAX_JOB_DIR}/gmall.sku_sale_attr_value.json ${ORIGIN_DATA_BASE}/db/sku_sale_attr_value_full/${DO_DATE}
    ;;
"spu_info")
    import_data ${DATAX_JOB_DIR}/gmall.spu_info.json ${ORIGIN_DATA_BASE}/db/spu_info_full/${DO_DATE}
    ;;
"promotion_pos")
    import_data ${DATAX_JOB_DIR}/gmall.promotion_pos.json ${ORIGIN_DATA_BASE}/db/promotion_pos_full/${DO_DATE}
    ;;
"promotion_refer")
    import_data ${DATAX_JOB_DIR}/gmall.promotion_refer.json ${ORIGIN_DATA_BASE}/db/promotion_refer_full/${DO_DATE}
    ;;
"all")
    echo "========== 开始全量同步所有表，日期: ${DO_DATE} =========="
    import_data ${DATAX_JOB_DIR}/gmall.activity_info.json       ${ORIGIN_DATA_BASE}/db/activity_info_full/${DO_DATE}
    import_data ${DATAX_JOB_DIR}/gmall.activity_rule.json       ${ORIGIN_DATA_BASE}/db/activity_rule_full/${DO_DATE}
    import_data ${DATAX_JOB_DIR}/gmall.base_category1.json      ${ORIGIN_DATA_BASE}/db/base_category1_full/${DO_DATE}
    import_data ${DATAX_JOB_DIR}/gmall.base_category2.json      ${ORIGIN_DATA_BASE}/db/base_category2_full/${DO_DATE}
    import_data ${DATAX_JOB_DIR}/gmall.base_category3.json      ${ORIGIN_DATA_BASE}/db/base_category3_full/${DO_DATE}
    import_data ${DATAX_JOB_DIR}/gmall.base_dic.json            ${ORIGIN_DATA_BASE}/db/base_dic_full/${DO_DATE}
    import_data ${DATAX_JOB_DIR}/gmall.base_province.json       ${ORIGIN_DATA_BASE}/db/base_province_full/${DO_DATE}
    import_data ${DATAX_JOB_DIR}/gmall.base_region.json         ${ORIGIN_DATA_BASE}/db/base_region_full/${DO_DATE}
    import_data ${DATAX_JOB_DIR}/gmall.base_trademark.json      ${ORIGIN_DATA_BASE}/db/base_trademark_full/${DO_DATE}
    import_data ${DATAX_JOB_DIR}/gmall.cart_info.json           ${ORIGIN_DATA_BASE}/db/cart_info_full/${DO_DATE}
    import_data ${DATAX_JOB_DIR}/gmall.coupon_info.json         ${ORIGIN_DATA_BASE}/db/coupon_info_full/${DO_DATE}
    import_data ${DATAX_JOB_DIR}/gmall.sku_attr_value.json      ${ORIGIN_DATA_BASE}/db/sku_attr_value_full/${DO_DATE}
    import_data ${DATAX_JOB_DIR}/gmall.sku_info.json            ${ORIGIN_DATA_BASE}/db/sku_info_full/${DO_DATE}
    import_data ${DATAX_JOB_DIR}/gmall.sku_sale_attr_value.json ${ORIGIN_DATA_BASE}/db/sku_sale_attr_value_full/${DO_DATE}
    import_data ${DATAX_JOB_DIR}/gmall.spu_info.json            ${ORIGIN_DATA_BASE}/db/spu_info_full/${DO_DATE}
    import_data ${DATAX_JOB_DIR}/gmall.promotion_pos.json       ${ORIGIN_DATA_BASE}/db/promotion_pos_full/${DO_DATE}
    import_data ${DATAX_JOB_DIR}/gmall.promotion_refer.json     ${ORIGIN_DATA_BASE}/db/promotion_refer_full/${DO_DATE}
    echo "========== 全量同步完成 =========="
    ;;
*)
    echo "Usage: $0 {table_name|all} [date]"
    echo "Available tables: activity_info, activity_rule, base_category1/2/3, base_dic, base_province, base_region, base_trademark, cart_info, coupon_info, sku_attr_value, sku_info, sku_sale_attr_value, spu_info, promotion_pos, promotion_refer"
    exit 1
    ;;
esac
