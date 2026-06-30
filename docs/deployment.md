# 项目部署说明

## 概述

本文档记录了 GMall 离线数据仓库项目从零开始的完整部署步骤。部署环境基于 **CentOS 7**，使用 **3 台虚拟机**搭建 Hadoop 大数据集群。

---

## 一、环境准备

### 1.1 服务器规划

| 主机名 | IP | 内存 | 硬盘 | 角色 |
|--------|-----|------|------|------|
| hadoop102 | 192.168.x.102 | ≥8GB | ≥100GB | Master 节点 |
| hadoop103 | 192.168.x.103 | ≥8GB | ≥100GB | Worker 节点 |
| hadoop104 | 192.168.x.104 | ≥8GB | ≥100GB | Worker 节点 |

### 1.2 基础环境配置

```bash
# 1. 修改主机名
hostnamectl set-hostname hadoop102  # 在各节点执行

# 2. 配置 hosts 文件
cat >> /etc/hosts << EOF
192.168.x.102 hadoop102
192.168.x.103 hadoop103
192.168.x.104 hadoop104
EOF

# 3. 关闭防火墙
systemctl stop firewalld
systemctl disable firewalld

# 4. 配置 SSH 免密登录
ssh-keygen -t rsa
ssh-copy-id hadoop102
ssh-copy-id hadoop103
ssh-copy-id hadoop104

# 5. 安装 JDK 1.8
# 解压并配置 JAVA_HOME 环境变量
```

### 1.3 编写分发脚本

```bash
#!/bin/bash
# xsync: 集群分发脚本
# 用法: xsync <文件路径>

if [ $# -lt 1 ]; then
    echo "Usage: xsync <file>"
    exit
fi

for host in hadoop102 hadoop103 hadoop104; do
    echo "========== $host =========="
    rsync -av $1 $host:$1
done
```

---

## 二、Hadoop 集群部署

### 2.1 安装 Hadoop 3.3.4

```bash
# 解压安装包
tar -zxvf hadoop-3.3.4.tar.gz -C /opt/module/

# 配置环境变量
# 在 /etc/profile.d/my_env.sh 中添加:
export HADOOP_HOME=/opt/module/hadoop-3.3.4
export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin
```

### 2.2 核心配置文件

**1. core-site.xml** — 配置 NameNode 地址和存储目录

```xml
<property>
    <name>fs.defaultFS</name>
    <value>hdfs://hadoop102:8020</value>
</property>
<property>
    <name>hadoop.tmp.dir</name>
    <value>/opt/module/hadoop-3.3.4/data</value>
</property>
```

**2. hdfs-site.xml** — 配置 NameNode 和 SecondaryNameNode Web 地址

```xml
<property>
    <name>dfs.namenode.http-address</name>
    <value>hadoop102:9870</value>
</property>
<property>
    <name>dfs.replication</name>
    <value>2</value>
</property>
```

**3. yarn-site.xml** — 配置 ResourceManager 和内存限制

```xml
<property>
    <name>yarn.resourcemanager.hostname</name>
    <value>hadoop103</value>
</property>
<property>
    <name>yarn.nodemanager.resource.memory-mb</name>
    <value>4096</value>
</property>
```

**4. mapred-site.xml** — 配置执行引擎为 YARN

```xml
<property>
    <name>mapreduce.framework.name</name>
    <value>yarn</value>
</property>
```

### 2.3 格式化并启动

```bash
# 格式化 NameNode（首次部署执行一次）
hdfs namenode -format

# 启动 Hadoop 集群
start-dfs.sh       # 在 hadoop102 执行
start-yarn.sh      # 在 hadoop103 执行
mapred --daemon start historyserver  # 历史服务器
```

---

## 三、ZooKeeper 部署

```bash
# 解压安装
tar -zxvf apache-zookeeper-3.7.1-bin.tar.gz -C /opt/module/

# 修改配置
# 1. zoo.cfg
dataDir=/opt/module/zookeeper-3.7.1/zkDatas
server.2=hadoop102:2888:3888
server.3=hadoop103:2888:3888
server.4=hadoop104:2888:3888

# 2. 创建 myid 文件（每节点不同）
echo 2 > /opt/module/zookeeper-3.7.1/zkDatas/myid  # hadoop102
echo 3 > /opt/module/zookeeper-3.7.1/zkDatas/myid  # hadoop103
echo 4 > /opt/module/zookeeper-3.7.1/zkDatas/myid  # hadoop104
```

---

## 四、Kafka 部署

```bash
# 解压安装
tar -zxvf kafka_2.12-3.6.1.tgz -C /opt/module/

# 修改 server.properties（每节点修改 broker.id）
broker.id=0                              # 各节点: 0/1/2
log.dirs=/opt/module/kafka_2.12-3.6.1/datas
zookeeper.connect=hadoop102:2181,hadoop103:2181,hadoop104:2181/kafka

# 启动
kafka-server-start.sh -daemon config/server.properties
```

---

## 五、Flume 部署

```bash
# 解压安装
tar -zxvf apache-flume-1.10.1-bin.tar.gz -C /opt/module/

# 复制自定义拦截器 JAR 包到 lib 目录
cp gmall-flume-interceptor.jar /opt/module/flume-1.10.1/lib/
```

---

## 六、Maxwell 部署

```bash
# 1. 开启 MySQL Binlog
# 修改 /etc/my.cnf，添加：
server-id = 1
log-bin = mysql-bin
binlog_format = row
binlog-do-db = gmall

# 2. 重启 MySQL
systemctl restart mysqld

# 3. 创建 Maxwell 用户
CREATE DATABASE maxwell;
CREATE USER 'maxwell'@'%' IDENTIFIED BY 'maxwell';
GRANT ALL ON maxwell.* TO 'maxwell'@'%';
GRANT SELECT, REPLICATION CLIENT, REPLICATION SLAVE ON *.* TO 'maxwell'@'%';

# 4. 解压并配置 Maxwell
tar -zxvf maxwell-1.29.2.tar.gz -C /opt/module/
# 编辑 config.properties
```

---

## 七、DataX 部署

```bash
# DataX 无需编译，直接解压即可使用
tar -zxvf datax.tar.gz -C /opt/module/

# 验证
python /opt/module/datax/bin/datax.py /opt/module/datax/job/job.json
```

---

## 八、Hive on Spark 部署

### 8.1 安装 Hive 3.1.3

```bash
tar -zxvf apache-hive-3.1.3-bin.tar.gz -C /opt/module/

# 配置 hive-site.xml（关键配置）:
# - 元数据库连接 (MySQL)
# - Metastore 服务地址
# - 执行引擎切换为 Spark
```

### 8.2 配置 Spark 3.3.1

```bash
# 使用纯净版 Spark（without-hadoop）
tar -zxvf spark-3.3.1-bin-without-hadoop.tgz -C /opt/module/

# 配置 spark-env.sh
export SPARK_DIST_CLASSPATH=$(hadoop classpath)

# 上传 Spark JAR 到 HDFS
hadoop fs -mkdir /spark-jars
hadoop fs -put /opt/module/spark-3.3.1/jars/* /spark-jars

# 在 hive-site.xml 中添加:
# hive.execution.engine=spark
# spark.yarn.jars=hdfs://hadoop102:8020/spark-jars/*
```

### 8.3 初始化 Hive 元数据

```bash
# 创建元数据库
mysql -uroot -p -e "CREATE DATABASE metastore;"

# 初始化
schematool -initSchema -dbType mysql -verbose

# 修改字符集（支持中文）
ALTER TABLE COLUMNS_V2 MODIFY COLUMN COMMENT VARCHAR(256) CHARACTER SET utf8;
ALTER TABLE TABLE_PARAMS MODIFY COLUMN PARAM_VALUE MEDIUMTEXT CHARACTER SET utf8;
```

### 8.4 启动 Hive 服务

```bash
# 启动 Metastore（后台）
nohup hive --service metastore > /opt/module/hive/logs/metastore.log 2>&1 &

# 启动 HiveServer2（后台）
nohup hive --service hiveserver2 > /opt/module/hive/logs/hiveServer2.log 2>&1 &
```

---

## 九、DolphinScheduler 部署

```bash
# 1. 解压
tar -zxvf apache-dolphinscheduler-2.0.5-bin.tar.gz

# 2. 创建元数据库
mysql -uroot -p -e "CREATE DATABASE dolphinscheduler DEFAULT CHARSET utf8;"

# 3. 修改一键部署配置
vim conf/config/install_config.conf
# 修改: ips, masters, workers, alertServer, apiServers, installPath,
#       deployUser, javaHome, 数据库连接信息

# 4. 执行一键部署
bash bin/install.sh

# 5. 启动
cd /opt/module/dolphinscheduler
bash bin/start-all.sh
```

---

## 十、MySQL 报表库部署

```bash
# 创建报表数据库
mysql -uroot -p -e "
CREATE DATABASE IF NOT EXISTS gmall_report
DEFAULT CHARSET utf8
COLLATE utf8_general_ci;
"

# 执行建表 SQL
mysql -uroot -p gmall_report < sql/export/mysql/create_ads_tables.sql
```

---

## 十一、验证部署

```bash
# 1. 检查所有服务进程
xcall jps

# 2. 启动数据采集通道
caiji_cluster.sh start

# 3. 生成模拟数据
lg.sh

# 4. 检查 HDFS 数据
hdfs dfs -ls /origin_data/gmall/

# 5. 执行每日调度
bash scheduler/offline_daily.sh 2022-06-08

# 6. 检查 Hive 表数据
beeline -u jdbc:hive2://hadoop102:10000 -e "SELECT COUNT(*) FROM gmall.ads_traffic_stats_by_channel;"

# 7. 检查 MySQL 报表数据
mysql -uroot -p -e "SELECT * FROM gmall_report.ads_traffic_stats_by_channel LIMIT 10;"
```

---

## 常见问题

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| Hive 连接失败 | Metastore 未启动 | 检查 Metastore 进程，端口 9083 |
| DataX 任务失败 | MySQL 驱动缺失 | 将 mysql-connector-java.jar 放入 datax/lib/ |
| Flume OOM | JVM 内存不足 | 调整 flume-env.sh 中的 JAVA_OPTS |
| Kafka 消息堆积 | 消费者处理慢 | 增大 Flume batchSize 或增加消费者实例 |
