-- ===================================================
-- DIM 层建表：维度表
-- 用途：构建一致性维度，为上层分析提供统一的"看数据的视角"
-- ===================================================

-- ----------------------------
-- 用户维度拉链表
-- 策略：追踪用户历史变化，通过 start_date/end_date 标记有效期
-- ----------------------------
DROP TABLE IF EXISTS gmall.dim_user;
CREATE EXTERNAL TABLE gmall.dim_user
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
    `create_time`  STRING COMMENT '注册时间',
    `operate_time` STRING COMMENT '最近修改时间',
    `start_date`   STRING COMMENT '有效期起始日期',
    `end_date`     STRING COMMENT '有效期结束日期(9999-12-31表示当前有效)'
)
COMMENT '用户维度拉链表'
PARTITIONED BY (`dt` STRING)
STORED AS PARQUET
LOCATION '/warehouse/gmall/dim/dim_user/'
TBLPROPERTIES ('parquet.compression'='snappy');

-- ----------------------------
-- 商品维度表（星型模型宽表）
-- 策略：整合 SKU/SPU/品类/品牌/属性，反规范化设计
-- ----------------------------
DROP TABLE IF EXISTS gmall.dim_sku;
CREATE EXTERNAL TABLE gmall.dim_sku
(
    `id`                  STRING COMMENT 'SKU_ID',
    `spu_id`              STRING COMMENT 'SPU_ID',
    `price`               DECIMAL(16,2) COMMENT '价格',
    `sku_name`            STRING COMMENT 'SKU名称',
    `sku_desc`            STRING COMMENT '商品规格描述',
    `weight`              DECIMAL(16,2) COMMENT '重量',
    `is_sale`             STRING COMMENT '是否销售',
    `tm_id`               STRING COMMENT '品牌ID',
    `tm_name`             STRING COMMENT '品牌名称',
    `category3_id`        STRING COMMENT '三级品类ID',
    `category3_name`      STRING COMMENT '三级品类名称',
    `category2_id`        STRING COMMENT '二级品类ID',
    `category2_name`      STRING COMMENT '二级品类名称',
    `category1_id`        STRING COMMENT '一级品类ID',
    `category1_name`      STRING COMMENT '一级品类名称',
    `spu_name`            STRING COMMENT 'SPU名称',
    `create_time`         STRING COMMENT '创建时间'
)
COMMENT '商品维度宽表'
PARTITIONED BY (`dt` STRING)
STORED AS PARQUET
LOCATION '/warehouse/gmall/dim/dim_sku/'
TBLPROPERTIES ('parquet.compression'='snappy');

-- ----------------------------
-- 日期维度表
-- ----------------------------
DROP TABLE IF EXISTS gmall.dim_date;
CREATE EXTERNAL TABLE gmall.dim_date
(
    `date_id`      STRING COMMENT '日期ID(yyyy-MM-dd)',
    `week_id`      STRING COMMENT '周ID(yyyy-ww)',
    `week_day`     STRING COMMENT '周几(1-7)',
    `day_of_month` STRING COMMENT '当月第几天',
    `month_id`     STRING COMMENT '月ID(yyyy-MM)',
    `quarter_id`   STRING COMMENT '季度ID(yyyy-Qn)',
    `year_id`      STRING COMMENT '年ID',
    `is_workday`   STRING COMMENT '是否工作日',
    `holiday_name` STRING COMMENT '节假日名称'
)
COMMENT '日期维度表'
STORED AS PARQUET
LOCATION '/warehouse/gmall/dim/dim_date/'
TBLPROPERTIES ('parquet.compression'='snappy');

-- ----------------------------
-- 省份维度表
-- ----------------------------
DROP TABLE IF EXISTS gmall.dim_province;
CREATE EXTERNAL TABLE gmall.dim_province
(
    `id`         STRING COMMENT '省份ID',
    `name`       STRING COMMENT '省份名称',
    `region_id`  STRING COMMENT '地区ID',
    `region_name` STRING COMMENT '地区名称',
    `area_code`  STRING COMMENT '行政区位码',
    `iso_code`   STRING COMMENT 'ISO编码'
)
COMMENT '省份维度表'
PARTITIONED BY (`dt` STRING)
STORED AS PARQUET
LOCATION '/warehouse/gmall/dim/dim_province/'
TBLPROPERTIES ('parquet.compression'='snappy');

-- ----------------------------
-- 优惠券维度表
-- ----------------------------
DROP TABLE IF EXISTS gmall.dim_coupon;
CREATE EXTERNAL TABLE gmall.dim_coupon
(
    `id`               STRING COMMENT '优惠券ID',
    `coupon_name`      STRING COMMENT '优惠券名称',
    `coupon_type`      STRING COMMENT '券类型：1-现金券 2-折扣券 3-满减券 4-满件打折券',
    `condition_amount` STRING COMMENT '满额数',
    `condition_num`    STRING COMMENT '满件数',
    `activity_id`      STRING COMMENT '活动编号',
    `benefit_amount`   STRING COMMENT '减免金额',
    `benefit_discount` STRING COMMENT '折扣',
    `limit_num`        STRING COMMENT '最多领用次数',
    `range_type`       STRING COMMENT '范围类型：1-商品 2-品类 3-品牌',
    `start_time`       STRING COMMENT '领取开始时间',
    `end_time`         STRING COMMENT '领取结束时间',
    `expire_time`      STRING COMMENT '过期时间'
)
COMMENT '优惠券维度表'
PARTITIONED BY (`dt` STRING)
STORED AS PARQUET
LOCATION '/warehouse/gmall/dim/dim_coupon/'
TBLPROPERTIES ('parquet.compression'='snappy');
