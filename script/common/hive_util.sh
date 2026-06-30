#!/bin/bash
# ===================================================
# Hive 工具函数
# 用途：封装 Hive SQL 执行逻辑，统一错误处理
# ===================================================

source $(dirname $0)/env.sh

# -------------------------------------------------
# 执行 Hive SQL 文件
# 参数: $1 - SQL 文件路径
#       $2 - 日期参数 (yyyy-MM-dd)
# -------------------------------------------------
execute_hive_sql() {
    local sql_file="$1"
    local do_date="${2:-$(date -d '-1 day' +%F)}"

    if [ ! -f "$sql_file" ]; then
        echo "[ERROR] SQL 文件不存在: $sql_file"
        return 1
    fi

    echo "[INFO] 正在执行 Hive SQL: $sql_file (日期: $do_date)"

    # 替换 SQL 文件中的变量占位符并执行
    sed "s/\${do_date}/$do_date/g" "$sql_file" | \
        ${HIVE_HOME}/bin/hive \
            --hiveconf do_date="$do_date" \
            -f /dev/stdin

    local ret_code=$?
    if [ $ret_code -eq 0 ]; then
        echo "[INFO] Hive SQL 执行完成"
    else
        echo "[ERROR] Hive SQL 执行失败 (exit code: $ret_code)"
        return $ret_code
    fi
}

# -------------------------------------------------
# 检查 Hive 表分区是否存在
# 参数: $1 - 表名
#       $2 - 分区值
# -------------------------------------------------
check_hive_partition() {
    local table="$1"
    local partition="$2"

    local count=$(${HIVE_HOME}/bin/hive -e "
        SELECT COUNT(*) FROM ${HIVE_DB}.${table}
        WHERE dt = '${partition}';
    " 2>/dev/null | tail -1)

    if [ "$count" -gt 0 ] 2>/dev/null; then
        echo "[INFO] 表 ${table} 分区 dt=${partition} 存在，记录数: ${count}"
        return 0
    else
        echo "[WARN] 表 ${table} 分区 dt=${partition} 为空或不存在"
        return 1
    fi
}
