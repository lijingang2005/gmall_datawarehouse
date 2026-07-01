#!/bin/bash
# ===================================================
# 数据采集集群一键启停脚本
# 用途：按照正确的依赖顺序启停所有数据采集组件
# 使用：caiji_cluster.sh start|stop
# ===================================================

case $1 in
"start"){
    echo ================== 启动采集集群 ==================

    # 启动 Zookeeper 集群
    zk.sh start || { echo "[ERROR] Zookeeper 启动失败"; exit 1; }

    # 启动 Hadoop 集群
    hadoop.sh start || { echo "[ERROR] Hadoop 启动失败"; exit 1; }

    # 启动 Kafka 采集集群
    kf.sh start || { echo "[ERROR] Kafka 启动失败"; exit 1; }

    # 启动采集 Flume（日志文件 → Kafka）
    f102.sh start || { echo "[ERROR] 采集 Flume 启动失败"; exit 1; }

    # 启动 Maxwell（MySQL Binlog → Kafka）
    mxw.sh start || { echo "[ERROR] Maxwell 启动失败"; exit 1; }

    # 启动日志消费 Flume（Kafka → HDFS）
    f104_log.sh start || { echo "[ERROR] 日志消费 Flume 启动失败"; exit 1; }

    # 启动业务消费 Flume（Kafka → HDFS）
    f103_db.sh start || { echo "[ERROR] 业务消费 Flume 启动失败"; exit 1; }

    echo ================== 采集集群启动完成 ==================
};;
"stop"){
    echo ================== 停止采集集群 ==================

    # 停止 Maxwell
    mxw.sh stop

    # 停止日志采集 Flume
    f102.sh stop

    # 停止业务消费 Flume
    f103_db.sh stop

    # 停止日志消费 Flume
    f104_log.sh stop

    # 停止 Kafka 采集集群
    kf.sh stop

    # 停止 Hadoop 集群
    hadoop.sh stop

    # 循环直至 Kafka 集群进程全部停止（最多等待 60 秒）
    kafka_count=$(xcall jps | grep 'kafka\.Kafka' | wc -l)
    retry=0
    while [ $kafka_count -gt 0 ]
    do
        sleep 1
        retry=$((retry + 1))
        kafka_count=$(xcall jps | grep 'kafka\.Kafka' | wc -l)
        echo "当前未停止的 Kafka 进程数为 $kafka_count"
        if [ $retry -ge 60 ]; then
            echo "[WARN] Kafka 进程未在 60 秒内全部停止，强制继续"
            break
        fi
    done

    # 停止 Zookeeper 集群
    zk.sh stop
};;
*)
    echo "Usage: $0 {start|stop}"
    exit 1
;;
esac
