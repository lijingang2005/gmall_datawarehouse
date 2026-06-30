-- ===================================================
-- DWD 层建表：明细层
-- 用途：清洗标准化后的明细数据，是数仓的核心层
-- ===================================================

-- ----------------------------
-- 页面浏览明细表
-- 来源：ods_log_inc
-- ----------------------------
DROP TABLE IF EXISTS gmall.dwd_traffic_page_log_inc;
CREATE EXTERNAL TABLE gmall.dwd_traffic_page_log_inc
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
    `from_pos_id`    STRING COMMENT '来源坑位ID',
    `from_pos_seq`   STRING COMMENT '来源坑位序列号',
    `refer_id`       STRING COMMENT '外部营销渠道ID',
    `source_type`    STRING COMMENT '来源类型',
    `session_id`     STRING COMMENT '会话ID',
    `ts`             BIGINT COMMENT '时间戳'
)
COMMENT '页面浏览明细表 - DWD层'
PARTITIONED BY (`dt` STRING)
STORED AS PARQUET
LOCATION '/warehouse/gmall/dwd/dwd_traffic_page_log_inc/'
TBLPROPERTIES ('parquet.compression'='snappy');

-- ----------------------------
-- 下单明细表
-- 来源：ods_order_detail_inc + ods_order_info_inc
-- ----------------------------
DROP TABLE IF EXISTS gmall.dwd_trade_order_detail_inc;
CREATE EXTERNAL TABLE gmall.dwd_trade_order_detail_inc
(
    `id`                     STRING COMMENT '订单明细编号',
    `order_id`               STRING COMMENT '订单ID',
    `user_id`                STRING COMMENT '用户ID',
    `sku_id`                 STRING COMMENT 'SKU_ID',
    `sku_name`               STRING COMMENT 'SKU名称（冗余）',
    `province_id`            STRING COMMENT '省份ID',
    `order_price`            DECIMAL(16,2) COMMENT '购买价格',
    `sku_num`                BIGINT COMMENT '购买数量',
    `total_amount`           DECIMAL(16,2) COMMENT '订单总金额',
    `activity_reduce_amount` DECIMAL(16,2) COMMENT '活动减免金额',
    `coupon_reduce_amount`   DECIMAL(16,2) COMMENT '优惠券减免金额',
    `original_total_amount`  DECIMAL(16,2) COMMENT '原价金额',
    `feight_fee`             DECIMAL(16,2) COMMENT '运费',
    `split_total_amount`     DECIMAL(16,2) COMMENT '分摊总金额',
    `create_time`            STRING COMMENT '创建时间'
)
COMMENT '下单明细表 - DWD层'
PARTITIONED BY (`dt` STRING)
STORED AS PARQUET
LOCATION '/warehouse/gmall/dwd/dwd_trade_order_detail_inc/'
TBLPROPERTIES ('parquet.compression'='snappy');

-- ----------------------------
-- 支付明细表
-- 来源：ods_payment_info_inc
-- ----------------------------
DROP TABLE IF EXISTS gmall.dwd_trade_pay_detail_inc;
CREATE EXTERNAL TABLE gmall.dwd_trade_pay_detail_inc
(
    `id`             STRING COMMENT '支付编号',
    `order_id`       STRING COMMENT '订单ID',
    `user_id`        STRING COMMENT '用户ID',
    `payment_type`   STRING COMMENT '支付类型',
    `trade_no`       STRING COMMENT '交易流水号',
    `total_amount`   DECIMAL(16,2) COMMENT '支付金额',
    `payment_status` STRING COMMENT '支付状态',
    `callback_time`  STRING COMMENT '回调时间',
    `create_time`    STRING COMMENT '创建时间'
)
COMMENT '支付明细表 - DWD层'
PARTITIONED BY (`dt` STRING)
STORED AS PARQUET
LOCATION '/warehouse/gmall/dwd/dwd_trade_pay_detail_inc/'
TBLPROPERTIES ('parquet.compression'='snappy');

-- ----------------------------
-- 加购明细表
-- 来源：ods_cart_info_inc
-- ----------------------------
DROP TABLE IF EXISTS gmall.dwd_trade_cart_add_inc;
CREATE EXTERNAL TABLE gmall.dwd_trade_cart_add_inc
(
    `id`           STRING COMMENT '编号',
    `user_id`      STRING COMMENT '用户ID',
    `sku_id`       STRING COMMENT 'SKU_ID',
    `cart_price`   DECIMAL(16,2) COMMENT '加入购物车时价格',
    `sku_num`      BIGINT COMMENT '数量',
    `sku_name`     STRING COMMENT 'SKU名称',
    `create_time`  STRING COMMENT '创建时间'
)
COMMENT '加购明细表 - DWD层'
PARTITIONED BY (`dt` STRING)
STORED AS PARQUET
LOCATION '/warehouse/gmall/dwd/dwd_trade_cart_add_inc/'
TBLPROPERTIES ('parquet.compression'='snappy');
