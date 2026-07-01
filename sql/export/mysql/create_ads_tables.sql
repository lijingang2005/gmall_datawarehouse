-- ===================================================
-- MySQL 报表库建表
-- 用途：在 MySQL 中创建 ADS 报表对应的表结构
--      用于接收 DataX 从 Hive ADS 导出的数据
--      供 Superset / 自定义报表 可视化使用
-- 数据库：gmall_report
-- ===================================================

CREATE DATABASE IF NOT EXISTS gmall_report
DEFAULT CHARSET utf8
COLLATE utf8_general_ci;

USE gmall_report;

-- ----------------------------
-- 各渠道流量统计
-- ----------------------------
DROP TABLE IF EXISTS `ads_traffic_stats_by_channel`;
CREATE TABLE `ads_traffic_stats_by_channel` (
    `dt`               DATE NOT NULL COMMENT '统计日期',
    `recent_days`      BIGINT(20) NOT NULL COMMENT '最近天数:1/7/30',
    `channel`          VARCHAR(16) NOT NULL COMMENT '渠道',
    `uv_count`         BIGINT(20) DEFAULT NULL COMMENT '访客人数',
    `avg_duration_sec` BIGINT(20) DEFAULT NULL COMMENT '会话平均停留时长(秒)',
    `avg_page_count`   BIGINT(20) DEFAULT NULL COMMENT '会话平均浏览页面数',
    `sv_count`         BIGINT(20) DEFAULT NULL COMMENT '会话数',
    `bounce_rate`      DECIMAL(16,2) DEFAULT NULL COMMENT '跳出率',
    PRIMARY KEY (`dt`, `recent_days`, `channel`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci
COMMENT='各渠道流量统计';

-- ----------------------------
-- 页面路径分析
-- ----------------------------
DROP TABLE IF EXISTS `ads_page_path`;
CREATE TABLE `ads_page_path` (
    `dt`         DATE NOT NULL COMMENT '统计日期',
    `source`     VARCHAR(64) NOT NULL COMMENT '起始页面ID',
    `target`     VARCHAR(64) NOT NULL COMMENT '目标页面ID',
    `path_count` BIGINT(20) DEFAULT NULL COMMENT '跳转次数',
    PRIMARY KEY (`dt`, `source`, `target`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci
COMMENT='页面浏览路径分析';

-- ----------------------------
-- 用户变动统计
-- ----------------------------
DROP TABLE IF EXISTS `ads_user_change`;
CREATE TABLE `ads_user_change` (
    `dt`               DATE NOT NULL COMMENT '统计日期',
    `user_churn_count` BIGINT(20) DEFAULT NULL COMMENT '流失用户数',
    `user_back_count`  BIGINT(20) DEFAULT NULL COMMENT '回流用户数',
    PRIMARY KEY (`dt`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci
COMMENT='用户变动统计';

-- ----------------------------
-- 用户留存率
-- ----------------------------
DROP TABLE IF EXISTS `ads_user_retention`;
CREATE TABLE `ads_user_retention` (
    `dt`              DATE NOT NULL COMMENT '统计日期',
    `create_date`     VARCHAR(16) NOT NULL COMMENT '用户新增日期',
    `retention_day`   INT(20) NOT NULL COMMENT '截至当前日期留存天数',
    `retention_count` BIGINT(20) DEFAULT NULL COMMENT '留存用户数量',
    `new_user_count`  BIGINT(20) DEFAULT NULL COMMENT '新增用户数量',
    `retention_rate`  DECIMAL(16,2) DEFAULT NULL COMMENT '留存率',
    PRIMARY KEY (`dt`, `create_date`, `retention_day`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci
COMMENT='用户留存率';

-- ----------------------------
-- 用户新增活跃统计
-- ----------------------------
DROP TABLE IF EXISTS `ads_user_stats`;
CREATE TABLE `ads_user_stats` (
    `dt`                DATE NOT NULL COMMENT '统计日期',
    `recent_days`       BIGINT(20) NOT NULL COMMENT '最近n日:1/7/30',
    `new_user_count`    BIGINT(20) DEFAULT NULL COMMENT '新增用户数',
    `active_user_count` BIGINT(20) DEFAULT NULL COMMENT '活跃用户数',
    PRIMARY KEY (`dt`, `recent_days`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci
COMMENT='用户新增活跃统计';

-- ----------------------------
-- 用户行为漏斗分析
-- ----------------------------
DROP TABLE IF EXISTS `ads_user_action`;
CREATE TABLE `ads_user_action` (
    `dt`                DATE NOT NULL COMMENT '统计日期',
    `home_count`        BIGINT(20) DEFAULT NULL COMMENT '浏览首页人数',
    `good_detail_count` BIGINT(20) DEFAULT NULL COMMENT '浏览商品详情页人数',
    `cart_count`        BIGINT(20) DEFAULT NULL COMMENT '加购人数',
    `order_count`       BIGINT(20) DEFAULT NULL COMMENT '下单人数',
    `payment_count`     BIGINT(20) DEFAULT NULL COMMENT '支付人数',
    PRIMARY KEY (`dt`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci
COMMENT='用户行为漏斗分析';

-- ----------------------------
-- 新增下单用户统计
-- ----------------------------
DROP TABLE IF EXISTS `ads_new_order_user_stats`;
CREATE TABLE `ads_new_order_user_stats` (
    `dt`                   DATE NOT NULL COMMENT '统计日期',
    `recent_days`          BIGINT(20) NOT NULL COMMENT '最近n日:1/7/30',
    `new_order_user_count` BIGINT(20) DEFAULT NULL COMMENT '新增下单用户数',
    PRIMARY KEY (`recent_days`, `dt`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci
COMMENT='新增下单用户统计';

-- ----------------------------
-- 连续三日下单用户统计
-- ----------------------------
DROP TABLE IF EXISTS `ads_order_continuously_user_count`;
CREATE TABLE `ads_order_continuously_user_count` (
    `dt`                              DATE NOT NULL COMMENT '统计日期',
    `recent_days`                     BIGINT(20) NOT NULL COMMENT '最近天数:7',
    `order_continuously_user_count`   BIGINT(20) DEFAULT NULL COMMENT '连续3日下单用户数',
    PRIMARY KEY (`dt`, `recent_days`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci
COMMENT='连续3日下单用户统计';

-- ----------------------------
-- 各品牌复购率统计
-- ----------------------------
DROP TABLE IF EXISTS `ads_repeat_purchase_by_tm`;
CREATE TABLE `ads_repeat_purchase_by_tm` (
    `dt`                 DATE NOT NULL COMMENT '统计日期',
    `recent_days`        BIGINT(20) NOT NULL COMMENT '最近天数:30',
    `tm_id`              VARCHAR(16) NOT NULL COMMENT '品牌ID',
    `tm_name`            VARCHAR(32) DEFAULT NULL COMMENT '品牌名称',
    `order_repeat_rate`  DECIMAL(16,2) DEFAULT NULL COMMENT '复购率',
    PRIMARY KEY (`dt`, `recent_days`, `tm_id`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci
COMMENT='各品牌复购率统计';

-- ----------------------------
-- 各品牌交易统计
-- ----------------------------
DROP TABLE IF EXISTS `ads_order_stats_by_tm`;
CREATE TABLE `ads_order_stats_by_tm` (
    `dt`          DATE NOT NULL COMMENT '统计日期',
    `recent_days` BIGINT(20) NOT NULL COMMENT '最近天数:1/7/30',
    `tm_id`       VARCHAR(16) NOT NULL COMMENT '品牌ID',
    `tm_name`     VARCHAR(32) DEFAULT NULL COMMENT '品牌名称',
    `order_count` BIGINT(20) DEFAULT NULL COMMENT '订单数',
    `order_user_count` BIGINT(20) DEFAULT NULL COMMENT '下单人数',
    PRIMARY KEY (`dt`, `recent_days`, `tm_id`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci
COMMENT='各品牌交易统计';

-- ----------------------------
-- 各品类商品下单统计
-- ----------------------------
DROP TABLE IF EXISTS `ads_order_stats_by_cate`;
CREATE TABLE `ads_order_stats_by_cate` (
    `dt`               DATE NOT NULL COMMENT '统计日期',
    `recent_days`      BIGINT(20) NOT NULL COMMENT '最近天数:1/7/30',
    `category1_id`     VARCHAR(16) DEFAULT NULL COMMENT '一级品类ID',
    `category1_name`   VARCHAR(32) DEFAULT NULL COMMENT '一级品类名称',
    `category2_id`     VARCHAR(16) DEFAULT NULL COMMENT '二级品类ID',
    `category2_name`   VARCHAR(32) DEFAULT NULL COMMENT '二级品类名称',
    `category3_id`     VARCHAR(16) DEFAULT NULL COMMENT '三级品类ID',
    `category3_name`   VARCHAR(32) DEFAULT NULL COMMENT '三级品类名称',
    `order_count`      BIGINT(20) DEFAULT NULL COMMENT '下单数',
    `order_user_count` BIGINT(20) DEFAULT NULL COMMENT '下单人数',
    PRIMARY KEY (`dt`, `recent_days`, `category3_id`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci
COMMENT='各品类商品下单统计';

-- ----------------------------
-- 各省份交易统计
-- ----------------------------
DROP TABLE IF EXISTS `ads_order_by_province`;
CREATE TABLE `ads_order_by_province` (
    `dt`                 DATE NOT NULL COMMENT '统计日期',
    `recent_days`        BIGINT(20) NOT NULL COMMENT '最近天数:1/7/30',
    `province_id`        VARCHAR(16) NOT NULL COMMENT '省份ID',
    `province_name`      VARCHAR(32) DEFAULT NULL COMMENT '省份名称',
    `area_code`          VARCHAR(16) DEFAULT NULL COMMENT '地区编码',
    `iso_code`           VARCHAR(16) DEFAULT NULL COMMENT 'ISO编码',
    `iso_code_3166_2`    VARCHAR(16) DEFAULT NULL COMMENT '新版ISO编码',
    `order_count`        BIGINT(20) DEFAULT NULL COMMENT '订单数',
    `order_total_amount` DECIMAL(16,2) DEFAULT NULL COMMENT '订单金额',
    PRIMARY KEY (`dt`, `recent_days`, `province_id`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci
COMMENT='各省份交易统计';

-- ----------------------------
-- 优惠券使用统计
-- ----------------------------
DROP TABLE IF EXISTS `ads_coupon_stats`;
CREATE TABLE `ads_coupon_stats` (
    `dt`              DATE NOT NULL COMMENT '统计日期',
    `coupon_id`       VARCHAR(16) NOT NULL COMMENT '优惠券ID',
    `coupon_name`     VARCHAR(64) DEFAULT NULL COMMENT '优惠券名称',
    `used_count`      BIGINT(20) DEFAULT NULL COMMENT '使用次数',
    `used_user_count` BIGINT(20) DEFAULT NULL COMMENT '使用人数',
    PRIMARY KEY (`dt`, `coupon_id`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci
COMMENT='优惠券使用统计';

-- ----------------------------
-- 各品类商品购物车存量Top3
-- ----------------------------
DROP TABLE IF EXISTS `ads_sku_cart_num_top3_by_cate`;
CREATE TABLE `ads_sku_cart_num_top3_by_cate` (
    `dt`             DATE NOT NULL COMMENT '统计日期',
    `category1_id`   VARCHAR(16) DEFAULT NULL COMMENT '一级品类ID',
    `category1_name` VARCHAR(32) DEFAULT NULL COMMENT '一级品类名称',
    `category2_id`   VARCHAR(16) DEFAULT NULL COMMENT '二级品类ID',
    `category2_name` VARCHAR(32) DEFAULT NULL COMMENT '二级品类名称',
    `category3_id`   VARCHAR(16) DEFAULT NULL COMMENT '三级品类ID',
    `category3_name` VARCHAR(32) DEFAULT NULL COMMENT '三级品类名称',
    `sku_id`         VARCHAR(16) NOT NULL COMMENT 'SKU_ID',
    `sku_name`       VARCHAR(128) DEFAULT NULL COMMENT 'SKU名称',
    `cart_num`       BIGINT(20) DEFAULT NULL COMMENT '购物车中商品数量',
    `rk`             BIGINT(20) NOT NULL COMMENT '排名',
    PRIMARY KEY (`dt`, `category3_id`, `rk`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci
COMMENT='各品类商品购物车存量Top3';

-- ----------------------------
-- 各品牌商品收藏次数Top3
-- ----------------------------
DROP TABLE IF EXISTS `ads_sku_favor_count_top3_by_tm`;
CREATE TABLE `ads_sku_favor_count_top3_by_tm` (
    `dt`          DATE NOT NULL COMMENT '统计日期',
    `tm_id`       VARCHAR(16) NOT NULL COMMENT '品牌ID',
    `tm_name`     VARCHAR(32) DEFAULT NULL COMMENT '品牌名称',
    `sku_id`      VARCHAR(16) NOT NULL COMMENT 'SKU_ID',
    `sku_name`    VARCHAR(128) DEFAULT NULL COMMENT 'SKU名称',
    `favor_count` BIGINT(20) DEFAULT NULL COMMENT '被收藏次数',
    `rk`          BIGINT(20) NOT NULL COMMENT '排名',
    PRIMARY KEY (`dt`, `tm_id`, `rk`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci
COMMENT='各品牌商品收藏次数Top3';

-- ----------------------------
-- 下单到支付时间间隔平均值
-- ----------------------------
DROP TABLE IF EXISTS `ads_order_to_pay_interval_avg`;
CREATE TABLE `ads_order_to_pay_interval_avg` (
    `dt`                        DATE NOT NULL COMMENT '统计日期',
    `order_to_pay_interval_avg` BIGINT(20) DEFAULT NULL COMMENT '下单到支付时间间隔平均值(秒)',
    PRIMARY KEY (`dt`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci
COMMENT='下单到支付时间间隔平均值统计';
