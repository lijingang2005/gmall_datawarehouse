-- ===================================================
-- DWD 层建表：明细层
-- 用途：清洗标准化后的明细数据，是数仓的核心层
-- 存储格式：ORC 列式存储 + snappy 压缩
-- ===================================================

-- ----------------------------
-- 1. 交易域加购事务事实表
-- 数据域：交易域 | 业务过程：加购
-- 来源：ods_cart_info_inc
-- ----------------------------
DROP TABLE IF EXISTS gmall.dwd_trade_cart_add_inc;
CREATE EXTERNAL TABLE gmall.dwd_trade_cart_add_inc
(
    `id`          STRING COMMENT '编号',
    `user_id`     STRING COMMENT '用户ID',
    `sku_id`      STRING COMMENT 'SKU_ID',
    `date_id`     STRING COMMENT '日期ID',
    `create_time` STRING COMMENT '加购时间',
    `sku_num`     BIGINT COMMENT '加购物车件数'
) COMMENT '交易域加购事务事实表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_trade_cart_add_inc/'
    TBLPROPERTIES ('orc.compress'='snappy');

-- ----------------------------
-- 2. 交易域下单事务事实表
-- 数据域：交易域 | 业务过程：下单
-- 来源：ods_order_detail_inc + ods_order_info_inc
--       + ods_order_detail_coupon_inc + ods_order_detail_activity_inc
-- ----------------------------
DROP TABLE IF EXISTS gmall.dwd_trade_order_detail_inc;
CREATE EXTERNAL TABLE gmall.dwd_trade_order_detail_inc
(
    `id`                     STRING COMMENT '编号',
    `order_id`               STRING COMMENT '订单ID',
    `user_id`                STRING COMMENT '用户ID',
    `sku_id`                 STRING COMMENT '商品ID',
    `province_id`            STRING COMMENT '省份ID',
    `activity_id`            STRING COMMENT '参与活动ID',
    `activity_rule_id`       STRING COMMENT '参与活动规则ID',
    `coupon_id`              STRING COMMENT '使用优惠券ID',
    `date_id`                STRING COMMENT '下单日期ID',
    `create_time`            STRING COMMENT '下单时间',
    `sku_num`                BIGINT COMMENT '商品数量',
    `split_original_amount`  DECIMAL(16, 2) COMMENT '原始价格',
    `split_activity_amount`  DECIMAL(16, 2) COMMENT '活动优惠分摊',
    `split_coupon_amount`    DECIMAL(16, 2) COMMENT '优惠券优惠分摊',
    `split_total_amount`     DECIMAL(16, 2) COMMENT '最终价格分摊'
) COMMENT '交易域下单事务事实表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_trade_order_detail_inc/'
    TBLPROPERTIES ('orc.compress'='snappy');

-- ----------------------------
-- 3. 交易域支付成功事务事实表
-- 数据域：交易域 | 业务过程：支付成功
-- 来源：ods_payment_info_inc + ods_order_detail_inc + ods_order_info_inc
--       + ods_order_detail_coupon_inc + ods_order_detail_activity_inc + ods_base_dic_full
-- ----------------------------
DROP TABLE IF EXISTS gmall.dwd_trade_pay_detail_suc_inc;
CREATE EXTERNAL TABLE gmall.dwd_trade_pay_detail_suc_inc
(
    `id`                      STRING COMMENT '编号',
    `order_id`                STRING COMMENT '订单ID',
    `user_id`                 STRING COMMENT '用户ID',
    `sku_id`                  STRING COMMENT 'SKU_ID',
    `province_id`             STRING COMMENT '省份ID',
    `activity_id`             STRING COMMENT '参与活动ID',
    `activity_rule_id`        STRING COMMENT '参与活动规则ID',
    `coupon_id`               STRING COMMENT '使用优惠券ID',
    `payment_type_code`       STRING COMMENT '支付类型编码',
    `payment_type_name`       STRING COMMENT '支付类型名称',
    `date_id`                 STRING COMMENT '支付日期ID',
    `callback_time`           STRING COMMENT '支付成功时间',
    `sku_num`                 BIGINT COMMENT '商品数量',
    `split_original_amount`   DECIMAL(16, 2) COMMENT '应支付原始金额',
    `split_activity_amount`   DECIMAL(16, 2) COMMENT '支付活动优惠分摊',
    `split_coupon_amount`     DECIMAL(16, 2) COMMENT '支付优惠券优惠分摊',
    `split_payment_amount`    DECIMAL(16, 2) COMMENT '支付金额'
) COMMENT '交易域支付成功事务事实表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_trade_pay_detail_suc_inc/'
    TBLPROPERTIES ('orc.compress'='snappy');

-- ----------------------------
-- 4. 交易域购物车周期快照事实表
-- 数据域：交易域 | 类型：周期快照
-- 来源：ods_cart_info_full
-- ----------------------------
DROP TABLE IF EXISTS gmall.dwd_trade_cart_full;
CREATE EXTERNAL TABLE gmall.dwd_trade_cart_full
(
    `id`       STRING COMMENT '编号',
    `user_id`  STRING COMMENT '用户ID',
    `sku_id`   STRING COMMENT 'SKU_ID',
    `sku_name` STRING COMMENT '商品名称',
    `sku_num`  BIGINT COMMENT '现存商品件数'
) COMMENT '交易域购物车周期快照事实表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_trade_cart_full/'
    TBLPROPERTIES ('orc.compress'='snappy');

-- ----------------------------
-- 5. 交易域交易流程累积快照事实表
-- 数据域：交易域 | 类型：累积快照
-- 来源：ods_order_info_inc + ods_payment_info_inc + ods_order_status_log_inc
-- ----------------------------
DROP TABLE IF EXISTS gmall.dwd_trade_trade_flow_acc;
CREATE EXTERNAL TABLE gmall.dwd_trade_trade_flow_acc
(
    `order_id`               STRING COMMENT '订单ID',
    `user_id`                STRING COMMENT '用户ID',
    `province_id`            STRING COMMENT '省份ID',
    `order_date_id`          STRING COMMENT '下单日期ID',
    `order_time`             STRING COMMENT '下单时间',
    `payment_date_id`        STRING COMMENT '支付日期ID',
    `payment_time`           STRING COMMENT '支付时间',
    `finish_date_id`         STRING COMMENT '确认收货日期ID',
    `finish_time`            STRING COMMENT '确认收货时间',
    `order_original_amount`  DECIMAL(16, 2) COMMENT '下单原始价格',
    `order_activity_amount`  DECIMAL(16, 2) COMMENT '下单活动优惠分摊',
    `order_coupon_amount`    DECIMAL(16, 2) COMMENT '下单优惠券优惠分摊',
    `order_total_amount`     DECIMAL(16, 2) COMMENT '下单最终价格分摊',
    `payment_amount`         DECIMAL(16, 2) COMMENT '支付金额'
) COMMENT '交易域交易流程累积快照事实表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_trade_trade_flow_acc/'
    TBLPROPERTIES ('orc.compress'='snappy');

-- ----------------------------
-- 6. 工具域优惠券使用（支付）事务事实表
-- 数据域：工具域 | 业务过程：优惠券使用（支付）
-- 来源：ods_coupon_use_inc
-- ----------------------------
DROP TABLE IF EXISTS gmall.dwd_tool_coupon_used_inc;
CREATE EXTERNAL TABLE gmall.dwd_tool_coupon_used_inc
(
    `id`           STRING COMMENT '编号',
    `coupon_id`    STRING COMMENT '优惠券ID',
    `user_id`      STRING COMMENT '用户ID',
    `order_id`     STRING COMMENT '订单ID',
    `date_id`      STRING COMMENT '日期ID',
    `payment_time` STRING COMMENT '使用(支付)时间'
) COMMENT '优惠券使用（支付）事务事实表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_tool_coupon_used_inc/'
    TBLPROPERTIES ('orc.compress'='snappy');

-- ----------------------------
-- 7. 互动域收藏商品事务事实表
-- 数据域：互动域 | 业务过程：收藏商品
-- 来源：ods_favor_info_inc
-- ----------------------------
DROP TABLE IF EXISTS gmall.dwd_interaction_favor_add_inc;
CREATE EXTERNAL TABLE gmall.dwd_interaction_favor_add_inc
(
    `id`          STRING COMMENT '编号',
    `user_id`     STRING COMMENT '用户ID',
    `sku_id`      STRING COMMENT 'SKU_ID',
    `date_id`     STRING COMMENT '日期ID',
    `create_time` STRING COMMENT '收藏时间'
) COMMENT '互动域收藏商品事务事实表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_interaction_favor_add_inc/'
    TBLPROPERTIES ('orc.compress'='snappy');

-- ----------------------------
-- 8. 流量域页面浏览事务事实表
-- 数据域：流量域 | 业务过程：页面浏览
-- 来源：ods_log_inc
-- ----------------------------
DROP TABLE IF EXISTS gmall.dwd_traffic_page_view_inc;
CREATE EXTERNAL TABLE gmall.dwd_traffic_page_view_inc
(
    `province_id`    STRING COMMENT '省份ID',
    `brand`          STRING COMMENT '手机品牌',
    `channel`        STRING COMMENT '渠道',
    `is_new`         STRING COMMENT '是否首次启动',
    `model`          STRING COMMENT '手机型号',
    `mid_id`         STRING COMMENT '设备ID',
    `operate_system` STRING COMMENT '操作系统',
    `user_id`        STRING COMMENT '会员ID',
    `version_code`   STRING COMMENT 'APP版本号',
    `page_item`      STRING COMMENT '目标ID',
    `page_item_type` STRING COMMENT '目标类型',
    `last_page_id`   STRING COMMENT '上页ID',
    `page_id`        STRING COMMENT '页面ID',
    `from_pos_id`    STRING COMMENT '点击坑位ID',
    `from_pos_seq`   STRING COMMENT '点击坑位位置',
    `refer_id`       STRING COMMENT '营销渠道ID',
    `date_id`        STRING COMMENT '日期ID',
    `view_time`      STRING COMMENT '跳入时间',
    `session_id`     STRING COMMENT '所属会话ID',
    `during_time`    BIGINT COMMENT '持续时间毫秒'
) COMMENT '流量域页面浏览事务事实表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_traffic_page_view_inc/'
    TBLPROPERTIES ('orc.compress'='snappy');

-- ----------------------------
-- 9. 用户域用户注册事务事实表
-- 数据域：用户域 | 业务过程：注册
-- 来源：ods_user_info_inc + ods_log_inc
-- ----------------------------
DROP TABLE IF EXISTS gmall.dwd_user_register_inc;
CREATE EXTERNAL TABLE gmall.dwd_user_register_inc
(
    `user_id`        STRING COMMENT '用户ID',
    `date_id`        STRING COMMENT '日期ID',
    `create_time`    STRING COMMENT '注册时间',
    `channel`        STRING COMMENT '应用下载渠道',
    `province_id`    STRING COMMENT '省份ID',
    `version_code`   STRING COMMENT '应用版本',
    `mid_id`         STRING COMMENT '设备ID',
    `brand`          STRING COMMENT '设备品牌',
    `model`          STRING COMMENT '设备型号',
    `operate_system` STRING COMMENT '设备操作系统'
) COMMENT '用户域用户注册事务事实表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_user_register_inc/'
    TBLPROPERTIES ('orc.compress'='snappy');

-- ----------------------------
-- 10. 用户域用户登录事务事实表
-- 数据域：用户域 | 业务过程：登录
-- 来源：ods_log_inc
-- ----------------------------
DROP TABLE IF EXISTS gmall.dwd_user_login_inc;
CREATE EXTERNAL TABLE gmall.dwd_user_login_inc
(
    `user_id`        STRING COMMENT '用户ID',
    `date_id`        STRING COMMENT '日期ID',
    `login_time`     STRING COMMENT '登录时间',
    `channel`        STRING COMMENT '应用下载渠道',
    `province_id`    STRING COMMENT '省份ID',
    `version_code`   STRING COMMENT '应用版本',
    `mid_id`         STRING COMMENT '设备ID',
    `brand`          STRING COMMENT '设备品牌',
    `model`          STRING COMMENT '设备型号',
    `operate_system` STRING COMMENT '设备操作系统'
) COMMENT '用户域用户登录事务事实表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_user_login_inc/'
    TBLPROPERTIES ('orc.compress'='snappy');
