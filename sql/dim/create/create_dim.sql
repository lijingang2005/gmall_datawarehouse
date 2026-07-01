-- ===================================================
-- DIM 层建表：维度表
-- 用途：构建一致性维度，为上层分析提供统一的"看数据的视角"
-- 存储格式：ORC 列式存储 + snappy 压缩
-- ===================================================

-- ----------------------------
-- 1. 商品维度表（星型模型宽表）
-- 策略：整合 SKU/SPU/品类/品牌/平台属性/销售属性，反规范化设计
-- ----------------------------
DROP TABLE IF EXISTS gmall.dim_sku_full;
CREATE EXTERNAL TABLE gmall.dim_sku_full
(
    `id`                   STRING COMMENT 'SKU_ID',
    `price`                DECIMAL(16, 2) COMMENT '商品价格',
    `sku_name`             STRING COMMENT '商品名称',
    `sku_desc`             STRING COMMENT '商品描述',
    `weight`               DECIMAL(16, 2) COMMENT '重量',
    `is_sale`              BOOLEAN COMMENT '是否在售',
    `spu_id`               STRING COMMENT 'SPU编号',
    `spu_name`             STRING COMMENT 'SPU名称',
    `category3_id`         STRING COMMENT '三级品类ID',
    `category3_name`       STRING COMMENT '三级品类名称',
    `category2_id`         STRING COMMENT '二级品类id',
    `category2_name`       STRING COMMENT '二级品类名称',
    `category1_id`         STRING COMMENT '一级品类ID',
    `category1_name`       STRING COMMENT '一级品类名称',
    `tm_id`                STRING COMMENT '品牌ID',
    `tm_name`              STRING COMMENT '品牌名称',
    `sku_attr_values`      ARRAY<STRUCT<attr_id :STRING,
        value_id :STRING,
        attr_name :STRING,
        value_name:STRING>> COMMENT '平台属性',
    `sku_sale_attr_values` ARRAY<STRUCT<sale_attr_id :STRING,
        sale_attr_value_id :STRING,
        sale_attr_name :STRING,
        sale_attr_value_name:STRING>> COMMENT '销售属性',
    `create_time`          STRING COMMENT '创建时间'
) COMMENT '商品维度表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dim/dim_sku_full/'
    TBLPROPERTIES ('orc.compress'='snappy');

-- ----------------------------
-- 2. 优惠券维度表
-- 策略：关联字典表，编码与名称共存，计算优惠规则
-- ----------------------------
DROP TABLE IF EXISTS gmall.dim_coupon_full;
CREATE EXTERNAL TABLE gmall.dim_coupon_full
(
    `id`               STRING COMMENT '优惠券编号',
    `coupon_name`      STRING COMMENT '优惠券名称',
    `coupon_type_code` STRING COMMENT '优惠券类型编码',
    `coupon_type_name` STRING COMMENT '优惠券类型名称',
    `condition_amount` DECIMAL(16, 2) COMMENT '满额数',
    `condition_num`    BIGINT COMMENT '满件数',
    `activity_id`      STRING COMMENT '活动编号',
    `benefit_amount`   DECIMAL(16, 2) COMMENT '减免金额',
    `benefit_discount` DECIMAL(16, 2) COMMENT '折扣',
    `benefit_rule`     STRING COMMENT '优惠规则:满元*减*元，满*件打*折',
    `create_time`      STRING COMMENT '创建时间',
    `range_type_code`  STRING COMMENT '优惠范围类型编码',
    `range_type_name`  STRING COMMENT '优惠范围类型名称',
    `limit_num`        BIGINT COMMENT '最多领取次数',
    `taken_count`      BIGINT COMMENT '已领取次数',
    `start_time`       STRING COMMENT '可以领取的开始时间',
    `end_time`         STRING COMMENT '可以领取的结束时间',
    `operate_time`     STRING COMMENT '修改时间',
    `expire_time`      STRING COMMENT '过期时间'
) COMMENT '优惠券维度表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dim/dim_coupon_full/'
    TBLPROPERTIES ('orc.compress'='snappy');

-- ----------------------------
-- 3. 活动维度表
-- 策略：活动规则为主维表，关联活动信息 + 字典表
-- ----------------------------
DROP TABLE IF EXISTS gmall.dim_activity_full;
CREATE EXTERNAL TABLE gmall.dim_activity_full
(
    `activity_rule_id`   STRING COMMENT '活动规则ID',
    `activity_id`        STRING COMMENT '活动ID',
    `activity_name`      STRING COMMENT '活动名称',
    `activity_type_code` STRING COMMENT '活动类型编码',
    `activity_type_name` STRING COMMENT '活动类型名称',
    `activity_desc`      STRING COMMENT '活动描述',
    `start_time`         STRING COMMENT '开始时间',
    `end_time`           STRING COMMENT '结束时间',
    `create_time`        STRING COMMENT '创建时间',
    `condition_amount`   DECIMAL(16, 2) COMMENT '满减金额',
    `condition_num`      BIGINT COMMENT '满减件数',
    `benefit_amount`     DECIMAL(16, 2) COMMENT '优惠金额',
    `benefit_discount`   DECIMAL(16, 2) COMMENT '优惠折扣',
    `benefit_rule`       STRING COMMENT '优惠规则',
    `benefit_level`      STRING COMMENT '优惠级别'
) COMMENT '活动维度表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dim/dim_activity_full/'
    TBLPROPERTIES ('orc.compress'='snappy');

-- ----------------------------
-- 4. 省份维度表
-- 策略：省份表关联地区表
-- ----------------------------
DROP TABLE IF EXISTS gmall.dim_province_full;
CREATE EXTERNAL TABLE gmall.dim_province_full
(
    `id`            STRING COMMENT '省份ID',
    `province_name` STRING COMMENT '省份名称',
    `area_code`     STRING COMMENT '地区编码',
    `iso_code`      STRING COMMENT '旧版国际标准地区编码，供可视化使用',
    `iso_3166_2`    STRING COMMENT '新版国际标准地区编码，供可视化使用',
    `region_id`     STRING COMMENT '地区ID',
    `region_name`   STRING COMMENT '地区名称'
) COMMENT '地区维度表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dim/dim_province_full/'
    TBLPROPERTIES ('orc.compress'='snappy');

-- ----------------------------
-- 5. 营销坑位维度表
-- 策略：直接从 ODS 映射
-- ----------------------------
DROP TABLE IF EXISTS gmall.dim_promotion_pos_full;
CREATE EXTERNAL TABLE gmall.dim_promotion_pos_full
(
    `id`             STRING COMMENT '营销坑位ID',
    `pos_location`   STRING COMMENT '营销坑位位置',
    `pos_type`       STRING COMMENT '营销坑位类型',
    `promotion_type` STRING COMMENT '营销类型',
    `create_time`    STRING COMMENT '创建时间',
    `operate_time`   STRING COMMENT '修改时间'
) COMMENT '营销坑位维度表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dim/dim_promotion_pos_full/'
    TBLPROPERTIES ('orc.compress'='snappy');

-- ----------------------------
-- 6. 营销渠道维度表
-- 策略：直接从 ODS 映射
-- ----------------------------
DROP TABLE IF EXISTS gmall.dim_promotion_refer_full;
CREATE EXTERNAL TABLE gmall.dim_promotion_refer_full
(
    `id`           STRING COMMENT '营销渠道ID',
    `refer_name`   STRING COMMENT '营销渠道名称',
    `create_time`  STRING COMMENT '创建时间',
    `operate_time` STRING COMMENT '修改时间'
) COMMENT '营销渠道维度表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dim/dim_promotion_refer_full/'
    TBLPROPERTIES ('orc.compress'='snappy');

-- ----------------------------
-- 7. 日期维度表
-- 策略：没有分区（数据量小），从 CSV/TSV 文件导入
-- ----------------------------
DROP TABLE IF EXISTS gmall.dim_date;
CREATE EXTERNAL TABLE gmall.dim_date
(
    `date_id`    STRING COMMENT '日期ID',
    `week_id`    STRING COMMENT '周ID,一年中的第几周',
    `week_day`   STRING COMMENT '周几',
    `day`        STRING COMMENT '每月的第几天',
    `month`      STRING COMMENT '一年中的第几月',
    `quarter`    STRING COMMENT '一年中的第几季度',
    `year`       STRING COMMENT '年份',
    `is_workday` STRING COMMENT '是否是工作日',
    `holiday_id` STRING COMMENT '节假日'
) COMMENT '日期维度表'
    STORED AS ORC
    LOCATION '/warehouse/gmall/dim/dim_date/'
    TBLPROPERTIES ('orc.compress'='snappy');

-- ----------------------------
-- 8. 用户维度拉链表
-- 策略：通过 start_date/end_date 追踪用户历史变化
--       dt='9999-12-31' 分区存储当前有效记录
-- ----------------------------
DROP TABLE IF EXISTS gmall.dim_user_zip;
CREATE EXTERNAL TABLE gmall.dim_user_zip
(
    `id`           STRING COMMENT '用户ID',
    `login_name`   STRING COMMENT '用户名称',
    `nick_name`    STRING COMMENT '用户昵称',
    `name`         STRING COMMENT '用户姓名',
    `phone_num`    STRING COMMENT '手机号码',
    `email`        STRING COMMENT '邮箱',
    `user_level`   STRING COMMENT '用户等级',
    `birthday`     STRING COMMENT '生日',
    `gender`       STRING COMMENT '性别',
    `create_time`  STRING COMMENT '创建时间',
    `operate_time` STRING COMMENT '操作时间',
    `start_date`   STRING COMMENT '开始日期',
    `end_date`     STRING COMMENT '结束日期'
) COMMENT '用户维度拉链表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dim/dim_user_zip/'
    TBLPROPERTIES ('orc.compress'='snappy');
