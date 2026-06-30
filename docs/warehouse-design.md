# 数仓分层设计

## 概述

本项目采用经典的**五层数据仓库架构**，遵循"高内聚、低耦合"的设计原则，每层有明确的数据定位和职责边界。数据从 ODS 贴源层逐步加工到 ADS 应用层，数据粒度逐渐由明细到汇总。

## 分层架构

```
┌─────────────────────────────────────────────────────────────────┐
│  ADS 层 (Application Data Service)                              │
│  业务出口 — 高度定制化报表，直接支撑业务决策                        │
├─────────────────────────────────────────────────────────────────┤
│  DWS 层 (Data Warehouse Summary)                                │
│  公共汇总 — 按主题域预聚合，避免重复计算，提升查询效率               │
├─────────────────────────────────────────────────────────────────┤
│  DWD 层 (Data Warehouse Detail)                                 │
│  清洗标准化 — 维度退化、字段统一、数据清洗，提供干净明细数据         │
├─────────────────────────────────────────────────────────────────┤
│  DIM 层 (Dimension)                                             │
│  统一视角 — 管理一致性维度属性，贯穿各层提供标准化实体描述           │
├─────────────────────────────────────────────────────────────────┤
│  ODS 层 (Operational Data Store)                                │
│  原始备份 — 原样同步业务数据，屏蔽底层异构差异，数据追溯兜底        │
└─────────────────────────────────────────────────────────────────┘
```

## 各层详细设计

### 一、ODS 层（贴源层）

**定位**：原始数据的第一落脚点，保持与源系统一致，不做任何业务加工。

**数据来源**：
- 用户行为日志（HDFS：`/origin_data/gmall/log/topic_log/`）
- 业务全量数据（HDFS：`/origin_data/gmall/db/{table}_full/`）
- 业务增量数据（HDFS：`/origin_data/gmall/db/{table}_inc/`）

**存储格式**：
- 用户行为日志：JSON 原样存储，gzip 压缩
- 业务数据：TSV 格式存储（\t 分隔），gzip 压缩

**表命名规范**：`ods_{源系统}_{源表名}_{全量/增量标识}`
- 例：`ods_log_inc` — 用户行为日志增量表
- 例：`ods_activity_info_full` — 活动信息全量表
- 例：`ods_order_info_inc` — 订单信息增量表

**分区策略**：按 `dt`（日期）分区

---

### 二、DIM 层（维度层）

**定位**：构建一致性维度，为上层分析提供标准化的"看数据的视角"。

**设计要点**：

1. **星型模型优先** — 维度表适度反规范化，减少 Join 操作，提升查询性能
2. **维度变化管理** — 对需要追踪历史的维度（如用户）采用拉链表
3. **维度唯一性** — 同一维度只建一张表，多个事实表复用

**维度表清单**：

| 维度表 | 更新策略 | 粒度 | 核心属性 |
|--------|----------|------|----------|
| dim_user | 拉链表 | 用户 | 用户等级、生日、性别、注册时间 |
| dim_sku | 全量快照 | SKU | 商品名、价格、品类、品牌、属性 |
| dim_date | 一次性初始化 | 天 | 日期、周、月、季、年、节假日 |
| dim_province | 全量快照 | 省份 | 省份名、地区、ISO 编码 |
| dim_coupon | 全量快照 | 优惠券 | 券类型、金额、折扣、使用规则 |

**拉链表设计（以用户维度为例）**：

```sql
-- dim_user 拉链表结构
CREATE TABLE dim_user (
    id            STRING COMMENT '用户ID',
    login_name    STRING COMMENT '用户名',
    nick_name     STRING COMMENT '昵称',
    user_level    STRING COMMENT '用户等级',
    birthday      STRING COMMENT '生日',
    gender        STRING COMMENT '性别',
    start_date    STRING COMMENT '有效期起始日期',
    end_date      STRING COMMENT '有效期结束日期 (9999-12-31 表示当前有效)'
) COMMENT '用户维度拉链表'
PARTITIONED BY (dt STRING)
STORED AS PARQUET;
```

---

### 三、DWD 层（明细层）

**定位**：对 ODS 数据进行清洗、标准化、维度退化，输出干净可信的事务级明细数据。

**核心处理步骤**：

1. **字段统一** — 统一字段命名、数据类型、编码格式
2. **数据清洗** — 过滤脏数据、处理空值、去重
3. **维度退化** — 将高频使用的维度属性退化到事实表中，减少 Join
4. **JSON 解析** — 将用户行为日志的 JSON 字段解析为结构化列

**明细表清单**：

| 类别 | 表名 | 描述 | 粒度 |
|------|------|------|------|
| 行为日志 | dwd_traffic_page_log_inc | 页面浏览明细 | 每次浏览 |
| 行为日志 | dwd_traffic_action_inc | 用户动作明细 | 每个动作 |
| 行为日志 | dwd_traffic_display_inc | 商品曝光明细 | 每次曝光 |
| 行为日志 | dwd_traffic_error_inc | 错误日志明细 | 每次报错 |
| 行为日志 | dwd_traffic_start_inc | 应用启动明细 | 每次启动 |
| 业务事务 | dwd_trade_order_detail_inc | 下单明细 | 每件商品 |
| 业务事务 | dwd_trade_pay_detail_inc | 支付明细 | 每笔支付 |
| 业务事务 | dwd_trade_cart_add_inc | 加购明细 | 每次加购 |
| 业务事务 | dwd_trade_refund_inc | 退款明细 | 每笔退款 |
| 业务事务 | dwd_interaction_favor_inc | 收藏明细 | 每次收藏 |
| 业务事务 | dwd_interaction_comment_inc | 评价明细 | 每条评价 |
| 业务事务 | dwd_tool_coupon_get_inc | 领券明细 | 每次领券 |

**表命名规范**：`dwd_{主题域}_{业务过程}_{周期标识}`

---

### 四、DWS 层（汇总层）

**定位**：按分析主题预聚合，沉淀公共宽表，避免在 ADS 层重复计算。

**设计原则**：
- 按主题域组织（流量域、用户域、交易域、活动域、优惠券域）
- 采用**最近 n 日窗口**（1d / nd / td）覆盖不同分析粒度
- 一个主题域 + 一个时间窗口 = 一张 DWS 表

**主题域与汇总表**：

| 主题域 | 1天窗口 | N天窗口(7/30) | 累计窗口 |
|--------|---------|---------------|----------|
| 流量域 | dws_traffic_session_page_view_1d | dws_traffic_page_view_nd | — |
| 用户域 | dws_user_user_login_1d | dws_user_user_login_nd | dws_user_user_login_td |
| 交易域 | dws_trade_order_1d | dws_trade_order_nd | dws_trade_user_order_td |
| 活动域 | dws_activity_order_1d | dws_activity_order_nd | — |
| 优惠券域 | dws_tool_coupon_used_1d | dws_tool_coupon_used_nd | — |

**汇总维度示例**：渠道、省份、品牌、品类、活动、优惠券类型等

**核心指标示例**：

| 指标 | 计算口径 |
|------|----------|
| UV（独立访客数） | COUNT(DISTINCT mid) |
| SV（会话数） | COUNT(DISTINCT sid) |
| 跳出率 | 单页会话数 / 总会话数 |
| 平均停留时长 | SUM(during_time) / COUNT(sid) |
| 新增用户数 | 当日首次登录用户数 |
| 留存率 | 某日新增用户中 N 日后仍活跃的比例 |
| GMV | SUM(order_price * sku_num) |

---

### 五、ADS 层（应用层）

**定位**：面向具体业务场景高度定制化，直接支撑报表系统、数据大屏。

**ADS 报表清单**：

| 报表 | 粒度 | 说明 |
|------|------|------|
| ads_traffic_stats_by_channel | 渠道 + 最近 n 日 | 各渠道流量统计 |
| ads_page_path | 来源页面 + 目标页面 | 用户浏览路径分析 |
| ads_user_change | 日期 | 用户变动统计（流失/回流） |
| ads_user_retention | 新增日期 + 留存天数 | 用户留存率分析 |
| ads_user_stats | 日期 + 最近 n 日 | 新增/活跃用户统计 |
| ads_user_action | 日期 | 用户行为漏斗分析 |
| ads_new_order_user_stats | 日期 + 最近 n 日 | 新增下单用户统计 |
| ads_order_continuously_user_count | 日期 | 连续三日下单用户统计 |
| ads_repeat_purchase_by_tm | 品牌 + 最近30日 | 各品牌复购率 |
| ads_order_stats_by_tm | 品牌 + 最近 n 日 | 各品牌交易统计 |
| ads_order_stats_by_cate | 品类 + 最近 n 日 | 各品类交易统计 |
| ads_order_stats_by_prov | 省份 + 最近 n 日 | 各省份交易统计 |

---

## 数据流向总结

```
ODS（原样同步）
  │
  ├──▶ DIM（维度管理：拉链表/全量快照）
  │
  └──▶ DWD（清洗标准化：维度退化 + 字段统一）
          │
          ├──▶ DWS 1d（按日汇总）
          │       │
          │       ├──▶ DWS nd（最近 n 日窗口聚合）
          │       │
          │       └──▶ DWS td（历史累计聚合）
          │
          └──▶ ADS（面向业务场景定制）
                    │
                    └──▶ MySQL（DataX 导出，供报表/大屏使用）
```
