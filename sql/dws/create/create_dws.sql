-- ===================================================
-- DWS 层建表：汇总层
-- 用途：按主题域和时间窗口预聚合，构建公共汇总宽表
-- ===================================================

-- ----------------------------
-- 流量域：会话粒度 1 日汇总
-- ----------------------------
DROP TABLE IF EXISTS gmall.dws_traffic_session_page_view_1d;
CREATE EXTERNAL TABLE gmall.dws_traffic_session_page_view_1d
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
COMMENT '流量域会话粒度日汇总表'
PARTITIONED BY (`dt` STRING)
STORED AS PARQUET
LOCATION '/warehouse/gmall/dws/dws_traffic_session_page_view_1d/'
TBLPROPERTIES ('parquet.compression'='snappy');

-- ----------------------------
-- 交易域：订单粒度 1 日汇总
-- ----------------------------
DROP TABLE IF EXISTS gmall.dws_trade_order_1d;
CREATE EXTERNAL TABLE gmall.dws_trade_order_1d
(
    `order_id`               STRING COMMENT '订单ID',
    `user_id`                STRING COMMENT '用户ID',
    `sku_id`                 STRING COMMENT 'SKU_ID',
    `sku_name`               STRING COMMENT 'SKU名称',
    `tm_id`                  STRING COMMENT '品牌ID',
    `tm_name`                STRING COMMENT '品牌名称',
    `category1_id`           STRING COMMENT '一级品类ID',
    `category1_name`         STRING COMMENT '一级品类名称',
    `category2_id`           STRING COMMENT '二级品类ID',
    `category2_name`         STRING COMMENT '二级品类名称',
    `category3_id`           STRING COMMENT '三级品类ID',
    `category3_name`         STRING COMMENT '三级品类名称',
    `province_id`            STRING COMMENT '省份ID',
    `order_price`            DECIMAL(16,2) COMMENT '购买价格',
    `sku_num`                BIGINT COMMENT '购买数量',
    `split_total_amount`     DECIMAL(16,2) COMMENT '分摊总金额',
    `activity_reduce_amount` DECIMAL(16,2) COMMENT '活动减免金额',
    `coupon_reduce_amount`   DECIMAL(16,2) COMMENT '优惠券减免金额',
    `original_total_amount`  DECIMAL(16,2) COMMENT '原价金额'
)
COMMENT '交易域订单粒度日汇总表'
PARTITIONED BY (`dt` STRING)
STORED AS PARQUET
LOCATION '/warehouse/gmall/dws/dws_trade_order_1d/'
TBLPROPERTIES ('parquet.compression'='snappy');

-- ----------------------------
-- 交易域：品牌粒度 N 日汇总 (nd)
-- ----------------------------
DROP TABLE IF EXISTS gmall.dws_trade_order_tm_nd;
CREATE EXTERNAL TABLE gmall.dws_trade_order_tm_nd
(
    `tm_id`        STRING COMMENT '品牌ID',
    `tm_name`      STRING COMMENT '品牌名称',
    `order_count`  BIGINT COMMENT '订单数',
    `user_count`   BIGINT COMMENT '用户数',
    `order_amount` DECIMAL(16,2) COMMENT '订单金额'
)
COMMENT '交易域品牌粒度N日汇总表'
PARTITIONED BY (`dt` STRING)
STORED AS PARQUET
LOCATION '/warehouse/gmall/dws/dws_trade_order_tm_nd/'
TBLPROPERTIES ('parquet.compression'='snappy');
