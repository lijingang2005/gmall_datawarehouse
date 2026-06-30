-- ===================================================
-- ODS 层建表：用户行为日志
-- 数据来源：/origin_data/gmall/log/topic_log/
-- ===================================================

-- ----------------------------
-- 用户行为日志增量表
-- ----------------------------
DROP TABLE IF EXISTS gmall.ods_log_inc;
CREATE EXTERNAL TABLE gmall.ods_log_inc
(
    `common`   STRING COMMENT '环境信息 JSON（品牌/渠道/设备/会话等）',
    `page`     STRING COMMENT '页面信息 JSON（页面ID/停留时长/来源等）',
    `actions`  STRING COMMENT '动作列表 JSON（点击/加购/收藏等行为）',
    `displays` STRING COMMENT '曝光列表 JSON（商品曝光记录）',
    `err`      STRING COMMENT '错误信息 JSON（错误码/错误信息）',
    `start`    STRING COMMENT '启动信息 JSON（启动入口/广告/加载时间）',
    `ts`       STRING COMMENT '时间戳（13位毫秒级）'
)
COMMENT '用户行为日志增量表 - ODS贴源层'
PARTITIONED BY (`dt` STRING COMMENT '分区日期 yyyy-MM-dd')
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE
LOCATION '/warehouse/gmall/ods/ods_log_inc/'
TBLPROPERTIES ('compression'='gzip');
