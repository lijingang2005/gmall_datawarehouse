-- ===================================================
-- ODS 层建表：业务数据增量表
-- 数据来源：/origin_data/gmall/db/{table}_inc/
-- 同步工具：Maxwell（MySQL Binlog → Kafka → Flume → HDFS）
-- ===================================================

-- ----------------------------
-- 订单信息增量表
-- ----------------------------
DROP TABLE IF EXISTS gmall.ods_order_info_inc;
CREATE EXTERNAL TABLE gmall.ods_order_info_inc
(
    `type` STRING COMMENT '变更类型：insert/update/delete',
    `ts`   STRING COMMENT '变更时间戳（10位秒级→补充为13位）',
    `data` STRUCT<
        id:STRING,
        consignee:STRING,
        consignee_tel:STRING,
        total_amount:STRING,
        order_status:STRING,
        user_id:STRING,
        payment_way:STRING,
        delivery_address:STRING,
        order_comment:STRING,
        out_trade_no:STRING,
        trade_body:STRING,
        create_time:STRING,
        operate_time:STRING,
        expire_time:STRING,
        process_status:STRING,
        tracking_no:STRING,
        parent_order_id:STRING,
        img_url:STRING,
        province_id:STRING,
        activity_reduce_amount:STRING,
        coupon_reduce_amount:STRING,
        original_total_amount:STRING,
        feight_fee:STRING,
        feight_fee_reduce:STRING,
        refundable_time:STRING
    > COMMENT '数据内容',
    `old`  MAP<STRING,STRING> COMMENT '变更前数据（仅 update 类型包含）'
)
COMMENT '订单信息增量表'
PARTITIONED BY (`dt` STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE
TBLPROPERTIES ('compression'='gzip');

-- ----------------------------
-- 订单明细增量表
-- ----------------------------
DROP TABLE IF EXISTS gmall.ods_order_detail_inc;
CREATE EXTERNAL TABLE gmall.ods_order_detail_inc
(
    `type` STRING COMMENT '变更类型',
    `ts`   STRING COMMENT '变更时间戳',
    `data` STRUCT<
        id:STRING,
        order_id:STRING,
        sku_id:STRING,
        sku_name:STRING,
        img_url:STRING,
        order_price:STRING,
        sku_num:STRING,
        create_time:STRING,
        source_type:STRING,
        source_id:STRING,
        split_total_amount:STRING,
        split_activity_amount:STRING,
        split_coupon_amount:STRING,
        operate_time:STRING
    > COMMENT '数据内容',
    `old`  MAP<STRING,STRING> COMMENT '变更前数据'
)
COMMENT '订单明细增量表'
PARTITIONED BY (`dt` STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE
TBLPROPERTIES ('compression'='gzip');

-- ----------------------------
-- 支付信息增量表
-- ----------------------------
DROP TABLE IF EXISTS gmall.ods_payment_info_inc;
CREATE EXTERNAL TABLE gmall.ods_payment_info_inc
(
    `type` STRING COMMENT '变更类型',
    `ts`   STRING COMMENT '变更时间戳',
    `data` STRUCT<
        id:STRING,
        out_trade_no:STRING,
        order_id:STRING,
        user_id:STRING,
        payment_type:STRING,
        trade_no:STRING,
        total_amount:STRING,
        subject:STRING,
        payment_status:STRING,
        create_time:STRING,
        callback_time:STRING,
        callback_content:STRING,
        operate_time:STRING
    > COMMENT '数据内容',
    `old`  MAP<STRING,STRING> COMMENT '变更前数据'
)
COMMENT '支付信息增量表'
PARTITIONED BY (`dt` STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE
TBLPROPERTIES ('compression'='gzip');

-- ----------------------------
-- 用户信息增量表
-- ----------------------------
DROP TABLE IF EXISTS gmall.ods_user_info_inc;
CREATE EXTERNAL TABLE gmall.ods_user_info_inc
(
    `type` STRING COMMENT '变更类型',
    `ts`   STRING COMMENT '变更时间戳',
    `data` STRUCT<
        id:STRING,
        login_name:STRING,
        nick_name:STRING,
        passwd:STRING,
        name:STRING,
        phone_num:STRING,
        email:STRING,
        head_img:STRING,
        user_level:STRING,
        birthday:STRING,
        gender:STRING,
        create_time:STRING,
        operate_time:STRING,
        status:STRING
    > COMMENT '数据内容',
    `old`  MAP<STRING,STRING> COMMENT '变更前数据'
)
COMMENT '用户信息增量表'
PARTITIONED BY (`dt` STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE
TBLPROPERTIES ('compression'='gzip');
