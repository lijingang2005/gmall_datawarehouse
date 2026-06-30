# GMall 电商离线数据仓库

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Hadoop](https://img.shields.io/badge/Hadoop-3.3.4-orange.svg)](https://hadoop.apache.org/)
[![Hive](https://img.shields.io/badge/Hive-3.1.3-yellow.svg)](https://hive.apache.org/)
[![Spark](https://img.shields.io/badge/Spark-3.3.1-red.svg)](https://spark.apache.org/)
[![Kafka](https://img.shields.io/badge/Kafka-3.6.1-white.svg)](https://kafka.apache.org/)

## 📖 项目简介

本项目是一个完整的**电商离线数据仓库系统**，基于 **Hadoop 大数据生态技术栈**，实现了从数据采集、数据同步、数据建模到数据分析与报表导出的全流程数据仓库解决方案。

以模拟的电商平台（GMall）为业务场景，涵盖**用户行为日志**和**业务数据库**两大核心数据源，构建了标准的 **ODS → DIM → DWD → DWS → ADS** 五层数据仓库架构，并通过 **DolphinScheduler** 实现全流程自动化工作流调度。

> 📚 详细文档请查看 [docs/](docs/) 目录。

---

## 🏗️ 系统架构

```
                          ┌──────────────────────────────┐
                          │    DolphinScheduler 调度层    │
                          │      全流程 DAG 编排          │
                          └──────────────┬───────────────┘
                                         ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           数据应用层 (Application)                       │
│                    报表系统  ·  数据大屏  ·  业务分析                      │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │ MySQL (gmall_report) ← DataX 导出
┌─────────────────────────────────┴───────────────────────────────────────┐
│                    离线数据仓库  (Hive on Spark)                          │
│                                                                          │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │  ADS 层 — 业务出口，支撑报表/大屏                                  │   │
│   │  流量主题 · 用户主题 · 订单主题 · 活动主题 · 优惠券主题            │   │
│   ├─────────────────────────────────────────────────────────────────┤   │
│   │  DWS 层 — 公共汇总，按主题预聚合                                   │   │
│   │  流量域 · 用户域 · 交易域 · 活动域 · 优惠券域                      │   │
│   ├─────────────────────────────────────────────────────────────────┤   │
│   │  DWD 层 — 清洗标准化，事务级明细                                   │   │
│   │  行为日志明细 · 业务事务事实 · 维度退化                            │   │
│   ├─────────────────────────────────────────────────────────────────┤   │
│   │  DIM 层 — 统一维度，拉链表/全量快照                                │   │
│   │  用户 · 商品 · 品牌 · 品类 · 日期 · 地区                          │   │
│   ├─────────────────────────────────────────────────────────────────┤   │
│   │  ODS 层 — 原始数据备份，贴源层                                     │   │
│   │  用户行为日志原始数据 · 业务数据库原始快照                           │   │
│   └─────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │ HDFS
┌─────────────────────────────────┴───────────────────────────────────────┐
│                         数据采集与同步层                                  │
│                                                                          │
│   日志文件 ──▶ Flume ──▶ Kafka(topic_log) ──▶ Flume+拦截器 ──▶ HDFS     │
│   MySQL ────▶ Maxwell ──▶ Kafka(topic_db) ──▶ Flume+拦截器 ──▶ HDFS     │
│   MySQL ────▶ DataX ──────────────────────────────▶ HDFS (全量同步)      │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## 🔄 数据流转全流程

```
数据生成 → 数据采集 → 数据同步 → 数仓分层计算 → 数据导出到MySQL
    │          │         │           │              │
    ▼          ▼         ▼           ▼              ▼
 Mock数据   Flume+   Kafka→HDFS   Hive on       DataX
 生成器     Kafka    同步落盘     Spark计算      →MySQL
```

| 阶段 | 描述 | 关键技术 |
|------|------|----------|
| ① **数据生成** | 模拟电商用户行为（浏览/点击/下单/支付）与 34 张业务表数据 | Java Mock + MySQL |
| ② **用户行为采集** | 日志文件 → Flume(TAILDIR) → Kafka(topic_log) → Flume → HDFS | Flume + Kafka |
| ③ **业务数据采集** | MySQL Binlog → Maxwell → Kafka(topic_db) → Flume → HDFS | Maxwell + Flume |
| ④ **全量同步** | MySQL 维度表 → DataX → HDFS（支持日期传参） | DataX |
| ⑤ **数仓计算** | ODS → DIM → DWD → DWS → ADS 五层递进计算 | Hive on Spark |
| ⑥ **数据导出** | ADS 报表数据 → DataX → MySQL(gmall_report) | DataX |
| ⑦ **任务调度** | 全流程自动化编排与定时调度 | DolphinScheduler |

---

## 🛠️ 技术栈

| 类别 | 技术组件 | 版本 | 用途 |
|------|----------|------|------|
| **分布式存储** | Hadoop HDFS | 3.3.4 | 分布式文件存储 |
| **资源调度** | YARN | 3.3.4 | 集群资源管理与任务调度 |
| **计算引擎** | Hive on Spark | 3.1.3 + 3.3.1 | 数据仓库 ETL 计算 |
| **元数据存储** | MySQL | 8.0.31 | Hive 元数据 + 业务数据存储 |
| **消息队列** | Kafka | 3.6.1 | 数据采集缓冲与解耦 |
| **日志采集** | Flume | 1.10.1 | 日志数据采集与传输 |
| **CDC 工具** | Maxwell | 1.29.2 | MySQL Binlog 增量采集 |
| **离线同步** | DataX | - | 异构数据源离线同步 |
| **协调服务** | ZooKeeper | 3.7.1 | 分布式协调与集群管理 |
| **任务调度** | DolphinScheduler | 2.0.5 | 全流程工作流编排与定时调度 |
| **开发语言** | Java / Shell / Python / HQL | - | 拦截器 / 脚本 / 数据处理 |

---

## 📂 项目结构

```
gmall-offline-datawarehouse/
│
├── README.md                          # 项目介绍（本文件）
├── LICENSE                            # 开源协议
├── .gitignore                         # Git 忽略规则
├── .gitattributes                     # Git 换行符规范
│
├── docs/                              # 项目文档
│   ├── architecture.md                # 系统整体架构
│   ├── data-collection.md             # 数据采集流程
│   ├── warehouse-design.md            # 数仓分层设计
│   ├── table-design.md                # 表结构设计
│   ├── scheduler.md                   # 调度流程
│   ├── deployment.md                  # 项目部署说明
│   └── development.md                 # 开发规范
│
├── images/                            # README 引用图片
│   └── .gitkeep
│
├── conf/                              # 配置文件（已脱敏）
│   ├── flume/
│   ├── maxwell/
│   ├── datax/
│   └── hive/
│
├── sql/                               # Hive SQL
│   ├── ods/
│   ├── dwd/
│   ├── dim/
│   ├── dws/
│   ├── ads/
│   └── export/
│
├── script/                            # Shell 脚本
│   ├── common/                        # 公共脚本
│   ├── collect/                       # 数据采集
│   ├── ods/
│   ├── dwd/
│   ├── dim/
│   ├── dws/
│   ├── ads/
│   └── export/                        # 数据导出
│
└── scheduler/                         # 调度入口
    ├── offline_daily.sh
    ├── offline_weekly.sh
    └── offline_monthly.sh
```

---

## 📊 数据仓库分层设计

| 分层 | 全称 | 定位 | 存储策略 |
|------|------|------|----------|
| **ODS** | Operational Data Store | 原始数据备份，贴源层 | 按日分区，gzip 压缩 |
| **DIM** | Dimension | 统一维度视图 | 全量快照 / 拉链表 |
| **DWD** | Data Warehouse Detail | 事务级明细，清洗标准化 | 按日分区 |
| **DWS** | Data Warehouse Summary | 主题域汇总，公共复用 | 1d/nd/td 多窗口 |
| **ADS** | Application Data Service | 业务出口，直接支撑报表 | 按日分区 |

### 核心报表指标

| 报表 | 分析维度 | 业务价值 |
|------|----------|----------|
| 各渠道流量统计 | 渠道 + 1/7/30天 | 评估渠道引流效果 |
| 页面路径分析 | 来源→目标页面 | 分析用户浏览路径 |
| 用户变动统计 | 日期 | 监控新增/流失/回流 |
| 用户留存率 | 新增日期 + 留存天数 | 评估用户粘性 |
| 用户行为漏斗 | 首页→详情→加购→下单→支付 | 定位转化瓶颈 |
| 各品牌复购率 | 品牌 + 最近30日 | 评估品牌忠诚度 |

---

## 🚀 快速开始

### 环境要求

- **操作系统**：CentOS 7.0+
- **JDK**：1.8+
- **集群**：3 节点 (hadoop102/103/104)，≥ 8GB 内存/节点

### 集群部署

| 节点 | 核心组件 |
|------|----------|
| **hadoop102** | NameNode, ResourceManager, Hive Metastore/Server2, Kafka, ZK, Maxwell, DolphinScheduler Master/Worker, Flume 采集端 |
| **hadoop103** | DataNode, NodeManager, Kafka, ZK, DS Worker, Flume 业务消费端 |
| **hadoop104** | DataNode, NodeManager, 2NN, Kafka, ZK, DS Worker, Flume 日志消费端 |

### 一键启动

```bash
# 启动数据采集集群
caiji_cluster.sh start

# 启动 Hive 服务
hive.sh start

# 启动 DolphinScheduler
cd /opt/module/dolphinscheduler && bin/start-all.sh

# 每日调度
cd scheduler && bash offline_daily.sh <日期>
```

> 📚 详细部署说明请查看 [docs/deployment.md](docs/deployment.md)。

---

## 🔧 核心技术亮点

- **Flume 时间戳拦截器** — 解决 Kafka → HDFS 的零点漂移问题，确保按业务时间分区
- **Maxwell 全量+增量同步** — Bootstrap 机制完成首日全量 + Binlog 实时增量
- **DataX 动态传参** — 支持 `-Ddt=日期`，适配 T+1 离线调度
- **用户维度拉链表** — `start_date/end_date` 记录历史效期，兼顾存储与回溯
- **Hive on Spark** — 替换默认 MR 引擎，大幅提升 ETL 性能
- **DolphinScheduler DAG** — 全流程串联为一条工作流，实现自动化定时调度

---

## 📄 License

本项目基于 Apache License 2.0 协议开源，仅用于学习与教学目的。

---

*最后更新时间：2026-07-01*
