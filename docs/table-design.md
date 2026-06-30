# 表结构设计

## 概述

本文档记录了 GMall 数据仓库中各层的核心表结构设计。完整建表 SQL 参见 `sql/` 目录。

---

## 一、ODS 层表结构

### 1.1 用户行为日志表

```sql
-- ods_log_inc: 用户行为日志增量表
CREATE EXTERNAL TABLE ods_log_inc
(
    `common`   STRING COMMENT '环境信息 JSON',
    `page`     STRING COMMENT '页面信息 JSON',
    `actions`  STRING COMMENT '动作列表 JSON',
    `displays` STRING COMMENT '曝光列表 JSON',
    `err`      STRING COMMENT '错误信息 JSON',
    `start`    STRING COMMENT '启动信息 JSON',
    `ts`       STRING COMMENT '时间戳'
)
PARTITIONED BY (`dt` STRING)
STORED AS TEXTFILE
LOCATION '/origin_data/gmall/log/topic_log';
```

### 1.2 业务全量表

```sql
-- ods_activity_info_full: 活动信息全量表
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
STORED AS TEXTFILE;
```

### 1.3 业务增量表

```sql
-- ods_order_info_inc: 订单信息增量表
CREATE EXTERNAL TABLE ods_order_info_inc
(
    `type` STRING COMMENT '变更类型: insert/update/delete',
    `ts`   STRING COMMENT '变更时间戳',
    `data` STRUCT<
        id:STRING,
        consignee:STRING,
        total_amount:STRING,
        order_status:STRING,
        user_id:STRING,
        -- ... 其它字段
    > COMMENT '数据内容',
    `old`  MAP<STRING,STRING> COMMENT '变更前数据(update时)'
)
PARTITIONED BY (`dt` STRING)
STORED AS TEXTFILE;
```

---

## 二、DIM 层核心表结构

### 2.1 用户维度拉链表

```sql
DROP TABLE IF EXISTS dim_user;
CREATE EXTERNAL TABLE dim_user
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
    `end_date`     STRING COMMENT '有效期结束日期'
)
COMMENT '用户维度拉链表'
PARTITIONED BY (`dt` STRING)
STORED AS PARQUET;
```

### 2.2 商品维度表（星型宽表）

```sql
DROP TABLE IF EXISTS dim_sku;
CREATE EXTERNAL TABLE dim_sku
(
    `id`                STRING COMMENT 'SKU_ID',
    `spu_id`            STRING COMMENT 'SPU_ID',
    `price`             STRING COMMENT '价格',
    `sku_name`          STRING COMMENT 'SKU名称',
    `sku_desc`          STRING COMMENT '商品规格描述',
    `weight`            STRING COMMENT '重量',
    `tm_id`             STRING COMMENT '品牌ID',
    `tm_name`           STRING COMMENT '品牌名称',
    `category3_id`      STRING COMMENT '三级品类ID',
    `category3_name`    STRING COMMENT '三级品类名称',
    `category2_id`      STRING COMMENT '二级品类ID',
    `category2_name`    STRING COMMENT '二级品类名称',
    `category1_id`      STRING COMMENT '一级品类ID',
    `category1_name`    STRING COMMENT '一级品类名称',
    `spu_name`          STRING COMMENT 'SPU名称',
    `create_time`       STRING COMMENT '创建时间'
)
COMMENT '商品维度宽表'
PARTITIONED BY (`dt` STRING)
STORED AS PARQUET;
```

### 2.3 日期维度表

```sql
DROP TABLE IF EXISTS dim_date;
CREATE EXTERNAL TABLE dim_date
(
    `date_id`        STRING COMMENT '日期ID',
    `week_id`        STRING COMMENT '周ID',
    `week_day`       STRING COMMENT '周几(1-7)',
    `day_of_month`   STRING COMMENT '当月第几天',
    `month_id`       STRING COMMENT '月ID',
    `quarter_id`     STRING COMMENT '季度ID',
    `year_id`        STRING COMMENT '年ID',
    `is_workday`     STRING COMMENT '是否工作日',
    `holiday_name`   STRING COMMENT '节假日名称'
)
COMMENT '日期维度表'
STORED AS PARQUET;
```

---

## 三、DWD 层核心表结构

### 3.1 页面浏览明细表

```sql
DROP TABLE IF EXISTS dwd_traffic_page_log_inc;
CREATE EXTERNAL TABLE dwd_traffic_page_log_inc
(
    `province_id`    STRING COMMENT '省份ID',
    `brand`          STRING COMMENT '手机品牌',
    `channel`        STRING COMMENT '渠道',
    `is_new`         STRING COMMENT '是否首日使用',
    `model`          STRING COMMENT '手机型号',
    `mid`            STRING COMMENT '设备ID',
    `operate_system` STRING COMMENT '操作系统',
    `user_id`        STRING COMMENT '会员ID',
    `version_code`   STRING COMMENT 'APP版本号',
    `during_time`    BIGINT COMMENT '停留时长(ms)',
    `page_item`      STRING COMMENT '目标ID',
    `page_item_type` STRING COMMENT '目标类型',
    `last_page_id`   STRING COMMENT '上一页面ID',
    `page_id`        STRING COMMENT '页面ID',
    `source_type`    STRING COMMENT '来源类型',
    `session_id`     STRING COMMENT '会话ID',
    `ts`             BIGINT COMMENT '时间戳'
)
PARTITIONED BY (`dt` STRING)
STORED AS PARQUET;
```

### 3.2 下单明细表

```sql
DROP TABLE IF EXISTS dwd_trade_order_detail_inc;
CREATE EXTERNAL TABLE dwd_trade_order_detail_inc
(
    `id`                    STRING COMMENT '编号',
    `order_id`              STRING COMMENT '订单ID',
    `user_id`               STRING COMMENT '用户ID',
    `sku_id`                STRING COMMENT 'SKU_ID',
    `sku_name`              STRING COMMENT 'SKU名称',
    `province_id`           STRING COMMENT '省份ID',
    `order_price`           STRING COMMENT '下单价格',
    `sku_num`               STRING COMMENT '购买数量',
    `total_amount`          STRING COMMENT '总金额',
    `activity_reduce_amount` STRING COMMENT '活动减免金额',
    `coupon_reduce_amount`  STRING COMMENT '优惠券减免金额',
    `original_total_amount` STRING COMMENT '原价金额',
    `feight_fee`            STRING COMMENT '运费',
    `create_time`           STRING COMMENT '创建时间'
)
PARTITIONED BY (`dt` STRING)
STORED AS PARQUET;
```

---

## 四、DWS 层核心表结构

### 4.1 流量域会话粒度日汇总

```sql
DROP TABLE IF EXISTS dws_traffic_session_page_view_1d;
CREATE EXTERNAL TABLE dws_traffic_session_page_view_1d
(
    `mid`              STRING COMMENT '设备ID',
    `user_id`          STRING COMMENT '用户ID',
    `province_id`      STRING COMMENT '省份ID',
    `channel`          STRING COMMENT '渠道',
    `is_new`           STRING COMMENT '是否新用户',
    `version_code`     STRING COMMENT '版本号',
    `during_time_sec`  BIGINT COMMENT '会话停留时长(秒)',
    `page_count`       BIGINT COMMENT '浏览页面数',
    `session_id`       STRING COMMENT '会话ID'
)
PARTITIONED BY (`dt` STRING)
STORED AS PARQUET;
```

### 4.2 交易域品牌粒度 N 日汇总

```sql
DROP TABLE IF EXISTS dws_trade_order_tm_nd;
CREATE EXTERNAL TABLE dws_trade_order_tm_nd
(
    `tm_id`         STRING COMMENT '品牌ID',
    `tm_name`       STRING COMMENT '品牌名称',
    `order_count`   BIGINT COMMENT '订单数',
    `user_count`    BIGINT COMMENT '用户数',
    `order_amount`  DECIMAL(16,2) COMMENT '订单金额'
)
PARTITIONED BY (`dt` STRING)
STORED AS PARQUET;
```

---

## 五、ADS 层核心表结构

### 5.1 各渠道流量统计

```sql
DROP TABLE IF EXISTS ads_traffic_stats_by_channel;
CREATE EXTERNAL TABLE ads_traffic_stats_by_channel
(
    `dt`               STRING COMMENT '统计日期',
    `recent_days`      BIGINT COMMENT '最近天数(1/7/30)',
    `channel`          STRING COMMENT '渠道',
    `uv_count`         BIGINT COMMENT '访客人数',
    `avg_duration_sec` BIGINT COMMENT '会话平均停留时长(秒)',
    `avg_page_count`   BIGINT COMMENT '会话平均浏览页面数',
    `sv_count`         BIGINT COMMENT '会话数',
    `bounce_rate`      DECIMAL(16,2) COMMENT '跳出率'
)
STORED AS PARQUET;
```

### 5.2 用户行为漏斗分析

```sql
DROP TABLE IF EXISTS ads_user_action;
CREATE EXTERNAL TABLE ads_user_action
(
    `dt`                STRING COMMENT '统计日期',
    `home_count`        BIGINT COMMENT '浏览首页人数',
    `good_detail_count` BIGINT COMMENT '浏览商品详情页人数',
    `cart_count`        BIGINT COMMENT '加购人数',
    `order_count`       BIGINT COMMENT '下单人数',
    `payment_count`     BIGINT COMMENT '支付人数'
)
STORED AS PARQUET;
```
