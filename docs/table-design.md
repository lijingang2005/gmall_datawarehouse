# 表结构设计

## 概述

本文档记录了 GMall 数据仓库中各层的核心表结构设计。完整建表 SQL 参见 `sql/` 目录。

---

## 一、ODS 层表结构

ODS 层共 30 张表：日志表 1 张 + 全量表 17 张 + 增量表 12 张。

### 1.1 用户行为日志表 (ods_log_inc)

```sql
DROP TABLE IF EXISTS ods_log_inc;
CREATE EXTERNAL TABLE ods_log_inc
(
    `common`   STRUCT<ar:STRING, ba:STRING, ch:STRING, is_new:STRING,
                     md:STRING, mid:STRING, os:STRING, sid:STRING,
                     uid:STRING, vc:STRING> COMMENT '公共信息',
    `page`     STRUCT<during_time:STRING, item:STRING, item_type:STRING,
                     last_page_id:STRING, page_id:STRING, from_pos_id:STRING,
                     from_pos_seq:STRING, refer_id:STRING, sourceType:STRING>
                     COMMENT '页面信息',
    `actions`  ARRAY<STRUCT<action_id:STRING, item:STRING, item_type:STRING, ts:BIGINT>>
                     COMMENT '动作信息',
    `displays` ARRAY<STRUCT<display_type:STRING, item:STRING, item_type:STRING,
                     pos_seq:STRING, pos_id:STRING>> COMMENT '曝光信息',
    `start`    STRUCT<entry:STRING, first_open:BIGINT, loading_time:BIGINT,
                     open_ad_id:BIGINT, open_ad_ms:BIGINT, open_ad_skip_ms:BIGINT>
                     COMMENT '启动信息',
    `err`      STRUCT<error_code:BIGINT, msg:STRING> COMMENT '错误信息',
    `ts`       BIGINT COMMENT '时间戳'
)
PARTITIONED BY (`dt` STRING)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.JsonSerDe'
LOCATION '/warehouse/gmall/ods/ods_log_inc/'
TBLPROPERTIES ('compression.codec'='org.apache.hadoop.io.compress.GzipCodec');
```

### 1.2 业务全量表（17 张）

数据通过 DataX 从 MySQL 全量同步，TSV 格式（`\t` 分隔），gzip 压缩。

| 表名 | 说明 |
|------|------|
| ods_activity_info_full | 活动信息表 |
| ods_activity_rule_full | 活动规则表 |
| ods_base_category1_full | 一级品类表 |
| ods_base_category2_full | 二级品类表 |
| ods_base_category3_full | 三级品类表 |
| ods_base_dic_full | 编码字典表 |
| ods_base_province_full | 省份表 |
| ods_base_region_full | 地区表 |
| ods_base_trademark_full | 品牌表 |
| ods_cart_info_full | 购物车表 |
| ods_coupon_info_full | 优惠券信息表 |
| ods_sku_attr_value_full | 商品平台属性表 |
| ods_sku_info_full | 商品表 |
| ods_sku_sale_attr_value_full | 商品销售属性值表 |
| ods_spu_info_full | SPU表 |
| ods_promotion_pos_full | 营销坑位表 |
| ods_promotion_refer_full | 营销渠道表 |

```sql
-- 示例
CREATE EXTERNAL TABLE ods_activity_info_full
(
    `id`            STRING COMMENT '活动ID',
    `activity_name` STRING COMMENT '活动名称',
    `activity_type` STRING COMMENT '活动类型',
    `activity_desc` STRING COMMENT '活动描述',
    `start_time`    STRING COMMENT '开始时间',
    `end_time`      STRING COMMENT '结束时间',
    `create_time`   STRING COMMENT '创建时间',
    `operate_time`  STRING COMMENT '修改时间'
)
PARTITIONED BY (`dt` STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
NULL DEFINED AS ''
LOCATION '/warehouse/gmall/ods/ods_activity_info_full/'
TBLPROPERTIES ('compression.codec'='org.apache.hadoop.io.compress.GzipCodec');
```

### 1.3 业务增量表（12 张）

数据通过 Maxwell → Kafka → Flume 增量采集，JSON 格式，JsonSerDe 解析。

| 表名 | 说明 |
|------|------|
| ods_cart_info_inc | 购物车增量表 |
| ods_comment_info_inc | 评论增量表 |
| ods_coupon_use_inc | 优惠券领用增量表 |
| ods_favor_info_inc | 收藏增量表 |
| ods_order_detail_inc | 订单明细增量表 |
| ods_order_detail_activity_inc | 订单明细活动关联增量表 |
| ods_order_detail_coupon_inc | 订单明细优惠券关联增量表 |
| ods_order_info_inc | 订单增量表 |
| ods_order_refund_info_inc | 退单增量表 |
| ods_order_status_log_inc | 订单状态流水增量表 |
| ods_payment_info_inc | 支付增量表 |
| ods_refund_payment_inc | 退款增量表 |
| ods_user_info_inc | 用户增量表 |

```sql
-- 示例
CREATE EXTERNAL TABLE ods_order_info_inc
(
    `type` STRING COMMENT '变动类型',
    `ts`   BIGINT COMMENT '变动时间',
    `data` STRUCT<id:STRING, consignee:STRING, total_amount:DECIMAL(16,2),
                  order_status:STRING, user_id:STRING, ...> COMMENT '数据',
    `old`  MAP<STRING,STRING> COMMENT '旧值'
)
PARTITIONED BY (`dt` STRING)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.JsonSerDe'
LOCATION '/warehouse/gmall/ods/ods_order_info_inc/'
TBLPROPERTIES ('compression.codec'='org.apache.hadoop.io.compress.GzipCodec');
```

---

## 二、DIM 层核心表结构（8 张）

DIM 层使用 ORC 列式存储 + snappy 压缩，命名规范：`dim_{维度名}_{策略标识}`（full=全量快照, zip=拉链表）。

### 2.1 用户维度拉链表 (dim_user_zip)

使用 start_date/end_date 追踪用户历史变化，dt='9999-12-31' 分区存储当前有效记录。

```sql
DROP TABLE IF EXISTS gmall.dim_user_zip;
CREATE EXTERNAL TABLE gmall.dim_user_zip
(
    `id`           STRING COMMENT '用户ID',
    `login_name`   STRING COMMENT '用户名称',
    `nick_name`    STRING COMMENT '用户昵称',
    `name`         STRING COMMENT '用户姓名',
    `phone_num`    STRING COMMENT '手机号',
    `email`        STRING COMMENT '邮箱',
    `user_level`   STRING COMMENT '用户级别',
    `birthday`     STRING COMMENT '生日',
    `gender`       STRING COMMENT '性别',
    `create_time`  STRING COMMENT '创建时间',
    `operate_time` STRING COMMENT '修改时间',
    `start_date`   STRING COMMENT '有效期起始日期',
    `end_date`     STRING COMMENT '有效期结束日期(9999-12-31=当前有效)'
)
COMMENT '用户维度拉链表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dim/dim_user_zip/'
TBLPROPERTIES ('orc.compress'='snappy');
```

### 2.2 商品维度宽表 (dim_sku_full)

整合 SKU/SPU/品类/品牌/平台属性/销售属性，星型模型反规范化设计。

```sql
DROP TABLE IF EXISTS gmall.dim_sku_full;
CREATE EXTERNAL TABLE gmall.dim_sku_full
(
    `id`                   STRING COMMENT 'SKU_ID',
    `price`                DECIMAL(16,2) COMMENT '价格',
    `sku_name`             STRING COMMENT 'SKU名称',
    `sku_desc`             STRING COMMENT '商品规格描述',
    `weight`               DECIMAL(16,2) COMMENT '重量',
    `is_sale`              BOOLEAN COMMENT '是否在售',
    `spu_id`               STRING COMMENT 'SPU_ID',
    `spu_name`             STRING COMMENT 'SPU名称',
    `category3_id`         STRING COMMENT '三级品类ID',
    `category3_name`       STRING COMMENT '三级品类名称',
    `category2_id`         STRING COMMENT '二级品类ID',
    `category2_name`       STRING COMMENT '二级品类名称',
    `category1_id`         STRING COMMENT '一级品类ID',
    `category1_name`       STRING COMMENT '一级品类名称',
    `tm_id`                STRING COMMENT '品牌ID',
    `tm_name`              STRING COMMENT '品牌名称',
    `sku_attr_values`      ARRAY<STRUCT<attr_id:STRING, value_id:STRING,
                                attr_name:STRING, value_name:STRING>> COMMENT '平台属性',
    `sku_sale_attr_values` ARRAY<STRUCT<sale_attr_id:STRING, sale_attr_value_id:STRING,
                                sale_attr_name:STRING, sale_attr_value_name:STRING>> COMMENT '销售属性',
    `create_time`          STRING COMMENT '创建时间'
)
COMMENT '商品维度宽表'
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dim/dim_sku_full/'
TBLPROPERTIES ('orc.compress'='snappy');
```

### 2.3 其他维度表

| 表名 | 粒度 | 更新策略 | 核心字段 |
|------|------|----------|----------|
| dim_coupon_full | 优惠券 | 全量快照 | 券类型编码/名称、优惠规则(benefit_rule)、范围类型编码/名称 |
| dim_activity_full | 活动规则 | 全量快照 | 活动类型编码/名称、优惠规则、优惠级别 |
| dim_province_full | 省份 | 全量快照 | 省份名、地区名、行政区位码、ISO编码(iso_code, iso_3166_2) |
| dim_promotion_pos_full | 营销坑位 | 全量快照 | 坑位位置、坑位类型、营销类型 |
| dim_promotion_refer_full | 营销渠道 | 全量快照 | 渠道名称 |
| dim_date | 天 | 一次性初始化 | 日期ID、周/月/季/年、工作日、节假日 |

---

## 三、DWD 层核心表结构（10 张）

DWD 层使用 ORC 列式存储 + snappy 压缩，命名规范：`dwd_{数据域}_{业务过程}_{周期标识}`。

| 数据域 | 表名 | 粒度 | 类型 |
|--------|------|------|------|
| 流量域 | dwd_traffic_page_view_inc | 每次页面浏览 | 事务事实表 |
| 交易域 | dwd_trade_cart_add_inc | 每次加购 | 事务事实表 |
| 交易域 | dwd_trade_order_detail_inc | 每件商品 | 事务事实表 |
| 交易域 | dwd_trade_pay_detail_suc_inc | 每笔支付 | 事务事实表 |
| 交易域 | dwd_trade_cart_full | 购物车商品 | 周期快照事实表 |
| 交易域 | dwd_trade_trade_flow_acc | 每个订单 | 累积快照事实表 |
| 工具域 | dwd_tool_coupon_used_inc | 每次使用 | 事务事实表 |
| 互动域 | dwd_interaction_favor_add_inc | 每次收藏 | 事务事实表 |
| 用户域 | dwd_user_register_inc | 每次注册 | 事务事实表 |
| 用户域 | dwd_user_login_inc | 每次登录 | 事务事实表 |

### 3.1 页面浏览明细表 (dwd_traffic_page_view_inc)

```sql
CREATE EXTERNAL TABLE gmall.dwd_traffic_page_view_inc
(
    `province_id`    STRING COMMENT '省份ID',
    `brand`          STRING COMMENT '手机品牌',
    `channel`        STRING COMMENT '渠道',
    `is_new`         STRING COMMENT '是否首次启动',
    `model`          STRING COMMENT '手机型号',
    `mid_id`         STRING COMMENT '设备ID',
    `operate_system` STRING COMMENT '操作系统',
    `user_id`        STRING COMMENT '会员ID',
    `version_code`   STRING COMMENT 'APP版本号',
    `page_item`      STRING COMMENT '目标ID',
    `page_item_type` STRING COMMENT '目标类型',
    `last_page_id`   STRING COMMENT '上页ID',
    `page_id`        STRING COMMENT '页面ID',
    `from_pos_id`    STRING COMMENT '来源坑位ID',
    `from_pos_seq`   STRING COMMENT '来源坑位位置',
    `refer_id`       STRING COMMENT '营销渠道ID',
    `date_id`        STRING COMMENT '日期ID',
    `view_time`      STRING COMMENT '跳入时间',
    `session_id`     STRING COMMENT '所属会话ID',
    `during_time`    BIGINT COMMENT '持续时间毫秒'
)
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dwd/dwd_traffic_page_view_inc/'
TBLPROPERTIES ('orc.compress'='snappy');
```

### 3.2 下单明细表 (dwd_trade_order_detail_inc)

```sql
CREATE EXTERNAL TABLE gmall.dwd_trade_order_detail_inc
(
    `id`                     STRING COMMENT '编号',
    `order_id`               STRING COMMENT '订单ID',
    `user_id`                STRING COMMENT '用户ID',
    `sku_id`                 STRING COMMENT '商品ID',
    `province_id`            STRING COMMENT '省份ID',
    `activity_id`            STRING COMMENT '参与活动ID',
    `activity_rule_id`       STRING COMMENT '参与活动规则ID',
    `coupon_id`              STRING COMMENT '使用优惠券ID',
    `date_id`                STRING COMMENT '下单日期ID',
    `create_time`            STRING COMMENT '下单时间',
    `sku_num`                BIGINT COMMENT '商品数量',
    `split_original_amount`  DECIMAL(16,2) COMMENT '原始价格',
    `split_activity_amount`  DECIMAL(16,2) COMMENT '活动优惠分摊',
    `split_coupon_amount`    DECIMAL(16,2) COMMENT '优惠券优惠分摊',
    `split_total_amount`     DECIMAL(16,2) COMMENT '最终价格分摊'
)
PARTITIONED BY (`dt` STRING)
STORED AS ORC
LOCATION '/warehouse/gmall/dwd/dwd_trade_order_detail_inc/'
TBLPROPERTIES ('orc.compress'='snappy');
```

---

## 四、DWS 层核心表结构（13 张）

DWS 层使用 ORC + snappy，命名规范：`dws_{数据域}_{统计粒度}_{业务过程}_{统计周期}`。

### 一日汇总表（9 张）

| 表名 | 粒度 | 来源 |
|------|------|------|
| dws_trade_user_sku_order_1d | 用户×商品 | dwd_trade_order_detail_inc + dim_sku_full |
| dws_trade_user_order_1d | 用户 | dwd_trade_order_detail_inc |
| dws_trade_user_cart_add_1d | 用户 | dwd_trade_cart_add_inc |
| dws_trade_user_payment_1d | 用户 | dwd_trade_pay_detail_suc_inc |
| dws_trade_province_order_1d | 省份 | dwd_trade_order_detail_inc + dim_province_full |
| dws_tool_user_coupon_coupon_used_1d | 用户×优惠券 | dwd_tool_coupon_used_inc + dim_coupon_full |
| dws_interaction_sku_favor_add_1d | 商品 | dwd_interaction_favor_add_inc + dim_sku_full |
| dws_traffic_session_page_view_1d | 会话 | dwd_traffic_page_view_inc |
| dws_traffic_page_visitor_page_view_1d | 访客×页面 | dwd_traffic_page_view_inc |

### N 日汇总表（2 张）

| 表名 | 窗口 | 来源 |
|------|------|------|
| dws_trade_user_sku_order_nd | 7日 / 30日 | dws_trade_user_sku_order_1d |
| dws_trade_province_order_nd | 7日 / 30日 | dws_trade_province_order_1d |

### 历史至今汇总表（2 张）

| 表名 | 来源 |
|------|------|
| dws_trade_user_order_td | dws_trade_user_order_1d + 昨日 td |
| dws_user_user_login_td | dwd_user_login_inc + 昨日 td |

### 示例：流量域会话粒度日汇总

```sql
CREATE EXTERNAL TABLE gmall.dws_traffic_session_page_view_1d
(
    `session_id`      STRING COMMENT '会话ID',
    `mid_id`          STRING COMMENT '设备ID',
    `brand`           STRING COMMENT '手机品牌',
    `model`           STRING COMMENT '手机型号',
    `operate_system`  STRING COMMENT '操作系统',
    `version_code`    STRING COMMENT 'APP版本号',
    `channel`         STRING COMMENT '渠道',
    `during_time_1d`  BIGINT COMMENT '最近1日浏览时长(ms)',
    `page_count_1d`   BIGINT COMMENT '最近1日浏览页面数'
)
PARTITIONED BY (`dt` STRING)
STORED AS ORC
TBLPROPERTIES ('orc.compress'='snappy');
```

---

## 五、ADS 层核心表结构（16 张）

ADS 层使用 ORC + snappy，面向具体报表场景，使用幂等 INSERT 模式（`SELECT * FROM old UNION SELECT new`）。

### 流量主题（2 张）

| 表名 | 说明 | 维度 |
|------|------|------|
| ads_traffic_stats_by_channel | 各渠道流量统计 | 渠道 + 1/7/30天 |
| ads_page_path | 页面路径分析 | 来源页面 → 目标页面 |

### 用户主题（4 张）

| 表名 | 说明 |
|------|------|
| ads_user_change | 用户变动统计（流失/回流）|
| ads_user_retention | 用户留存率 |
| ads_user_stats | 用户新增活跃统计 |
| ads_user_action | 用户行为漏斗分析 |

### 交易主题（6 张）

| 表名 | 说明 |
|------|------|
| ads_order_stats_by_tm | 各品牌交易统计 |
| ads_order_stats_by_cate | 各品类商品下单统计 |
| ads_order_by_province | 各省份交易统计 |
| ads_new_order_user_stats | 新增下单用户统计 |
| ads_order_continuously_user_count | 连续3日下单用户统计 |
| ads_repeat_purchase_by_tm | 各品牌复购率 |

### 商品/优惠券主题（4 张）

| 表名 | 说明 |
|------|------|
| ads_sku_cart_num_top3_by_cate | 各品类购物车存量Top3 |
| ads_sku_favor_count_top3_by_tm | 各品牌商品收藏次数Top3 |
| ads_coupon_stats | 优惠券使用统计 |
| ads_order_to_pay_interval_avg | 下单到支付间隔平均值 |
