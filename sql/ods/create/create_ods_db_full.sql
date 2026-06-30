-- ===================================================
-- ODS 层建表：业务数据全量表
-- 数据来源：/origin_data/gmall/db/{table}_full/
-- 同步工具：DataX（MySQL → HDFS）
-- ===================================================

-- ----------------------------
-- 活动信息全量表
-- ----------------------------
DROP TABLE IF EXISTS gmall.ods_activity_info_full;
CREATE EXTERNAL TABLE gmall.ods_activity_info_full
(
    `id`            STRING COMMENT '活动ID',
    `activity_name` STRING COMMENT '活动名称',
    `activity_type` STRING COMMENT '活动类型：1-满减，2-折扣',
    `activity_desc` STRING COMMENT '活动描述',
    `start_time`    STRING COMMENT '开始时间',
    `end_time`      STRING COMMENT '结束时间',
    `create_time`   STRING COMMENT '创建时间',
    `operate_time`  STRING COMMENT '修改时间'
)
COMMENT '活动信息全量表'
PARTITIONED BY (`dt` STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE
TBLPROPERTIES ('compression'='gzip');

-- ----------------------------
-- 品牌全量表
-- ----------------------------
DROP TABLE IF EXISTS gmall.ods_base_trademark_full;
CREATE EXTERNAL TABLE gmall.ods_base_trademark_full
(
    `id`           STRING COMMENT '品牌ID',
    `tm_name`      STRING COMMENT '品牌名称',
    `logo_url`     STRING COMMENT '品牌LOGO图片路径',
    `create_time`  STRING COMMENT '创建时间',
    `operate_time` STRING COMMENT '修改时间'
)
COMMENT '品牌全量表'
PARTITIONED BY (`dt` STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE
TBLPROPERTIES ('compression'='gzip');

-- ----------------------------
-- 一级品类全量表
-- ----------------------------
DROP TABLE IF EXISTS gmall.ods_base_category1_full;
CREATE EXTERNAL TABLE gmall.ods_base_category1_full
(
    `id`           STRING COMMENT '一级品类ID',
    `name`         STRING COMMENT '一级品类名称',
    `create_time`  STRING COMMENT '创建时间',
    `operate_time` STRING COMMENT '修改时间'
)
COMMENT '一级品类全量表'
PARTITIONED BY (`dt` STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE
TBLPROPERTIES ('compression'='gzip');

-- ----------------------------
-- 省份全量表
-- ----------------------------
DROP TABLE IF EXISTS gmall.ods_base_province_full;
CREATE EXTERNAL TABLE gmall.ods_base_province_full
(
    `id`           STRING COMMENT '省份ID',
    `name`         STRING COMMENT '省份名称',
    `region_id`    STRING COMMENT '地区ID',
    `area_code`    STRING COMMENT '行政区位码',
    `iso_code`     STRING COMMENT '旧版ISO编码',
    `iso_3166_2`   STRING COMMENT '新版ISO编码',
    `create_time`  STRING COMMENT '创建时间',
    `operate_time` STRING COMMENT '修改时间'
)
COMMENT '省份全量表'
PARTITIONED BY (`dt` STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE
TBLPROPERTIES ('compression'='gzip');

-- ----------------------------
-- SKU 信息全量表
-- ----------------------------
DROP TABLE IF EXISTS gmall.ods_sku_info_full;
CREATE EXTERNAL TABLE gmall.ods_sku_info_full
(
    `id`                STRING COMMENT 'SKU_ID',
    `spu_id`            STRING COMMENT 'SPU_ID',
    `price`             STRING COMMENT '价格',
    `sku_name`          STRING COMMENT 'SKU名称',
    `sku_desc`          STRING COMMENT '商品规格描述',
    `weight`            STRING COMMENT '重量',
    `tm_id`             STRING COMMENT '品牌ID(冗余)',
    `category3_id`      STRING COMMENT '三级品类ID(冗余)',
    `sku_default_img`   STRING COMMENT '默认显示图片(冗余)',
    `is_sale`           STRING COMMENT '是否销售：1-是，0-否',
    `create_time`       STRING COMMENT '创建时间',
    `operate_time`      STRING COMMENT '修改时间'
)
COMMENT 'SKU信息全量表'
PARTITIONED BY (`dt` STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE
TBLPROPERTIES ('compression'='gzip');

-- ----------------------------
-- SPU 信息全量表
-- ----------------------------
DROP TABLE IF EXISTS gmall.ods_spu_info_full;
CREATE EXTERNAL TABLE gmall.ods_spu_info_full
(
    `id`             STRING COMMENT 'SPU_ID',
    `spu_name`       STRING COMMENT 'SPU名称',
    `description`    STRING COMMENT '商品描述(后台简述)',
    `category3_id`   STRING COMMENT '三级品类ID',
    `tm_id`          STRING COMMENT '品牌ID',
    `create_time`    STRING COMMENT '创建时间',
    `operate_time`   STRING COMMENT '修改时间'
)
COMMENT 'SPU信息全量表'
PARTITIONED BY (`dt` STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE
TBLPROPERTIES ('compression'='gzip');
