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
    `order_amount` DECIMAL(16,2) DEFAULT NULL COMMENT '订单金额',
    PRIMARY KEY (`dt`, `recent_days`, `tm_id`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci
COMMENT='各品牌交易统计';
