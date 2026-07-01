-- ===================================================
-- ODS 层建表：用户行为日志
-- 数据来源：/origin_data/gmall/log/topic_log/
-- 同步工具：Flume（日志文件 → Kafka → Flume → HDFS）
-- ===================================================

-- ----------------------------
-- 用户行为日志增量表
-- ----------------------------
DROP TABLE IF EXISTS gmall.ods_log_inc;
CREATE EXTERNAL TABLE gmall.ods_log_inc
(
    `common` STRUCT<ar :STRING,         -- common类型：struct
        ba :STRING,
        ch :STRING,
        is_new :STRING,
        md :STRING,
        mid :STRING,
        os :STRING,
        sid :STRING,
        uid :STRING,
        vc :STRING> COMMENT '公共信息',
    `page` STRUCT<during_time :STRING,      -- page类型: struct
        item :STRING,
        item_type :STRING,
        last_page_id :STRING,
        page_id :STRING,
        from_pos_id :STRING,
        from_pos_seq :STRING,
        refer_id :STRING,
        sourceType :STRING> COMMENT '页面信息',
    `actions` ARRAY<STRUCT<action_id:STRING,    -- actions类型: array<struct>
        item:STRING,
        item_type:STRING,
        ts:BIGINT>> COMMENT '动作信息',
    `displays` ARRAY<STRUCT<display_type :STRING,       -- displays类型: array<struct>
        item :STRING,
        item_type :STRING,
        `pos_seq` :STRING,
        pos_id :STRING>> COMMENT '曝光信息',
    `start` STRUCT<entry :STRING,               -- start类型: struct
        first_open :BIGINT,
        loading_time :BIGINT,
        open_ad_id :BIGINT,
        open_ad_ms :BIGINT,
        open_ad_skip_ms :BIGINT> COMMENT '启动信息',
    `err` STRUCT<error_code:BIGINT,             -- err类型: struct
            msg:STRING> COMMENT '错误信息',
    `ts` BIGINT  COMMENT '时间戳'              -- ts类型: bigint
) COMMENT '用户行为日志增量表'
    PARTITIONED BY (`dt` STRING)        -- 创建分区字段
    ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.JsonSerDe'      -- 使用json进行解析,如果表的字段在json中获取不到，不会报错，字段值为null
LOCATION '/warehouse/gmall/ods/ods_log_inc/'            -- 表在hdfs中的存储路径
TBLPROPERTIES ('compression.codec'='org.apache.hadoop.io.compress.GzipCodec');      -- 数据压缩方式gzip
