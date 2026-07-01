#!/bin/bash
# ===================================================
# HDFS 工具函数
# 用途：封装常用的 HDFS 操作
# ===================================================

# -------------------------------------------------
# 检查 HDFS 路径是否存在，不存在则创建
# 参数: $1 - HDFS 路径
# -------------------------------------------------
ensure_hdfs_dir() {
    local hdfs_path="$1"

    if ${HADOOP_HOME}/bin/hdfs dfs -test -e "$hdfs_path" 2>/dev/null; then
        echo "[INFO] HDFS 路径已存在: $hdfs_path"
        return 0
    else
        echo "[INFO] 正在创建 HDFS 路径: $hdfs_path"
        ${HADOOP_HOME}/bin/hdfs dfs -mkdir -p "$hdfs_path"
    fi
}

# -------------------------------------------------
# 清空 HDFS 路径内容
# 参数: $1 - HDFS 路径
# -------------------------------------------------
clean_hdfs_dir() {
    local hdfs_path="$1"

    if ${HADOOP_HOME}/bin/hdfs dfs -test -e "$hdfs_path" 2>/dev/null; then
        echo "[INFO] 正在清空 HDFS 路径: $hdfs_path"
        ${HADOOP_HOME}/bin/hdfs dfs -rm -r -f "$hdfs_path/*"
    fi
    ensure_hdfs_dir "$hdfs_path"
}

# -------------------------------------------------
# 获取 HDFS 路径下的文件数量
# 参数: $1 - HDFS 路径
# -------------------------------------------------
count_hdfs_files() {
    local hdfs_path="$1"
    ${HADOOP_HOME}/bin/hdfs dfs -ls "$hdfs_path" 2>/dev/null | \
        grep -v "^d" | wc -l
}
