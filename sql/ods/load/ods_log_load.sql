-- ===================================================
-- ODS 层数据装载：用户行为日志
-- 用途：将 HDFS 原始数据装载到 ODS 表分区
-- 参数：${do_date} — 日期，格式 yyyy-MM-dd
-- ===================================================

-- 装载用户行为日志增量表
LOAD DATA INPATH '/origin_data/gmall/log/topic_log/${do_date}'
OVERWRITE INTO TABLE gmall.ods_log_inc
PARTITION (dt = '${do_date}');
