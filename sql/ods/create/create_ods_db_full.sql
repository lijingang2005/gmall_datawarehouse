-- ===================================================
-- ODS 层建表：业务数据全量表
-- 数据来源：/origin_data/gmall/db/{table}_full/
-- 同步工具：DataX（MySQL → HDFS）
-- ===================================================

-- ----------------------------
-- 活动信息表（全量表）
-- ----------------------------
DROP TABLE IF EXISTS gmall.ods_activity_info_full;
CREATE EXTERNAL TABLE gmall.ods_activity_info_full
(
    `id`              STRING COMMENT '活动id',
    `activity_name` STRING COMMENT '活动名称',
    `activity_type` STRING COMMENT '活动类型',
    `activity_desc` STRING COMMENT '活动描述',
    `start_time`     STRING COMMENT '开始时间',
    `end_time`        STRING COMMENT '结束时间',
    `create_time`    STRING COMMENT '创建时间',
    `operate_time`   STRING COMMENT '修改时间'
) COMMENT '活动信息表'
    PARTITIONED BY (`dt` STRING)
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    NULL DEFINED AS ''
LOCATION '/warehouse/gmall/ods/ods_activity_info_full/'
TBLPROPERTIES ('compression.codec'='org.apache.hadoop.io.compress.GzipCodec');

-- ----------------------------
-- 活动规则表（全量表）
-- ----------------------------
DROP TABLE IF EXISTS gmall.ods_activity_rule_full;
CREATE EXTERNAL TABLE gmall.ods_activity_rule_full
(
    `id`                  STRING COMMENT '编号',
    `activity_id`       STRING COMMENT '活动ID',
    `activity_type`     STRING COMMENT '活动类型',
    `condition_amount` DECIMAL(16, 2) COMMENT '满减金额',
    `condition_num`     BIGINT COMMENT '满减件数',
    `benefit_amount`    DECIMAL(16, 2) COMMENT '优惠金额',
    `benefit_discount` DECIMAL(16, 2) COMMENT '优惠折扣',
    `benefit_level`     STRING COMMENT '优惠级别',
    `create_time`       STRING COMMENT '创建时间',
    `operate_time`      STRING COMMENT '修改时间'
) COMMENT '活动规则表'
    PARTITIONED BY (`dt` STRING)
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    NULL DEFINED AS ''
LOCATION '/warehouse/gmall/ods/ods_activity_rule_full/'
TBLPROPERTIES ('compression.codec'='org.apache.hadoop.io.compress.GzipCodec');

-- ----------------------------
-- 一级品类表（全量表）
-- ----------------------------
DROP TABLE IF EXISTS gmall.ods_base_category1_full;
CREATE EXTERNAL TABLE gmall.ods_base_category1_full
(
    `id`               STRING COMMENT '编号',
    `name`             STRING COMMENT '分类名称',
    `create_time`    STRING COMMENT '创建时间',
    `operate_time`   STRING COMMENT '修改时间'
) COMMENT '一级品类表'
    PARTITIONED BY (`dt` STRING)
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    NULL DEFINED AS ''
LOCATION '/warehouse/gmall/ods/ods_base_category1_full/'
TBLPROPERTIES ('compression.codec'='org.apache.hadoop.io.compress.GzipCodec');

-- ----------------------------
-- 二级品类表（全量表）
-- ----------------------------
DROP TABLE IF EXISTS gmall.ods_base_category2_full;
CREATE EXTERNAL TABLE gmall.ods_base_category2_full
(
    `id`               STRING COMMENT '编号',
    `name`             STRING COMMENT '二级分类名称',
    `category1_id`   STRING COMMENT '一级分类编号',
    `create_time`    STRING COMMENT '创建时间',
    `operate_time`   STRING COMMENT '修改时间'
) COMMENT '二级品类表'
    PARTITIONED BY (`dt` STRING)
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    NULL DEFINED AS ''
LOCATION '/warehouse/gmall/ods/ods_base_category2_full/'
TBLPROPERTIES ('compression.codec'='org.apache.hadoop.io.compress.GzipCodec');

-- ----------------------------
-- 三级品类表（全量表）
-- ----------------------------
DROP TABLE IF EXISTS gmall.ods_base_category3_full;
CREATE EXTERNAL TABLE gmall.ods_base_category3_full
(
    `id`               STRING COMMENT '编号',
    `name`             STRING COMMENT '三级分类名称',
    `category2_id`   STRING COMMENT '二级分类编号',
    `create_time`    STRING COMMENT '创建时间',
    `operate_time`   STRING COMMENT '修改时间'
) COMMENT '三级品类表'
    PARTITIONED BY (`dt` STRING)
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    NULL DEFINED AS ''
LOCATION '/warehouse/gmall/ods/ods_base_category3_full/'
TBLPROPERTIES ('compression.codec'='org.apache.hadoop.io.compress.GzipCodec');

-- ----------------------------
-- 编码字典表（全量表）
-- ----------------------------
DROP TABLE IF EXISTS gmall.ods_base_dic_full;
CREATE EXTERNAL TABLE gmall.ods_base_dic_full
(
    `dic_code`     STRING COMMENT '编号',
    `dic_name`     STRING COMMENT '编码名称',
    `parent_code`  STRING COMMENT '父编号',
    `create_time`  STRING COMMENT '创建日期',
    `operate_time` STRING COMMENT '修改日期'
) COMMENT '编码字典表'
    PARTITIONED BY (`dt` STRING)
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    NULL DEFINED AS ''
LOCATION '/warehouse/gmall/ods/ods_base_dic_full/'
TBLPROPERTIES ('compression.codec'='org.apache.hadoop.io.compress.GzipCodec');

-- ----------------------------
-- 省份表（全量表）
-- ----------------------------
DROP TABLE IF EXISTS gmall.ods_base_province_full;
CREATE EXTERNAL TABLE gmall.ods_base_province_full
(
    `id`              STRING COMMENT '编号',
    `name`            STRING COMMENT '省份名称',
    `region_id`      STRING COMMENT '地区ID',
    `area_code`      STRING COMMENT '地区编码',
    `iso_code`   STRING COMMENT '旧版国际标准地区编码，供可视化使用',
    `iso_3166_2` STRING COMMENT '新版国际标准地区编码，供可视化使用',
    `create_time`    STRING COMMENT '创建时间',
    `operate_time`   STRING COMMENT '修改时间'
) COMMENT '省份表'
    PARTITIONED BY (`dt` STRING)
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    NULL DEFINED AS ''
LOCATION '/warehouse/gmall/ods/ods_base_province_full/'
TBLPROPERTIES ('compression.codec'='org.apache.hadoop.io.compress.GzipCodec');

-- ----------------------------
-- 地区表（全量表）
-- ----------------------------
DROP TABLE IF EXISTS gmall.ods_base_region_full;
CREATE EXTERNAL TABLE gmall.ods_base_region_full
(
    `id`               STRING COMMENT '地区ID',
    `region_name`    STRING COMMENT '地区名称',
    `create_time`    STRING COMMENT '创建时间',
    `operate_time`   STRING COMMENT '修改时间'
) COMMENT '地区表'
    PARTITIONED BY (`dt` STRING)
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    NULL DEFINED AS ''
LOCATION '/warehouse/gmall/ods/ods_base_region_full/'
TBLPROPERTIES ('compression.codec'='org.apache.hadoop.io.compress.GzipCodec');

-- ----------------------------
-- 品牌表（全量表）
-- ----------------------------
DROP TABLE IF EXISTS gmall.ods_base_trademark_full;
CREATE EXTERNAL TABLE gmall.ods_base_trademark_full
(
    `id`               STRING COMMENT '编号',
    `tm_name`         STRING COMMENT '品牌名称',
    `logo_url`        STRING COMMENT '品牌LOGO的图片路径',
    `create_time`    STRING COMMENT '创建时间',
    `operate_time`   STRING COMMENT '修改时间'
) COMMENT '品牌表'
    PARTITIONED BY (`dt` STRING)
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    NULL DEFINED AS ''
LOCATION '/warehouse/gmall/ods/ods_base_trademark_full/'
TBLPROPERTIES ('compression.codec'='org.apache.hadoop.io.compress.GzipCodec');

-- ----------------------------
-- 购物车表（全量表）
-- ----------------------------
DROP TABLE IF EXISTS gmall.ods_cart_info_full;
CREATE EXTERNAL TABLE gmall.ods_cart_info_full
(
    `id`            STRING COMMENT '编号',
    `user_id`      STRING COMMENT '用户ID',
    `sku_id`       STRING COMMENT 'SKU_ID',
    `cart_price`   DECIMAL(16, 2) COMMENT '放入购物车时价格',
    `sku_num`      BIGINT COMMENT '数量',
    `img_url`      STRING COMMENT '商品图片地址',
    `sku_name`     STRING COMMENT 'SKU名称 (冗余)',
    `is_checked`   STRING COMMENT '是否被选中',
    `create_time`  STRING COMMENT '创建时间',
    `operate_time` STRING COMMENT '修改时间',
    `is_ordered`   STRING COMMENT '是否已经下单',
    `order_time`   STRING COMMENT '下单时间'
) COMMENT '购物车全量表'
    PARTITIONED BY (`dt` STRING)
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    NULL DEFINED AS ''
LOCATION '/warehouse/gmall/ods/ods_cart_info_full/'
TBLPROPERTIES ('compression.codec'='org.apache.hadoop.io.compress.GzipCodec');

-- ----------------------------
-- 优惠券信息表（全量表）
-- ----------------------------
DROP TABLE IF EXISTS gmall.ods_coupon_info_full;
CREATE EXTERNAL TABLE gmall.ods_coupon_info_full
(
    `id`                 STRING COMMENT '购物券编号',
    `coupon_name`      STRING COMMENT '购物券名称',
    `coupon_type`      STRING COMMENT '购物券类型 1 现金券 2 折扣券 3 满减券 4 满件打折券',
    `condition_amount` DECIMAL(16, 2) COMMENT '满额数',
    `condition_num`    BIGINT COMMENT '满件数',
    `activity_id`      STRING COMMENT '活动编号',
    `benefit_amount`   DECIMAL(16, 2) COMMENT '减免金额',
    `benefit_discount` DECIMAL(16, 2) COMMENT '折扣',
    `create_time`      STRING COMMENT '创建时间',
    `range_type`       STRING COMMENT '范围类型 1、商品(SPUID) 2、品类(三级品类id) 3、品牌',
    `limit_num`        BIGINT COMMENT '最多领用次数',
    `taken_count`      BIGINT COMMENT '已领用次数',
    `start_time`       STRING COMMENT '可以领取的开始时间',
    `end_time`         STRING COMMENT '可以领取的结束时间',
    `operate_time`     STRING COMMENT '修改时间',
    `expire_time`      STRING COMMENT '过期时间',
    `range_desc`       STRING COMMENT '范围描述'
) COMMENT '优惠券信息表'
    PARTITIONED BY (`dt` STRING)
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    NULL DEFINED AS ''
LOCATION '/warehouse/gmall/ods/ods_coupon_info_full/'
TBLPROPERTIES ('compression.codec'='org.apache.hadoop.io.compress.GzipCodec');

-- ----------------------------
-- 商品平台属性表（全量表）
-- ----------------------------
DROP TABLE IF EXISTS gmall.ods_sku_attr_value_full;
CREATE EXTERNAL TABLE gmall.ods_sku_attr_value_full
(
    `id`              STRING COMMENT '编号',
    `attr_id`        STRING COMMENT '平台属性ID',
    `value_id`       STRING COMMENT '平台属性值ID',
    `sku_id`         STRING COMMENT 'SKU_ID',
    `attr_name`      STRING COMMENT '平台属性名称',
    `value_name`     STRING COMMENT '平台属性值名称',
    `create_time`    STRING COMMENT '创建时间',
    `operate_time`   STRING COMMENT '修改时间'
) COMMENT '商品平台属性表'
    PARTITIONED BY (`dt` STRING)
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    NULL DEFINED AS ''
LOCATION '/warehouse/gmall/ods/ods_sku_attr_value_full/'
TBLPROPERTIES ('compression.codec'='org.apache.hadoop.io.compress.GzipCodec');

-- ----------------------------
-- 商品表（全量表）
-- ----------------------------
DROP TABLE IF EXISTS gmall.ods_sku_info_full;
CREATE EXTERNAL TABLE gmall.ods_sku_info_full
(
    `id`                STRING COMMENT 'SKU_ID',
    `spu_id`           STRING COMMENT 'SPU_ID',
    `price`            DECIMAL(16, 2) COMMENT '价格',
    `sku_name`         STRING COMMENT 'SKU名称',
    `sku_desc`         STRING COMMENT 'SKU规格描述',
    `weight`           DECIMAL(16, 2) COMMENT '重量',
    `tm_id`             STRING COMMENT '品牌ID',
    `category3_id`     STRING COMMENT '三级品类ID',
    `sku_default_img` STRING COMMENT '默认显示图片地址',
    `is_sale`           STRING COMMENT '是否在售',
    `create_time`      STRING COMMENT '创建时间',
    `operate_time`     STRING COMMENT '修改时间'
) COMMENT '商品表'
    PARTITIONED BY (`dt` STRING)
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    NULL DEFINED AS ''
LOCATION '/warehouse/gmall/ods/ods_sku_info_full/'
TBLPROPERTIES ('compression.codec'='org.apache.hadoop.io.compress.GzipCodec');

-- ----------------------------
-- 商品销售属性值表（全量表）
-- ----------------------------
DROP TABLE IF EXISTS gmall.ods_sku_sale_attr_value_full;
CREATE EXTERNAL TABLE gmall.ods_sku_sale_attr_value_full
(
    `id`                      STRING COMMENT '编号',
    `sku_id`                 STRING COMMENT 'SKU_ID',
    `spu_id`                 STRING COMMENT 'SPU_ID',
    `sale_attr_value_id`   STRING COMMENT '销售属性值ID',
    `sale_attr_id`          STRING COMMENT '销售属性ID',
    `sale_attr_name`        STRING COMMENT '销售属性名称',
    `sale_attr_value_name` STRING COMMENT '销售属性值名称',
    `create_time`            STRING COMMENT '创建时间',
    `operate_time`           STRING COMMENT '修改时间'
) COMMENT '商品销售属性值表'
    PARTITIONED BY (`dt` STRING)
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    NULL DEFINED AS ''
LOCATION '/warehouse/gmall/ods/ods_sku_sale_attr_value_full/'
TBLPROPERTIES ('compression.codec'='org.apache.hadoop.io.compress.GzipCodec');

-- ----------------------------
-- SPU表（全量表）
-- ----------------------------
DROP TABLE IF EXISTS gmall.ods_spu_info_full;
CREATE EXTERNAL TABLE gmall.ods_spu_info_full
(
    `id`              STRING COMMENT 'SPU_ID',
    `spu_name`       STRING COMMENT 'SPU名称',
    `description`   STRING COMMENT '描述信息',
    `category3_id`  STRING COMMENT '三级品类ID',
    `tm_id`           STRING COMMENT '品牌ID',
    `create_time`    STRING COMMENT '创建时间',
    `operate_time`   STRING COMMENT '修改时间'
) COMMENT 'SPU表'
    PARTITIONED BY (`dt` STRING)
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    NULL DEFINED AS ''
LOCATION '/warehouse/gmall/ods/ods_spu_info_full/'
TBLPROPERTIES ('compression.codec'='org.apache.hadoop.io.compress.GzipCodec');

-- ----------------------------
-- 营销坑位表（全量表）
-- ----------------------------
DROP TABLE IF EXISTS gmall.ods_promotion_pos_full;
CREATE EXTERNAL TABLE gmall.ods_promotion_pos_full
(
    `id`                   STRING COMMENT '营销坑位ID',
    `pos_location`       STRING COMMENT '营销坑位位置',
    `pos_type`            STRING COMMENT '营销坑位类型：banner,宫格,列表,瀑布',
    `promotion_type`     STRING COMMENT '营销类型：算法、固定、搜索',
    `create_time`         STRING COMMENT '创建时间',
    `operate_time`        STRING COMMENT '修改时间'
) COMMENT '营销坑位表'
    PARTITIONED BY (`dt` STRING)
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    NULL DEFINED AS ''
LOCATION '/warehouse/gmall/ods/ods_promotion_pos_full/'
TBLPROPERTIES ('compression.codec'='org.apache.hadoop.io.compress.GzipCodec');

-- ----------------------------
-- 营销渠道表（全量表）
-- ----------------------------
DROP TABLE IF EXISTS gmall.ods_promotion_refer_full;
CREATE EXTERNAL TABLE gmall.ods_promotion_refer_full
(
    `id`                  STRING COMMENT '外部营销渠道ID',
    `refer_name`        STRING COMMENT '外部营销渠道名称',
    `create_time`       STRING COMMENT '创建时间',
    `operate_time`      STRING COMMENT '修改时间'
) COMMENT '营销渠道表'
    PARTITIONED BY (`dt` STRING)
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    NULL DEFINED AS ''
LOCATION '/warehouse/gmall/ods/ods_promotion_refer_full/'
TBLPROPERTIES ('compression.codec'='org.apache.hadoop.io.compress.GzipCodec');
