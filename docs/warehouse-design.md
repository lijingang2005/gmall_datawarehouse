# 数仓分层设计

## 概述

本项目采用经典的**五层数据仓库架构**：ODS → DIM → DWD → DWS → ADS，每层有明确的数据定位和职责边界。

## 分层架构

| 分层 | 全称 | 定位 | 存储格式 | 表数 |
|------|------|------|----------|------|
| **ODS** | Operational Data Store | 原始数据备份，贴源层 | gzip（TEXTFILE / JsonSerDe）| 31 |
| **DIM** | Dimension | 统一维度视图，一致性维度 | ORC + snappy | 8 |
| **DWD** | Data Warehouse Detail | 事务级明细，清洗标准化 | ORC + snappy | 10 |
| **DWS** | Data Warehouse Summary | 主题域汇总，公共复用（1d/nd/td）| ORC + snappy | 13 |
| **ADS** | Application Data Service | 业务出口，直接支撑报表 | ORC + snappy | 16 |

---

## 各层详细设计

### 一、ODS 层（31 张）

**数据来源**：
- 用户行为日志：HDFS `/origin_data/gmall/log/topic_log/`（JSON，JsonSerDe 解析为 STRUCT）
- 业务全量数据：HDFS `/origin_data/gmall/db/{table}_full/`（TSV，`\t` 分隔）
- 业务增量数据：HDFS `/origin_data/gmall/db/{table}_inc/`（JSON，JsonSerDe 解析为 STRUCT+MAP）

**表分类**：
- 日志表 1 张：`ods_log_inc`
- 全量表 17 张：同步策略为每日全量快照
- 增量表 13 张：同步策略为 Maxwell CDC 增量 + 首日 Maxwell Bootstrap 全量

**命名规范**：`ods_{表名}_{全量/增量标识}`（full=全量, inc=增量）
**分区策略**：按 `dt`（日期）分区，gzip 压缩

---

### 二、DIM 层（8 张）

**设计要点**：
- 星型模型优先，维度表适度反规范化
- 需要追踪历史的维度（用户）采用拉链表（zip）
- 其他维度采用每日全量快照（full）
- 同一维度只建一张表，多个事实表复用

**维度表清单**：

| 维度表 | 策略 | 粒度 | 核心属性 |
|--------|------|------|----------|
| dim_user_zip | 拉链表 | 用户 | 用户信息 + start_date/end_date 有效期 |
| dim_sku_full | 全量快照 | SKU | 商品+SPU+品类+品牌+平台属性+销售属性 |
| dim_coupon_full | 全量快照 | 优惠券 | 券类型名称、优惠规则、范围类型名称 |
| dim_activity_full | 全量快照 | 活动规则 | 活动名称、活动类型名称、优惠规则 |
| dim_province_full | 全量快照 | 省份 | 省份名、地区名、ISO编码 |
| dim_promotion_pos_full | 全量快照 | 营销坑位 | 坑位位置、类型 |
| dim_promotion_refer_full | 全量快照 | 营销渠道 | 渠道名称 |
| dim_date | 一次性初始化 | 天 | 日期、周、月、季、年、节假日 |

**命名规范**：`dim_{维度名}_{策略标识}`（full=全量快照, zip=拉链表）

---

### 三、DWD 层（10 张）

**核心处理**：字段统一、数据清洗、维度退化、JSON 解析。

**事实表分类**：
- **事务事实表**（7 张）：记录最细粒度的业务事件
- **周期快照事实表**（1 张）：按固定时间间隔记录状态
- **累积快照事实表**（1 张）：跟踪业务流程的多个里程碑

**按数据域分类**：

| 数据域 | 表名 | 类型 | 粒度 |
|--------|------|------|------|
| 流量域 | dwd_traffic_page_view_inc | 事务 | 每次页面浏览 |
| 交易域 | dwd_trade_cart_add_inc | 事务 | 每次加购 |
| 交易域 | dwd_trade_order_detail_inc | 事务 | 每件商品 |
| 交易域 | dwd_trade_pay_detail_suc_inc | 事务 | 每笔支付 |
| 交易域 | dwd_trade_cart_full | 周期快照 | 购物车商品 |
| 交易域 | dwd_trade_trade_flow_acc | 累积快照 | 每个订单(下单→支付→收货) |
| 工具域 | dwd_tool_coupon_used_inc | 事务 | 每次优惠券使用 |
| 互动域 | dwd_interaction_favor_add_inc | 事务 | 每次收藏 |
| 用户域 | dwd_user_register_inc | 事务 | 每次注册 |
| 用户域 | dwd_user_login_inc | 事务 | 每次登录 |

**命名规范**：`dwd_{数据域}_{业务过程}_{周期标识}`（inc=增量, full=全量, acc=累积）

---

### 四、DWS 层（13 张）

**设计原则**：
- 按主题域组织（流量/交易/工具/互动/用户）
- 采用三个时间窗口：1d（最近1日）、nd（最近N日）、td（历史至今）
- 从 DWD 层聚合，关联 DIM 层补全维度属性

**汇总表清单**：

| 分类 | 表名 | 粒度 | 周期 |
|------|------|------|------|
| 交易-商品 | dws_trade_user_sku_order_1d | 用户×商品 | 1d |
| 交易-用户 | dws_trade_user_order_1d | 用户 | 1d |
| 交易-用户 | dws_trade_user_cart_add_1d | 用户 | 1d |
| 交易-用户 | dws_trade_user_payment_1d | 用户 | 1d |
| 交易-省份 | dws_trade_province_order_1d | 省份 | 1d |
| 工具 | dws_tool_user_coupon_coupon_used_1d | 用户×优惠券 | 1d |
| 互动 | dws_interaction_sku_favor_add_1d | 商品 | 1d |
| 流量-会话 | dws_traffic_session_page_view_1d | 会话 | 1d |
| 流量-访客 | dws_traffic_page_visitor_page_view_1d | 访客×页面 | 1d |
| 交易-商品 | dws_trade_user_sku_order_nd | 用户×商品 | 7d/30d |
| 交易-省份 | dws_trade_province_order_nd | 省份 | 7d/30d |
| 交易-用户 | dws_trade_user_order_td | 用户 | td |
| 用户 | dws_user_user_login_td | 用户 | td |

**命名规范**：`dws_{数据域}_{统计粒度}_{业务过程}_{统计周期}`

---

### 五、ADS 层（16 张）

**设计原则**：面向具体业务场景高度定制，使用幂等 INSERT 模式确保可重入。

**报表清单**：

| 报表 | 维度 | 周期 |
|------|------|------|
| ads_traffic_stats_by_channel | 渠道 | 1/7/30天 |
| ads_page_path | 来源→目标页面 | 1天 |
| ads_user_change | 日期 | 1天 |
| ads_user_retention | 新增日期 | 1-7天 |
| ads_user_stats | 日期 | 1/7/30天 |
| ads_user_action | 日期（漏斗）| 1天 |
| ads_new_order_user_stats | 日期 | 1/7/30天 |
| ads_order_continuously_user_count | 日期 | 7天 |
| ads_repeat_purchase_by_tm | 品牌 | 30天 |
| ads_order_stats_by_tm | 品牌 | 1/7/30天 |
| ads_order_stats_by_cate | 品类 | 1/7/30天 |
| ads_order_by_province | 省份 | 1/7/30天 |
| ads_coupon_stats | 优惠券 | 1天 |
| ads_sku_cart_num_top3_by_cate | 品类+商品 | 1天 |
| ads_sku_favor_count_top3_by_tm | 品牌+商品 | 1天 |
| ads_order_to_pay_interval_avg | 日期 | 1天 |

---

## 数据流向

```
ODS（30张：日志+全量+增量）
  │
  ├──▶ DIM（8张：拉链表+全量快照，每日覆盖）
  │
  └──▶ DWD（10张：事务+周期快照+累积快照，每日增量）
          │
          ├──▶ DWS 1d（9张：按日汇总）
          │       │
          │       ├──▶ DWS nd（2张：7/30日窗口聚合）
          │       │
          │       └──▶ DWS td（2张：历史累计聚合）
          │
          └──▶ ADS（16张：面向报表场景定制）
                    │
                    └──▶ MySQL gmall_report（DataX 导出，16 张表）
```
