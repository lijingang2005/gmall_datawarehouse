-- DWS层(Data Warehouse Summary: 数据汇总层)
    -- 主要用于存储中间的计算汇总结果，以便后续的计算
        -- DWS层放的是具有共通性的中间计算结果表，这张表在后续的统计分析中经常使用
        -- 汇总表设计的使用要考虑共通性，即要考虑到后续的统计分析中可能会使用到的字段
            -- 如果业务过程相同，统计周期相同，粒度也相同，那么就可以考虑使用相同的汇总表
    -- 汇总的数据量不小
        -- 设置分区
    -- 后续还需要再次进行计算
        -- orc
        -- snappy
    -- 命名规范
        -- dws_域_统计粒度_业务行为_统计周期(1d,nd,td)
---------------------------------------------   一日汇总表   -------------------------------------------------------------

--- TODO 交易域用户商品粒度订单最近1日汇总表(存在nd表)
    -- 交易域： 交易相关的标识
    -- 用户商品粒度；group by的字段
    -- 订单  ： 对订单业务做统计
    -- 最近1日汇总表： 统计的周期
-- 建表语句
DROP TABLE IF EXISTS dws_trade_user_sku_order_1d;
CREATE EXTERNAL TABLE dws_trade_user_sku_order_1d
(
    `user_id`                   STRING COMMENT '用户ID',
    `sku_id`                    STRING COMMENT 'SKU_ID',
    `sku_name`                  STRING COMMENT 'SKU名称',
    `category1_id`              STRING COMMENT '一级品类ID',
    `category1_name`            STRING COMMENT '一级品类名称',
    `category2_id`              STRING COMMENT '二级品类ID',
    `category2_name`            STRING COMMENT '二级品类名称',
    `category3_id`              STRING COMMENT '三级品类ID',
    `category3_name`            STRING COMMENT '三级品类名称',
    `tm_id`                      STRING COMMENT '品牌ID',
    `tm_name`                    STRING COMMENT '品牌名称',
    `order_count_1d`            BIGINT COMMENT '最近1日下单次数',
    `order_num_1d`              BIGINT COMMENT '最近1日下单件数',
    `order_original_amount_1d`  DECIMAL(16, 2) COMMENT '最近1日下单原始金额',
    `activity_reduce_amount_1d` DECIMAL(16, 2) COMMENT '最近1日活动优惠金额',
    `coupon_reduce_amount_1d`   DECIMAL(16, 2) COMMENT '最近1日优惠券优惠金额',
    `order_total_amount_1d`     DECIMAL(16, 2) COMMENT '最近1日下单最终金额'
) COMMENT '交易域用户商品粒度订单最近1日汇总表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dws/dws_trade_user_sku_order_1d'
    TBLPROPERTIES ('orc.compress' = 'snappy');

-- 装载数据
    -- 统计求和的字段: 用户下单次数(count)，下单件数(sum)，下单原始金额(sum)，活动优惠金额(sum)，优惠券优惠金额(sum)，下单最终金额(sum)
-- 首日数据装载
    -- 首日数据装载存在历史的订单数据，使用动态分区，将不同日期的汇总结果存放在不同的分区中
set hive.exec.dynamic.partition.mode=nonstrict;
insert overwrite table dws_trade_user_sku_order_1d partition(dt)
select
    user_id,
    id,
    sku_name,
    category1_id,
    category1_name,
    category2_id,
    category2_name,
    category3_id,
    category3_name,
    tm_id,
    tm_name,
    order_count_1d,
    order_num_1d,
    order_original_amount_1d,
    activity_reduce_amount_1d,
    coupon_reduce_amount_1d,
    order_total_amount_1d,
    dt
from(
    select
        dt,
        `user_id`                  ,-- STRING COMMENT '用户ID',
        `sku_id`                   ,-- STRING COMMENT 'SKU_ID',
        count(*) `order_count_1d`           ,-- BIGINT COMMENT '最近1日下单次数',
        sum(sku_num) `order_num_1d`             ,-- BIGINT COMMENT '最近1日下单件数',
        sum(nvl(split_original_amount,0.0))`order_original_amount_1d` ,-- DECIMAL(16, 2) COMMENT '最近1日下单原始金额',
        sum(nvl(split_activity_amount,0.0))`activity_reduce_amount_1d`,-- DECIMAL(16, 2) COMMENT '最近1日活动优惠金额',
        sum(nvl(split_coupon_amount,0.0))`coupon_reduce_amount_1d`  ,-- DECIMAL(16, 2) COMMENT '最近1日优惠券优惠金额',
        sum(split_total_amount)`order_total_amount_1d`    -- DECIMAL(16, 2) COMMENT '最近1日下单最终金额'
    from dwd_trade_order_detail_inc
    group by dt,user_id,sku_id
) od
left join (
    select
        id,
        `sku_name`                 ,-- STRING COMMENT 'SKU名称',
        `category1_id`             ,-- STRING COMMENT '一级品类ID',
        `category1_name`           ,-- STRING COMMENT '一级品类名称',
        `category2_id`             ,-- STRING COMMENT '二级品类ID',
        `category2_name`           ,-- STRING COMMENT '二级品类名称',
        `category3_id`             ,-- STRING COMMENT '三级品类ID',
        `category3_name`           ,-- STRING COMMENT '三级品类名称',
        `tm_id`                    ,--  STRING COMMENT '品牌ID',
        `tm_name`                  --  STRING COMMENT '品牌名称',
    from dim_sku_full
    where dt='2022-06-08'
) sku on od.sku_id = sku.id;


-- 每日数据装载
insert overwrite table dws_trade_user_sku_order_1d partition (dt='2022-06-09')
select
    `user_id`                  ,-- STRING COMMENT '用户ID',
    `sku_id`                   ,-- STRING COMMENT 'SKU_ID',
    `sku_name`                 ,-- STRING COMMENT 'SKU名称',
    `category1_id`             ,-- STRING COMMENT '一级品类ID',
    `category1_name`           ,-- STRING COMMENT '一级品类名称',
    `category2_id`             ,-- STRING COMMENT '二级品类ID',
    `category2_name`           ,-- STRING COMMENT '二级品类名称',
    `category3_id`             ,-- STRING COMMENT '三级品类ID',
    `category3_name`           ,-- STRING COMMENT '三级品类名称',
    `tm_id`                    ,--  STRING COMMENT '品牌ID',
    `tm_name`                  ,--  STRING COMMENT '品牌名称',
    `order_count_1d`           ,-- BIGINT COMMENT '最近1日下单次数',
    `order_num_1d`             ,-- BIGINT COMMENT '最近1日下单件数',
    `order_original_amount_1d` ,-- DECIMAL(16, 2) COMMENT '最近1日下单原始金额',
    `activity_reduce_amount_1d`,-- DECIMAL(16, 2) COMMENT '最近1日活动优惠金额',
    `coupon_reduce_amount_1d`  ,-- DECIMAL(16, 2) COMMENT '最近1日优惠券优惠金额',
    `order_total_amount_1d`    -- DECIMAL(16, 2) COMMENT '最近1日下单最终金额'
from(
    select
        user_id,
        sku_id,
        count(*)  order_count_1d , -- 下单次数
        sum(sku_num) order_num_1d , -- 下单总件数
        sum(split_original_amount) order_original_amount_1d , -- 下单总金额
        sum(nvl(split_activity_amount,0.0)) activity_reduce_amount_1d , -- 活动优惠金额
        sum(nvl(split_coupon_amount,0.0)) coupon_reduce_amount_1d ,  -- 优惠券优惠金额
        sum(split_total_amount) order_total_amount_1d
    from dwd_trade_order_detail_inc
    where dt='2022-06-09'
    group by user_id,sku_id
) od
left join (
    select
        id,
        sku_name,
        tm_id,
        tm_name,
        category1_id,
        category1_name,
        category2_id,
        category2_name,
        category3_id,
        category3_name
    from dim_sku_full
    where dt='2022-06-09'
) sku on od.sku_id = sku.id;


--- TODO 交易域用户粒度订单最近1日汇总表（存在td表）
    -- 交易域
    -- 用户粒度
    -- 订单
    -- 最近1日汇总表
-- 建表语句
DROP TABLE IF EXISTS dws_trade_user_order_1d;
CREATE EXTERNAL TABLE dws_trade_user_order_1d
(
    `user_id`                   STRING COMMENT '用户ID',
    `order_count_1d`            BIGINT COMMENT '最近1日下单次数',
    `order_num_1d`              BIGINT COMMENT '最近1日下单商品件数',
    `order_original_amount_1d`  DECIMAL(16, 2) COMMENT '最近1日下单原始金额',
    `activity_reduce_amount_1d` DECIMAL(16, 2) COMMENT '最近1日下单活动优惠金额',
    `coupon_reduce_amount_1d`   DECIMAL(16, 2) COMMENT '最近1日下单优惠券优惠金额',
    `order_total_amount_1d`     DECIMAL(16, 2) COMMENT '最近1日下单最终金额'
) COMMENT '交易域用户粒度订单最近1日汇总表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dws/dws_trade_user_order_1d'
    TBLPROPERTIES ('orc.compress' = 'snappy');

-- 装载数据
    -- 存在历史下单数据，需要区分首日和每日
-- 首日数据装载
set hive.exec.dynamic.partition.mode=nonstrict;
insert overwrite table dws_trade_user_order_1d partition (dt)
select
    user_id,
    count(distinct order_id),
    sum(sku_num),
    sum(split_original_amount),
    sum(nvl(split_activity_amount,0.0)),
    sum(nvl(split_coupon_amount,0.0)),
    sum(split_total_amount),
    dt
from dwd_trade_order_detail_inc
group by user_id,dt;
-- 每日数据装载
insert overwrite table dws_trade_user_order_1d partition (dt='2022-06-09')
select
    user_id,
    count(distinct order_id),
    sum(sku_num),
    sum(split_original_amount),
    sum(nvl(split_activity_amount,0.0)),
    sum(nvl(split_coupon_amount,0.0)),
    sum(split_total_amount)
from dwd_trade_order_detail_inc
where dt='2022-06-09'
group by user_id;




--- TODO 交易域用户粒度加购最近1日汇总表
-- 建表
DROP TABLE IF EXISTS dws_trade_user_cart_add_1d;
CREATE EXTERNAL TABLE dws_trade_user_cart_add_1d
(
    `user_id`           STRING COMMENT '用户ID',
    `cart_add_count_1d` BIGINT COMMENT '最近1日加购次数',
    `cart_add_num_1d`   BIGINT COMMENT '最近1日加购商品件数'
) COMMENT '交易域用户粒度加购最近1日汇总表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dws/dws_trade_user_cart_add_1d'
    TBLPROPERTIES ('orc.compress' = 'snappy');
-- 数据装载
-- 首次
    -- 存在历史数据，需要动态分区装载
set hive.exec.dynamic.partition.mode=nonstrict;
insert overwrite table dws_trade_user_cart_add_1d partition (dt)
select
    user_id,
    count(*),   -- 每一行数据就是一次加购行为，不需要考虑重复
    sum(sku_num),
    dt
from dwd_trade_cart_add_inc
group by user_id,dt;
-- 每日数据装载
insert overwrite table dws_trade_user_cart_add_1d partition (dt='2022-06-09')
select
    user_id,
    count(*),   -- 每一行数据就是一次加购行为，不需要考虑重复
    sum(sku_num)
from dwd_trade_cart_add_inc
where dt='2022-06-09'
group by user_id;


-- TODO 交易域用户粒度支付最近1日汇总表
-- 建表语句
DROP TABLE IF EXISTS dws_trade_user_payment_1d;
CREATE EXTERNAL TABLE dws_trade_user_payment_1d
(
    `user_id`           STRING COMMENT '用户ID',
    `payment_count_1d`  BIGINT COMMENT '最近1日支付次数',
    `payment_num_1d`    BIGINT COMMENT '最近1日支付商品件数',
    `payment_amount_1d` DECIMAL(16, 2) COMMENT '最近1日支付金额'
) COMMENT '交易域用户粒度支付最近1日汇总表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dws/dws_trade_user_payment_1d'
    TBLPROPERTIES ('orc.compress' = 'snappy');
-- 数据装载
    -- 存在历史数据，需要区分首日和每日数据
-- 首次
insert overwrite table dws_trade_user_payment_1d partition (dt)
select
    user_id,
    count(distinct order_id),   -- 支付表中订单ID是重复的，需要去重处理
    sum(sku_num),
    sum(split_payment_amount),
    dt
from dwd_trade_pay_detail_suc_inc
group by user_id,dt;
-- 每日数据装载
insert overwrite table dws_trade_user_payment_1d partition (dt='2022-06-09')
select
    user_id,
    count(distinct order_id),   -- 支付表中订单ID是重复的，需要去重处理
    sum(sku_num),
    sum(split_payment_amount)
from dwd_trade_pay_detail_suc_inc
where dt='2022-06-09'
group by user_id;



-- TODO 交易域省份粒度订单最近1日汇总表
-- 建表语句
DROP TABLE IF EXISTS dws_trade_province_order_1d;
CREATE EXTERNAL TABLE dws_trade_province_order_1d
(
    `province_id`               STRING COMMENT '省份ID',
    `province_name`             STRING COMMENT '省份名称',
    `area_code`                 STRING COMMENT '地区编码',
    `iso_code`                  STRING COMMENT '旧版国际标准地区编码',
    `iso_3166_2`                STRING COMMENT '新版国际标准地区编码',
    `order_count_1d`            BIGINT COMMENT '最近1日下单次数',
    `order_original_amount_1d`  DECIMAL(16, 2) COMMENT '最近1日下单原始金额',
    `activity_reduce_amount_1d` DECIMAL(16, 2) COMMENT '最近1日下单活动优惠金额',
    `coupon_reduce_amount_1d`   DECIMAL(16, 2) COMMENT '最近1日下单优惠券优惠金额',
    `order_total_amount_1d`     DECIMAL(16, 2) COMMENT '最近1日下单最终金额'
) COMMENT '交易域省份粒度订单最近1日汇总表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dws/dws_trade_province_order_1d'
    TBLPROPERTIES ('orc.compress' = 'snappy');
-- 数据装载
    -- 存在历史数据，需要区分首日和每日数据
    -- 统计粒度和补全字段没有关系，可以先统计在进行补全数据
-- 首次
insert overwrite table dws_trade_province_order_1d partition (dt)
select
    `province_id`               ,--STRING COMMENT '省份ID',
    `province_name`             ,--STRING COMMENT '省份名称',
    `area_code`                 ,--STRING COMMENT '地区编码',
    `iso_code`                  ,--STRING COMMENT '旧版国际标准地区编码',
    `iso_3166_2`                ,--STRING COMMENT '新版国际标准地区编码',
    `order_count_1d`            ,--BIGINT COMMENT '最近1日下单次数',
    `order_original_amount_1d`  ,--DECIMAL(16, 2) COMMENT '最近1日下单原始金额',
    `activity_reduce_amount_1d` ,--DECIMAL(16, 2) COMMENT '最近1日下单活动优惠金额',
    `coupon_reduce_amount_1d`   ,--DECIMAL(16, 2) COMMENT '最近1日下单优惠券优惠金额',
    `order_total_amount_1d`     ,--DECIMAL(16, 2) COMMENT '最近1日下单最终金额'
    dt
from(
    select
        province_id,
        count(distinct order_id) as order_count_1d,
        sum(split_original_amount) as order_original_amount_1d,
        sum(nvl(split_activity_amount,0.0)) as activity_reduce_amount_1d,
        sum(nvl(split_coupon_amount,0.0)) as coupon_reduce_amount_1d,
        sum(split_total_amount) as order_total_amount_1d,
        dt
    from dwd_trade_order_detail_inc
    group by province_id,dt
) od
left join (
    select
        id,
        `province_name`  ,
        `area_code`      ,
        `iso_code`       ,
        `iso_3166_2`
    from dim_province_full
    where dt='2022-06-08'
) prv on od.province_id=prv.id;
-- 每次
insert overwrite table dws_trade_province_order_1d partition (dt='2022-06-09')
select
    `province_id`               ,--STRING COMMENT '省份ID',
    `province_name`             ,--STRING COMMENT '省份名称',
    `area_code`                 ,--STRING COMMENT '地区编码',
    `iso_code`                  ,--STRING COMMENT '旧版国际标准地区编码',
    `iso_3166_2`                ,--STRING COMMENT '新版国际标准地区编码',
    `order_count_1d`            ,--BIGINT COMMENT '最近1日下单次数',
    `order_original_amount_1d`  ,--DECIMAL(16, 2) COMMENT '最近1日下单原始金额',
    `activity_reduce_amount_1d` ,--DECIMAL(16, 2) COMMENT '最近1日下单活动优惠金额',
    `coupon_reduce_amount_1d`   ,--DECIMAL(16, 2) COMMENT '最近1日下单优惠券优惠金额',
    `order_total_amount_1d`     --DECIMAL(16, 2) COMMENT '最近1日下单最终金额'
from(
    select
        province_id,
        count(distinct order_id) as order_count_1d,
        sum(split_original_amount) as order_original_amount_1d,
        sum(nvl(split_activity_amount,0.0)) as activity_reduce_amount_1d,
        sum(nvl(split_coupon_amount,0.0)) as coupon_reduce_amount_1d,
        sum(split_total_amount) as order_total_amount_1d
    from dwd_trade_order_detail_inc
    where dt = '2022-06-09'
    group by province_id
) od
left join (
    select
        id,
        `province_name`  ,
        `area_code`      ,
        `iso_code`       ,
        `iso_3166_2`
    from dim_province_full
    where dt='2022-06-09'
) prv on od.province_id=prv.id;



-- TODO 工具域用户优惠券粒度优惠券使用(支付)最近1日汇总表
-- 建表
DROP TABLE IF EXISTS dws_tool_user_coupon_coupon_used_1d;
CREATE EXTERNAL TABLE dws_tool_user_coupon_coupon_used_1d
(
    `user_id`          STRING COMMENT '用户ID',
    `coupon_id`        STRING COMMENT '优惠券ID',
    `coupon_name`      STRING COMMENT '优惠券名称',
    `coupon_type_code` STRING COMMENT '优惠券类型编码',
    `coupon_type_name` STRING COMMENT '优惠券类型名称',
    `benefit_rule`     STRING COMMENT '优惠规则',
    `used_count_1d`    STRING COMMENT '使用(支付)次数'
) COMMENT '工具域用户优惠券粒度优惠券使用(支付)最近1日汇总表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dws/dws_tool_user_coupon_coupon_used_1d'
    TBLPROPERTIES ('orc.compress' = 'snappy');

-- 数据装载
    -- 存在历史数据，首次需要动态分区
    -- 统计粒度和补全字段没有关系，可以先统计在进行补全数据
-- 首次数据装载
insert overwrite table dws_tool_user_coupon_coupon_used_1d partition (dt)
select
    `user_id`          ,--STRING COMMENT '用户ID',
    `coupon_id`        ,--STRING COMMENT '优惠券ID',
    `coupon_name`      ,--STRING COMMENT '优惠券名称',
    `coupon_type_code` ,--STRING COMMENT '优惠券类型编码',
    `coupon_type_name` ,--STRING COMMENT '优惠券类型名称',
    `benefit_rule`     ,--STRING COMMENT '优惠规则',
    `used_count_1d`    ,--STRING COMMENT '使用(支付)次数'
    dt
from(
    select
        user_id,
        coupon_id,
        count(*) used_count_1d,
        dt
    from dwd_tool_coupon_used_inc
    group by user_id,coupon_id,dt
) cu
left join (
    select
        id,
        coupon_name,
        coupon_type_code,
        coupon_type_name,
        benefit_rule
    from dim_coupon_full
    where dt='2022-06-08'
) cp on cu.coupon_id = cp.id;
-- 每日装载
insert overwrite table dws_tool_user_coupon_coupon_used_1d partition (dt='2022-06-09')
select
    `user_id`          ,--STRING COMMENT '用户ID',
    `coupon_id`        ,--STRING COMMENT '优惠券ID',
    `coupon_name`      ,--STRING COMMENT '优惠券名称',
    `coupon_type_code` ,--STRING COMMENT '优惠券类型编码',
    `coupon_type_name` ,--STRING COMMENT '优惠券类型名称',
    `benefit_rule`     ,--STRING COMMENT '优惠规则',
    `used_count_1d`    --STRING COMMENT '使用(支付)次数'
from(
    select
        user_id,
        coupon_id,
        count(*) used_count_1d
    from dwd_tool_coupon_used_inc
    where dt='2022-06-09'
    group by user_id,coupon_id
) cu
left join (
    select
        id,
        coupon_name,
        coupon_type_code,
        coupon_type_name,
        benefit_rule
    from dim_coupon_full
    where dt='2022-06-09'
) cp on cu.coupon_id = cp.id;


--- TODO 互动域商品粒度收藏商品最近1日汇总表
-- 建表语句
DROP TABLE IF EXISTS dws_interaction_sku_favor_add_1d;
CREATE EXTERNAL TABLE dws_interaction_sku_favor_add_1d
(
    `sku_id`             STRING COMMENT 'SKU_ID',
    `sku_name`           STRING COMMENT 'SKU名称',
    `category1_id`       STRING COMMENT '一级品类ID',
    `category1_name`     STRING COMMENT '一级品类名称',
    `category2_id`       STRING COMMENT '二级品类ID',
    `category2_name`     STRING COMMENT '二级品类名称',
    `category3_id`       STRING COMMENT '三级品类ID',
    `category3_name`     STRING COMMENT '三级品类名称',
    `tm_id`              STRING COMMENT '品牌ID',
    `tm_name`            STRING COMMENT '品牌名称',
    `favor_add_count_1d` BIGINT COMMENT '商品被收藏次数'
) COMMENT '互动域商品粒度收藏商品最近1日汇总表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dws/dws_interaction_sku_favor_add_1d'
    TBLPROPERTIES ('orc.compress' = 'snappy');

-- 装载数据
-- 首日数据装载
insert overwrite table dws_interaction_sku_favor_add_1d partition (dt)
select
    `sku_id`             ,--STRING COMMENT 'SKU_ID',
    `sku_name`           ,--STRING COMMENT 'SKU名称',
    `category1_id`       ,--STRING COMMENT '一级品类ID',
    `category1_name`     ,--STRING COMMENT '一级品类名称',
    `category2_id`       ,--STRING COMMENT '二级品类ID',
    `category2_name`     ,--STRING COMMENT '二级品类名称',
    `category3_id`       ,--STRING COMMENT '三级品类ID',
    `category3_name`     ,--STRING COMMENT '三级品类名称',
    `tm_id`              ,--STRING COMMENT '品牌ID',
    `tm_name`            ,--STRING COMMENT '品牌名称',
    `favor_add_count_1d` ,--BIGINT COMMENT '商品被收藏次数'
    dt
from(
    select
        sku_id,
        count(*) favor_add_count_1d,
        dt
    from dwd_interaction_favor_add_inc
    group by sku_id,dt
) fa
left join (
    select
        id             ,--STRING COMMENT 'SKU_ID',
        `sku_name`           ,--STRING COMMENT 'SKU名称',
        `category1_id`       ,--STRING COMMENT '一级品类ID',
        `category1_name`     ,--STRING COMMENT '一级品类名称',
        `category2_id`       ,--STRING COMMENT '二级品类ID',
        `category2_name`     ,--STRING COMMENT '二级品类名称',
        `category3_id`       ,--STRING COMMENT '三级品类ID',
        `category3_name`     ,--STRING COMMENT '三级品类名称',
        `tm_id`              ,--STRING COMMENT '品牌ID',
        `tm_name`            --STRING COMMENT '品牌名称',
    from dim_sku_full
    where dt='2022-06-08'
) sku on fa.sku_id = sku.id;
-- 每日装载
insert overwrite table dws_interaction_sku_favor_add_1d partition (dt='2022-06-09')
select
    `sku_id`             ,--STRING COMMENT 'SKU_ID',
    `sku_name`           ,--STRING COMMENT 'SKU名称',
    `category1_id`       ,--STRING COMMENT '一级品类ID',
    `category1_name`     ,--STRING COMMENT '一级品类名称',
    `category2_id`       ,--STRING COMMENT '二级品类ID',
    `category2_name`     ,--STRING COMMENT '二级品类名称',
    `category3_id`       ,--STRING COMMENT '三级品类ID',
    `category3_name`     ,--STRING COMMENT '三级品类名称',
    `tm_id`              ,--STRING COMMENT '品牌ID',
    `tm_name`            ,--STRING COMMENT '品牌名称',
    `favor_add_count_1d` --BIGINT COMMENT '商品被收藏次数'
from(
    select
        sku_id,
        count(*) favor_add_count_1d
    from dwd_interaction_favor_add_inc
    where dt='2022-06-09'
    group by sku_id
) fa
left join (
    select
        id             ,--STRING COMMENT 'SKU_ID',
        `sku_name`           ,--STRING COMMENT 'SKU名称',
        `category1_id`       ,--STRING COMMENT '一级品类ID',
        `category1_name`     ,--STRING COMMENT '一级品类名称',
        `category2_id`       ,--STRING COMMENT '二级品类ID',
        `category2_name`     ,--STRING COMMENT '二级品类名称',
        `category3_id`       ,--STRING COMMENT '三级品类ID',
        `category3_name`     ,--STRING COMMENT '三级品类名称',
        `tm_id`              ,--STRING COMMENT '品牌ID',
        `tm_name`            --STRING COMMENT '品牌名称',
    from dim_sku_full
    where dt='2022-06-09'
) sku on fa.sku_id = sku.id;


-- TODO 流量域会话粒度页面浏览最近1日汇总表
-- 建表语句
DROP TABLE IF EXISTS dws_traffic_session_page_view_1d;
CREATE EXTERNAL TABLE dws_traffic_session_page_view_1d
(
    `session_id`     STRING COMMENT '会话ID',
    `mid_id`         string comment '设备ID',
    `brand`          string comment '手机品牌',
    `model`          string comment '手机型号',
    `operate_system` string comment '操作系统',
    `version_code`   string comment 'APP版本号',
    `channel`        string comment '渠道',
    `during_time_1d` BIGINT COMMENT '最近1日浏览时长',
    `page_count_1d`  BIGINT COMMENT '最近1日浏览页面数'
) COMMENT '流量域会话粒度页面浏览最近1日汇总表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dws/dws_traffic_session_page_view_1d'
    TBLPROPERTIES ('orc.compress' = 'snappy');

-- 装载数据
    -- 数据源是流量域页面浏览增量表(dwd_traffic_page_view_inc),这个表的来源是用户行为日志,只有数仓上线之后再有数据
    -- 所以不需要考虑首次是否存在历史数据
insert overwrite table dws_traffic_session_page_view_1d partition (dt='2022-06-08')
select
    `session_id`     ,--STRING COMMENT '会话ID',
    `mid_id`         ,--string comment '设备ID',
    `brand`          ,--string comment '手机品牌',
    `model`          ,--string comment '手机型号',
    `operate_system` ,--string comment '操作系统',
    `version_code`   ,--string comment 'APP版本号',
    `channel`        ,--string comment '渠道',
    sum(during_time) `during_time_1d` ,--BIGINT COMMENT '最近1日浏览时长',
    count(*) `page_count_1d`  --BIGINT COMMENT '最近1日浏览页面数'
from dwd_traffic_page_view_inc
where dt='2022-06-08'
group by session_id,mid_id,brand,model,operate_system,version_code,channel;


-- TODO 流量域访客页面粒度页面浏览最近1日汇总表
-- 建表语句
DROP TABLE IF EXISTS dws_traffic_page_visitor_page_view_1d;
CREATE EXTERNAL TABLE dws_traffic_page_visitor_page_view_1d
(
    `mid_id`         STRING COMMENT '访客ID',
    `brand`          string comment '手机品牌',
    `model`          string comment '手机型号',
    `operate_system` string comment '操作系统',
    `page_id`        STRING COMMENT '页面ID',
    `during_time_1d` BIGINT COMMENT '最近1日浏览时长',
    `view_count_1d`  BIGINT COMMENT '最近1日访问次数'
) COMMENT '流量域访客页面粒度页面浏览最近1日汇总表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dws/dws_traffic_page_visitor_page_view_1d'
    TBLPROPERTIES ('orc.compress' = 'snappy');
-- 装载数据
    -- 不区分首次和每日
    -- 数据源是流量域页面浏览增量表(dwd_traffic_page_view_inc),这个表的来源是用户行为日志,只有数仓上线之后才有数据
insert overwrite table dws_traffic_page_visitor_page_view_1d partition(dt='2022-06-08')
select
    mid_id,
    brand,
    model,
    operate_system,
    page_id,
    sum(during_time),
    count(*)
from dwd_traffic_page_view_inc
where dt='2022-06-08'
group by mid_id,brand,model,operate_system,page_id;










---------------------------------------------- n日汇总表 ----------------------------------------------------------------

--- TODO 交易域用户商品粒度订单最近N日汇总表
-- 建表
DROP TABLE IF EXISTS dws_trade_user_sku_order_nd;
CREATE EXTERNAL TABLE dws_trade_user_sku_order_nd
(
    `user_id`                     STRING COMMENT '用户ID',
    `sku_id`                      STRING COMMENT 'SKU_ID',
    `sku_name`                    STRING COMMENT 'SKU名称',
    `category1_id`               STRING COMMENT '一级品类ID',
    `category1_name`             STRING COMMENT '一级品类名称',
    `category2_id`               STRING COMMENT '二级品类ID',
    `category2_name`             STRING COMMENT '二级品类名称',
    `category3_id`               STRING COMMENT '三级品类ID',
    `category3_name`             STRING COMMENT '三级品类名称',
    `tm_id`                       STRING COMMENT '品牌ID',
    `tm_name`                     STRING COMMENT '品牌名称',
    `order_count_7d`             STRING COMMENT '最近7日下单次数',
    `order_num_7d`               BIGINT COMMENT '最近7日下单件数',
    `order_original_amount_7d`   DECIMAL(16, 2) COMMENT '最近7日下单原始金额',
    `activity_reduce_amount_7d`  DECIMAL(16, 2) COMMENT '最近7日活动优惠金额',
    `coupon_reduce_amount_7d`    DECIMAL(16, 2) COMMENT '最近7日优惠券优惠金额',
    `order_total_amount_7d`      DECIMAL(16, 2) COMMENT '最近7日下单最终金额',
    `order_count_30d`            BIGINT COMMENT '最近30日下单次数',
    `order_num_30d`              BIGINT COMMENT '最近30日下单件数',
    `order_original_amount_30d`  DECIMAL(16, 2) COMMENT '最近30日下单原始金额',
    `activity_reduce_amount_30d` DECIMAL(16, 2) COMMENT '最近30日活动优惠金额',
    `coupon_reduce_amount_30d`   DECIMAL(16, 2) COMMENT '最近30日优惠券优惠金额',
    `order_total_amount_30d`     DECIMAL(16, 2) COMMENT '最近30日下单最终金额'
) COMMENT '交易域用户商品粒度订单最近n日汇总表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dws/dws_trade_user_sku_order_nd'
    TBLPROPERTIES ('orc.compress' = 'snappy');

-- 装载数据
insert overwrite table dws_trade_user_sku_order_nd partition (dt='2022-06-08')
select
    `user_id`                   ,-- STRING COMMENT '用户ID',
    `sku_id`                    ,-- STRING COMMENT 'SKU_ID',
    `sku_name`                  ,-- STRING COMMENT 'SKU名称',
    `category1_id`              ,--STRING COMMENT '一级品类ID',
    `category1_name`            ,--STRING COMMENT '一级品类名称',
    `category2_id`              ,--STRING COMMENT '二级品类ID',
    `category2_name`            ,--STRING COMMENT '二级品类名称',
    `category3_id`              ,--STRING COMMENT '三级品类ID',
    `category3_name`            ,--STRING COMMENT '三级品类名称',
    `tm_id`                     ,-- STRING COMMENT '品牌ID',
    `tm_name`                   ,-- STRING COMMENT '品牌名称',
    sum(if(dt>=date_add('2022-06-08',-6),order_count_1d,0))`order_count_7d`            ,--STRING COMMENT '最近7日下单次数',
    sum(if(dt>=date_add('2022-06-08',-6),order_num_1d,0)) `order_num_7d`              ,--BIGINT COMMENT '最近7日下单件数',
    sum(if(dt>=date_add('2022-06-08',-6),order_original_amount_1d,0)) `order_original_amount_7d`  ,--DECIMAL(16, 2) COMMENT '最近7日下单原始金额',
    sum(if(dt>=date_add('2022-06-08',-6),activity_reduce_amount_1d,0))`activity_reduce_amount_7d` ,--DECIMAL(16, 2) COMMENT '最近7日活动优惠金额',
    sum(if(dt>=date_add('2022-06-08',-6),coupon_reduce_amount_1d,0))`coupon_reduce_amount_7d`   ,--DECIMAL(16, 2) COMMENT '最近7日优惠券优惠金额',
    sum(if(dt>=date_add('2022-06-08',-6),order_total_amount_1d,0))`order_total_amount_7d`     ,--DECIMAL(16, 2) COMMENT '最近7日下单最终金额',
    sum(order_count_1d) `order_count_30d`           ,--BIGINT COMMENT '最近30日下单次数',
    sum(order_num_1d)`order_num_30d`             ,--BIGINT COMMENT '最近30日下单件数',
    sum(order_original_amount_1d) `order_original_amount_30d` ,--DECIMAL(16, 2) COMMENT '最近30日下单原始金额',
    sum(activity_reduce_amount_1d)`activity_reduce_amount_30d`,--DECIMAL(16, 2) COMMENT '最近30日活动优惠金额',
    sum(coupon_reduce_amount_1d) `coupon_reduce_amount_30d`  ,--DECIMAL(16, 2) COMMENT '最近30日优惠券优惠金额',
    sum(order_total_amount_1d) `order_total_amount_30d`    --DECIMAL(16, 2) COMMENT '最近30日下单最终金额'
from dws_trade_user_sku_order_1d
where dt >= date_sub('2022-06-08',29) and dt <= '2022-06-08'
group by `user_id`, `sku_id`, `sku_name`, `category1_id`, `category1_name`, `category2_id`, `category2_name`, `category3_id`, `category3_name`, `tm_id`, `tm_name` ;


--- TODO 交易域省份粒度订单最近n日汇总表
-- 建表语句
DROP TABLE IF EXISTS dws_trade_province_order_nd;
CREATE EXTERNAL TABLE dws_trade_province_order_nd
(
    `province_id`                STRING COMMENT '省份ID',
    `province_name`              STRING COMMENT '省份名称',
    `area_code`                  STRING COMMENT '地区编码',
    `iso_code`                   STRING COMMENT '旧版国际标准地区编码',
    `iso_3166_2`                 STRING COMMENT '新版国际标准地区编码',
    `order_count_7d`             BIGINT COMMENT '最近7日下单次数',
    `order_original_amount_7d`   DECIMAL(16, 2) COMMENT '最近7日下单原始金额',
    `activity_reduce_amount_7d`  DECIMAL(16, 2) COMMENT '最近7日下单活动优惠金额',
    `coupon_reduce_amount_7d`    DECIMAL(16, 2) COMMENT '最近7日下单优惠券优惠金额',
    `order_total_amount_7d`      DECIMAL(16, 2) COMMENT '最近7日下单最终金额',
    `order_count_30d`            BIGINT COMMENT '最近30日下单次数',
    `order_original_amount_30d`  DECIMAL(16, 2) COMMENT '最近30日下单原始金额',
    `activity_reduce_amount_30d` DECIMAL(16, 2) COMMENT '最近30日下单活动优惠金额',
    `coupon_reduce_amount_30d`   DECIMAL(16, 2) COMMENT '最近30日下单优惠券优惠金额',
    `order_total_amount_30d`     DECIMAL(16, 2) COMMENT '最近30日下单最终金额'
) COMMENT '交易域省份粒度订单最近n日汇总表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dws/dws_trade_province_order_nd'
    TBLPROPERTIES ('orc.compress' = 'snappy');
-- 数据装载
    -- 基于dws_trade_province_order_1d表进行计算
    -- 计算最近7日、30日的订单数据，不需要动态分区，直接计算即可
insert overwrite table dws_trade_province_order_nd partition(dt='2022-06-08')
select
    `province_id`                ,--STRING COMMENT '省份ID',
    `province_name`              ,--STRING COMMENT '省份名称',
    `area_code`                  ,--STRING COMMENT '地区编码',
    `iso_code`                   ,--STRING COMMENT '旧版国际标准地区编码',
    `iso_3166_2`                 ,--STRING COMMENT '新版国际标准地区编码',
    sum( if(dt>=date_sub('2022-06-08',6),order_count_1d,0) ) `order_count_7d`             ,--BIGINT COMMENT '最近7日下单次数',
    sum( if(dt>=date_sub('2022-06-08',6),order_original_amount_1d,0) ) `order_original_amount_7d`   ,--DECIMAL(16, 2) COMMENT '最近7日下单原始金额',
    sum( if(dt>=date_sub('2022-06-08',6),activity_reduce_amount_1d,0) ) `activity_reduce_amount_7d`  ,--DECIMAL(16, 2) COMMENT '最近7日下单活动优惠金额',
    sum( if(dt>=date_sub('2022-06-08',6),coupon_reduce_amount_1d,0) ) `coupon_reduce_amount_7d`    ,--DECIMAL(16, 2) COMMENT '最近7日下单优惠券优惠金额',
    sum( if(dt>=date_sub('2022-06-08',6),order_total_amount_1d,0) ) `order_total_amount_7d`      ,--DECIMAL(16, 2) COMMENT '最近7日下单最终金额',
    sum(order_count_1d) `order_count_30d`            ,--BIGINT COMMENT '最近30日下单次数',
    sum(order_original_amount_1d) `order_original_amount_30d`  ,--DECIMAL(16, 2) COMMENT '最近30日下单原始金额',
    sum(activity_reduce_amount_1d) `activity_reduce_amount_30d` ,--DECIMAL(16, 2) COMMENT '最近30日下单活动优惠金额',
    sum(coupon_reduce_amount_1d) `coupon_reduce_amount_30d`   ,--DECIMAL(16, 2) COMMENT '最近30日下单优惠券优惠金额',
    sum(order_total_amount_1d) `order_total_amount_30d`     --DECIMAL(16, 2) COMMENT '最近30日下单最终金额'
from dws_trade_province_order_1d
where dt >= date_sub('2022-06-08',29) and dt <= '2022-06-08'
group by `province_id`  ,
    `province_name`     ,
    `area_code`         ,
    `iso_code`          ,
    `iso_3166_2`        ;






----------------------------------------- 历史至今汇总表 -----------------------------------------------------------------
-- TODO 交易域用户粒度订单历史至今汇总表
    -- 统计至今的历史数据
    -- 为什么使用历史至今汇总表，而不是最近N日汇总表
        -- 1，历史至今汇总表可以统计用户从注册到当前时间的所有订单数据，可以统计用户第一天下单时间和最后一次下单时间
        -- 2，历史至今汇总表可以统计用户从注册到当前时间的所有订单数据，可以统计用户在各个时间段的活跃度
-- 建表
DROP TABLE IF EXISTS dws_trade_user_order_td;
CREATE EXTERNAL TABLE dws_trade_user_order_td
(
    `user_id`                   STRING COMMENT '用户ID',
    `order_date_first`          STRING COMMENT '历史至今首次下单日期',
    `order_date_last`           STRING COMMENT '历史至今末次下单日期',
    `order_count_td`            BIGINT COMMENT '历史至今下单次数',
    `order_num_td`              BIGINT COMMENT '历史至今购买商品件数',
    `original_amount_td`        DECIMAL(16, 2) COMMENT '历史至今下单原始金额',
    `activity_reduce_amount_td` DECIMAL(16, 2) COMMENT '历史至今下单活动优惠金额',
    `coupon_reduce_amount_td`   DECIMAL(16, 2) COMMENT '历史至今下单优惠券优惠金额',
    `total_amount_td`           DECIMAL(16, 2) COMMENT '历史至今下单最终金额'
) COMMENT '交易域用户粒度订单历史至今汇总表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dws/dws_trade_user_order_td'
    TBLPROPERTIES ('orc.compress' = 'snappy');
-- 数据装载
    -- 需要区分首日和每日
        -- 首次需要获取全部数据，这个是必须的，因为历史至今汇总表需要统计用户从注册到当前时间的所有订单数据
        -- 每日只需要获取当日的数据和前一天的统计结果进一步汇总就可以
    -- 数据来源
        -- 可以从1D表中获取（优先选择，因为已经经过预聚合，数据量小），也可以从DWD + DIM表中获取
-- 首次装载
insert overwrite table dws_trade_user_order_td partition (dt='2022-06-08')
select
    user_id,
    min(dt) `order_date_first`,
    max(dt) `order_date_last`,
    sum(order_count_1d) `order_count_td`,
    sum(order_num_1d) `order_num_td`,
    sum(order_original_amount_1d) `original_amount_td`,
    sum(activity_reduce_amount_1d) `activity_reduce_amount_td`,
    sum(coupon_reduce_amount_1d) `coupon_reduce_amount_td`,
    sum(order_total_amount_1d) `total_amount_td`
from dws_trade_user_order_1d
group by user_id;
-- 每日装载
insert overwrite table dws_trade_user_order_td partition (dt='2022-06-09')
select
    user_id,
    min(order_date_first),
    max(order_date_last),
    sum(order_count_td),
    sum(order_num_td),
    sum(original_amount_td),
    sum(activity_reduce_amount_td),
    sum(coupon_reduce_amount_td),
    sum(total_amount_td)
from(
    select
        `user_id`                   ,--STRING COMMENT '用户ID',
        `order_date_first`          ,--STRING COMMENT '历史至今首次下单日期',
        `order_date_last`           ,--STRING COMMENT '历史至今末次下单日期',
        `order_count_td`            ,--BIGINT COMMENT '历史至今下单次数',
        `order_num_td`              ,--BIGINT COMMENT '历史至今购买商品件数',
        `original_amount_td`        ,--DECIMAL(16, 2) COMMENT '历史至今下单原始金额',
        `activity_reduce_amount_td` ,--DECIMAL(16, 2) COMMENT '历史至今下单活动优惠金额',
        `coupon_reduce_amount_td`   ,--DECIMAL(16, 2) COMMENT '历史至今下单优惠券优惠金额',
        `total_amount_td`           --DECIMAL(16, 2) COMMENT '历史至今下单最终金额'
    from dws_trade_user_order_td    -- 昨日统计结果
    union all
    select
        user_id,
        '2022-06-09',
        '2022-06-09',
        order_count_1d,
        order_num_1d,
        order_original_amount_1d,
        activity_reduce_amount_1d,
        coupon_reduce_amount_1d,
        order_total_amount_1d
    from dws_trade_user_order_1d   -- 当日数据
    where dt = '2022-06-09'
) t group by user_id;



--- TODO 用户域用户粒度登录历史至今汇总表
-- 建表
DROP TABLE IF EXISTS dws_user_user_login_td;
CREATE EXTERNAL TABLE dws_user_user_login_td
(
    `user_id`          STRING COMMENT '用户ID',
    `login_date_last`  STRING COMMENT '历史至今末次登录日期',
    `login_date_first` STRING COMMENT '历史至今首次登录日期',
    `login_count_td`   BIGINT COMMENT '历史至今累计登录次数'
) COMMENT '用户域用户粒度登录历史至今汇总表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dws/dws_user_user_login_td'
    TBLPROPERTIES ('orc.compress' = 'snappy');
-- 数据装载
    -- 历史至今汇总表首次肯定需要进行全表扫描
    -- 每日只需要获取当日的数据和前一天的统计结果进一步汇总就可以
-- 首次装载
    -- 从dwd_user_login_inc表中获取数据存在问题
        -- dwd_user_login_inc表的数据是从用户行为日志中取数据的，但是数仓上线之前是没有日志数据的，所以dwd_user_login_inc表没有历史数据
        -- 对于首次登录，我们可以选择注册表的时间作为首次登录时间
insert overwrite table dws_user_user_login_td partition (dt='2022-06-08')
select
    `user_id`         ,
    max(login_date_last) `login_date_last`,
    min(login_date_first) `login_date_first`,
    count(*) `login_count_td`
from(
    select
        user_id,
        dt login_date_last,     -- 第一次注册是最后一次登录
        dt login_date_first,      -- 第一次注册是首次登录
        1 login_count_td
    from dwd_user_register_inc
    where dt < '2022-06-08'  -- 之前的注册信息，作为首次登录时间
    union all
    select
        user_id,
        '2022-06-08',
        '2022-06-08',
        count(*) `login_count_td`
    from dwd_user_login_inc
    group by user_id
) t group by user_id;
-- 每日数据装载（基于dws_user_user_login_td表）
insert overwrite table dws_user_user_login_td partition (dt='2022-06-09')
select
    user_id,
    max(login_date_last) `login_date_last`,
    min(login_date_first) `login_date_first`,
    sum(login_count_td) `login_count_td`
from (
    select
        user_id,
        login_date_last,
        login_date_first,
        login_count_td
    from dws_user_user_login_td
    union all
    select
        user_id,
        dt,
        dt,
        count(*) `login_count_td`
    from dwd_user_login_inc
    where dt = '2022-06-09'
    group by user_id
) t group by user_id;



