-- ===================================================
-- ADS 层建表：应用层
-- 用途：面向具体业务场景，直接支撑报表/大屏
-- ===================================================

-- ----------------------------
-- 各渠道流量统计
-- ----------------------------
DROP TABLE IF EXISTS gmall.ads_traffic_stats_by_channel;
CREATE EXTERNAL TABLE gmall.ads_traffic_stats_by_channel
(
    `dt`               STRING COMMENT '统计日期',
    `recent_days`      BIGINT COMMENT '最近天数：1/7/30',
    `channel`          STRING COMMENT '渠道',
    `uv_count`         BIGINT COMMENT '访客人数',
    `avg_duration_sec` BIGINT COMMENT '会话平均停留时长(秒)',
    `avg_page_count`   BIGINT COMMENT '会话平均浏览页面数',
    `sv_count`         BIGINT COMMENT '会话数',
    `bounce_rate`      DECIMAL(16,2) COMMENT '跳出率'
)
COMMENT '各渠道流量统计'
STORED AS PARQUET
LOCATION '/warehouse/gmall/ads/ads_traffic_stats_by_channel/'
TBLPROPERTIES ('parquet.compression'='snappy');

-- ----------------------------
-- 页面路径分析
-- ----------------------------
DROP TABLE IF EXISTS gmall.ads_page_path;
CREATE EXTERNAL TABLE gmall.ads_page_path
(
    `dt`         STRING COMMENT '统计日期',
    `source`     STRING COMMENT '起始页面ID',
    `target`     STRING COMMENT '目标页面ID',
    `path_count` BIGINT COMMENT '跳转次数'
)
COMMENT '页面浏览路径分析'
STORED AS PARQUET
LOCATION '/warehouse/gmall/ads/ads_page_path/'
TBLPROPERTIES ('parquet.compression'='snappy');

-- ----------------------------
-- 用户变动统计
-- ----------------------------
DROP TABLE IF EXISTS gmall.ads_user_change;
CREATE EXTERNAL TABLE gmall.ads_user_change
(
    `dt`               STRING COMMENT '统计日期',
    `user_churn_count` BIGINT COMMENT '流失用户数',
    `user_back_count`  BIGINT COMMENT '回流用户数'
)
COMMENT '用户变动统计'
STORED AS PARQUET
LOCATION '/warehouse/gmall/ads/ads_user_change/'
TBLPROPERTIES ('parquet.compression'='snappy');

-- ----------------------------
-- 用户留存率
-- ----------------------------
DROP TABLE IF EXISTS gmall.ads_user_retention;
CREATE EXTERNAL TABLE gmall.ads_user_retention
(
    `dt`              STRING COMMENT '统计日期',
    `create_date`     STRING COMMENT '用户新增日期',
    `retention_day`   INT COMMENT '截至当前日期留存天数',
    `retention_count` BIGINT COMMENT '留存用户数量',
    `new_user_count`  BIGINT COMMENT '新增用户数量',
    `retention_rate`  DECIMAL(16,2) COMMENT '留存率'
)
COMMENT '用户留存率'
STORED AS PARQUET
LOCATION '/warehouse/gmall/ads/ads_user_retention/'
TBLPROPERTIES ('parquet.compression'='snappy');

-- ----------------------------
-- 用户新增活跃统计
-- ----------------------------
DROP TABLE IF EXISTS gmall.ads_user_stats;
CREATE EXTERNAL TABLE gmall.ads_user_stats
(
    `dt`                STRING COMMENT '统计日期',
    `recent_days`       BIGINT COMMENT '最近天数：1/7/30',
    `new_user_count`    BIGINT COMMENT '新增用户数',
    `active_user_count` BIGINT COMMENT '活跃用户数'
)
COMMENT '用户新增活跃统计'
STORED AS PARQUET
LOCATION '/warehouse/gmall/ads/ads_user_stats/'
TBLPROPERTIES ('parquet.compression'='snappy');

-- ----------------------------
-- 用户行为漏斗分析
-- ----------------------------
DROP TABLE IF EXISTS gmall.ads_user_action;
CREATE EXTERNAL TABLE gmall.ads_user_action
(
    `dt`                STRING COMMENT '统计日期',
    `home_count`        BIGINT COMMENT '浏览首页人数',
    `good_detail_count` BIGINT COMMENT '浏览商品详情页人数',
    `cart_count`        BIGINT COMMENT '加购人数',
    `order_count`       BIGINT COMMENT '下单人数',
    `payment_count`     BIGINT COMMENT '支付人数'
)
COMMENT '用户行为漏斗分析'
STORED AS PARQUET
LOCATION '/warehouse/gmall/ads/ads_user_action/'
TBLPROPERTIES ('parquet.compression'='snappy');

-- ----------------------------
-- 各品牌复购率统计
-- ----------------------------
DROP TABLE IF EXISTS gmall.ads_repeat_purchase_by_tm;
CREATE EXTERNAL TABLE gmall.ads_repeat_purchase_by_tm
(
    `dt`                 STRING COMMENT '统计日期',
    `recent_days`        BIGINT COMMENT '最近天数：30',
    `tm_id`              STRING COMMENT '品牌ID',
    `tm_name`            STRING COMMENT '品牌名称',
    `order_repeat_rate`  DECIMAL(16,2) COMMENT '复购率'
)
COMMENT '各品牌复购率统计'
STORED AS PARQUET
LOCATION '/warehouse/gmall/ads/ads_repeat_purchase_by_tm/'
TBLPROPERTIES ('parquet.compression'='snappy');

-- ----------------------------
-- 各品牌交易统计
-- ----------------------------
DROP TABLE IF EXISTS gmall.ads_order_stats_by_tm;
CREATE EXTERNAL TABLE gmall.ads_order_stats_by_tm
(
    `dt`          STRING COMMENT '统计日期',
    `recent_days` BIGINT COMMENT '最近天数：1/7/30',
    `tm_id`       STRING COMMENT '品牌ID',
    `tm_name`     STRING COMMENT '品牌名称',
    `order_count` BIGINT COMMENT '订单数',
    `order_amount` DECIMAL(16,2) COMMENT '订单金额'
)
COMMENT '各品牌交易统计'
STORED AS PARQUET
LOCATION '/warehouse/gmall/ads/ads_order_stats_by_tm/'
TBLPROPERTIES ('parquet.compression'='snappy');

-- ----------------------------
-- 连续三日下单用户统计
-- ----------------------------
DROP TABLE IF EXISTS gmall.ads_order_continuously_user_count;
CREATE EXTERNAL TABLE gmall.ads_order_continuously_user_count
(
    `dt`                              STRING COMMENT '统计日期',
    `recent_days`                     BIGINT COMMENT '最近天数：7',
    `order_continuously_user_count`   BIGINT COMMENT '连续3日下单用户数'
)
COMMENT '连续三日下单用户统计'
STORED AS PARQUET
LOCATION '/warehouse/gmall/ads/ads_order_continuously_user_count/'
TBLPROPERTIES ('parquet.compression'='snappy');
