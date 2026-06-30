#!/bin/bash
# ===================================================
# 环境变量配置
# 用途：定义所有脚本共用的环境变量和路径
# ===================================================

# ---- HDFS 配置 ----
export HDFS_URI="hdfs://<NAMENODE_HOST>:8020"

# ---- Hive 配置 ----
export HIVE_HOME="/opt/module/hive-3.1.3"
export HIVE_DB="gmall"

# ---- DataX 配置 ----
export DATAX_HOME="/opt/module/datax"

# ---- MySQL 配置（已脱敏） ----
export MYSQL_HOST="<MYSQL_HOST>"
export MYSQL_PORT="3306"
export MYSQL_USER="root"
export MYSQL_PASSWORD="<MYSQL_PASSWORD>"

# ---- Hadoop 配置 ----
export HADOOP_HOME="/opt/module/hadoop-3.3.4"

# ---- HDFS 原始数据路径 ----
export ORIGIN_DATA_BASE="/origin_data/gmall"

# ---- 日期默认值 ----
export DO_DATE="${1:-$(date -d '-1 day' +%F)}"
