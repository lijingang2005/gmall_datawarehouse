-- dim(Dimension 维度层)
    -- 进行统计分析的角度：维度表
    -- 维度表的存储格式与压缩方式
        -- 存储格式:orc列式存储，满足快速查询统计分析
        -- 压缩方式:snappy，主要看压缩比率，提高执行速度
    -- 维度表的创建遵循维度模型
        -- 事实表：用户行为产生的数据，一般是增量表
        -- 维度表：统计分析数据的角度（环境），一般是全量表
    -- 维度表创建
        -- 1,理论上，每一个角度(环境)都需要创建一个维度表(例如：用户年龄，用户身高)
        -- 2,但是，如果维度之间存在关联关系,可以合成一个维度表(例如: 用户身高，用户年龄都是属于用户相关的维度，可以合并成一个用户维度表)
        -- 3,如果一个维度表很小并且适用范围小，不必抽成一个单独的维度表(如支付方式，只有在统计用户下单的时候才会用到，其他地方不使用，则不抽成维度表)

--- TODO 商品维度表
    -- 主维表：商品表(ods_sku_info),商品的基本信息,sku_id,商品名称,描述，价格，重量，是否在售，创建时间
    -- 相关维表：
        -- 商品平台属性表(ods_sku_attr_value_full),规格参数(如屏幕尺寸、内存容量等技术参数)
        -- 商品销售属性表(ods_sku_sale_attr_value_full),销售规格(如颜色、版本等影响销售的属性)


    -- 建表语句
DROP TABLE IF EXISTS dim_sku_full;
CREATE EXTERNAL TABLE dim_sku_full(
    `id`                   STRING COMMENT 'SKU_ID',   -- 商品id
    `price`                DECIMAL(16, 2) COMMENT '商品价格',
    `sku_name`             STRING COMMENT '商品名称',
    `sku_desc`             STRING COMMENT '商品描述',
    `weight`               DECIMAL(16, 2) COMMENT '重量',
    `is_sale`              BOOLEAN COMMENT '是否在售',
    `spu_id`               STRING COMMENT 'SPU编号',
    `spu_name`             STRING COMMENT 'SPU名称',
    `category3_id`         STRING COMMENT '三级品类ID',
    `category3_name`       STRING COMMENT '三级品类名称',
    `category2_id`         STRING COMMENT '二级品类id',
    `category2_name`       STRING COMMENT '二级品类名称',
    `category1_id`         STRING COMMENT '一级品类ID',
    `category1_name`       STRING COMMENT '一级品类名称',
    `tm_id`                  STRING COMMENT '品牌ID',
    `tm_name`               STRING COMMENT '品牌名称',
    `sku_attr_values`      ARRAY<STRUCT<attr_id :STRING,
        value_id :STRING,
        attr_name :STRING,
        value_name:STRING>> COMMENT '平台属性',
    `sku_sale_attr_values` ARRAY<STRUCT<sale_attr_id :STRING,
        sale_attr_value_id :STRING,
        sale_attr_name :STRING,
        sale_attr_value_name:STRING>> COMMENT '销售属性',
    `create_time`          STRING COMMENT '创建时间'
) COMMENT '商品维度表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC       -- 使用列式存储，提高统计分析效率
    LOCATION '/warehouse/gmall/dim/dim_sku_full/'
    TBLPROPERTIES ('orc.compress' = 'snappy');      -- 使用snappy压缩，提高执行效率

-- 装载数据
    -- 查询出维度表需要的数据
    -- 将数据导入到维度表
    -- 细节：
        -- 使用left join: 正常应该使用join,取有关联的数据，但是在分布式生产环境中可能会有数据丢失，为了尽可能的不影响结果(join可能导致一行数据都没有)，这里使用left join
        -- 分区字段：dt,每一张表查询的时候都应该使用分区字段过滤，只对一个分区进行操作
        -- 插入方式：insert overwrite,真实场景中是使用脚本执行sql语句，在分布式环境中可能出现问题要重试(例如网络问题)，所以这里使用insert overwrite覆盖写入，不会导致数据重复
        -- 一对多的关系：一个商品会有多个平台属性和销售属性，所以使用数组聚合
insert overwrite table dim_sku_full partition(dt='2022-06-08')
select
    sku.`id`               ,
    `price`                ,
    `sku_name`             ,
    `sku_desc`             ,
    `weight`               ,
    `is_sale`              ,
    `spu_id`               ,
    `spu_name`             ,
    `category3_id`         ,
    `category3_name`       ,
    `category2_id`         ,
    `category2_name`       ,
    `category1_id`         ,
    `category1_name`       ,
    `tm_id`                ,
    `tm_name`              ,
    `sku_attr_values`      ,
    `sku_sale_attr_values` ,
    `create_time`
from (
    select
    `id`                   , --STRING COMMENT 'SKU_ID',   -- 商品id
    `price`                , --DECIMAL(16, 2) COMMENT '商品价格',
    `sku_name`             , --STRING COMMENT '商品名称',
    `sku_desc`             , --STRING COMMENT '商品描述',
    `weight`               , --DECIMAL(16, 2) COMMENT '重量',
    `is_sale`              , --BOOLEAN COMMENT '是否在售',
    `spu_id`               , --STRING COMMENT 'SPU编号',
    -- `spu_name`             , --STRING COMMENT 'SPU名称',
    `category3_id`         , --STRING COMMENT '三级品类ID',
--     `category3_name`       , --STRING COMMENT '三级品类名称',
--     `category2_id`         , --STRING COMMENT '二级品类id',
--     `category2_name`       , --STRING COMMENT '二级品类名称',
--     `category1_id`         , --STRING COMMENT '一级品类ID',
--     `category1_name`       , --STRING COMMENT '一级品类名称',
    `tm_id`                , --  STRING COMMENT '品牌ID',
    --`tm_name`              -- STRING COMMENT '品牌名称',
    create_time
    from ods_sku_info_full
    where dt = '2022-06-08'
) as sku
left join (
    select
        id,
        spu_name
    from ods_spu_info_full
    where dt = '2022-06-08'
) as spu on sku.spu_id = spu.id
left join (
    select
        id,
        name category3_name,
        category2_id
    from ods_base_category3_full
    where dt = '2022-06-08'
) as c3 on sku.category3_id = c3.id
left join (
    select
        id,
        name category2_name,
        category1_id
    from ods_base_category2_full
    where dt = '2022-06-08'
) as c2 on c3.category2_id = c2.id
left join (
    select
        id,
        name category1_name
    from ods_base_category1_full
    where dt = '2022-06-08'
) as c1 on c2.category1_id = c1.id
left join (
    select
        id,
        tm_name
    from ods_base_trademark_full
    where dt = '2022-06-08'
) as tm on sku.tm_id = tm.id
left join (
    -- 查询商品平台属性,一个商品可能对应多个平台属性，将一个商品的多个平台属性聚合成 array<struct>
    select
        sku_id,
        collect_list(named_struct("attr_id",attr_id,"value_id",value_id,"attr_name",attr_name,"value_name",value_name)) as sku_attr_values
    from ods_sku_attr_value_full
    where dt = '2022-06-08'
    group by sku_id
) as attrs on sku.id = attrs.sku_id
left join (
    -- 查询商品的销售属性，一个商品可能对应多个销售属性，将一个商品的多个销售属性聚合成 array<struct>
    select
        sku_id,
        collect_list(named_struct("sale_attr_id",sale_attr_id,"sale_attr_value_id",sale_attr_value_id,"sale_attr_name",sale_attr_name,"sale_attr_value_name",sale_attr_value_name)) as sku_sale_attr_values
    from ods_sku_sale_attr_value_full
    where dt = '2022-06-08'
    group by sku_id
) as sale on sale.sku_id = sku.id;








--- TODO 优惠卷维度表
-- 建表
    -- 在初始的ods_coupon_full表中只有优惠卷类型编码和优惠卷范围编码，没有优惠券类型名称和优惠券范围名称
    -- 需要去字典表(ods_base_dic_full)中查询编码和名称的关系，在维度表中编码和名称共存
    -- 关于优惠规则需要根据优惠卷类型编写，例如：满100减10，满3件打9.5折
DROP TABLE IF EXISTS dim_coupon_full;
CREATE EXTERNAL TABLE dim_coupon_full
(
    `id`                  STRING COMMENT '优惠券编号',
    `coupon_name`       STRING COMMENT '优惠券名称',
    `coupon_type_code` STRING COMMENT '优惠券类型编码',
    `coupon_type_name` STRING COMMENT '优惠券类型名称',
    `condition_amount` DECIMAL(16, 2) COMMENT '满额数',
    `condition_num`     BIGINT COMMENT '满件数',
    `activity_id`       STRING COMMENT '活动编号',
    `benefit_amount`   DECIMAL(16, 2) COMMENT '减免金额',
    `benefit_discount` DECIMAL(16, 2) COMMENT '折扣',
    `benefit_rule`     STRING COMMENT '优惠规则:满元*减*元，满*件打*折',
    `create_time`       STRING COMMENT '创建时间',
    `range_type_code`  STRING COMMENT '优惠范围类型编码',
    `range_type_name`  STRING COMMENT '优惠范围类型名称',
    `limit_num`         BIGINT COMMENT '最多领取次数',
    `taken_count`       BIGINT COMMENT '已领取次数',
    `start_time`        STRING COMMENT '可以领取的开始时间',
    `end_time`          STRING COMMENT '可以领取的结束时间',
    `operate_time`      STRING COMMENT '修改时间',
    `expire_time`       STRING COMMENT '过期时间'
) COMMENT '优惠券维度表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dim/dim_coupon_full/'
    TBLPROPERTIES ('orc.compress' = 'snappy');

-- 装载数据
    -- 1,查询出维度表所需要的数据
    -- 2,将数据装载到表中
insert overwrite table dim_coupon_full partition(dt = '2022-06-08')
select
    `id`               ,--   STRING COMMENT '优惠券编号',
    `coupon_name`      ,-- STRING COMMENT '优惠券名称',
    `coupon_type_code` ,--STRING COMMENT '优惠券类型编码',
    `coupon_type_name` ,--STRING COMMENT '优惠券类型名称',
    `condition_amount` ,--DECIMAL(16, 2) COMMENT '满额数',
    `condition_num`    ,-- BIGINT COMMENT '满件数',
    `activity_id`      ,-- STRING COMMENT '活动编号',
    `benefit_amount`   ,--DECIMAL(16, 2) COMMENT '减免金额',
    `benefit_discount` ,--DECIMAL(16, 2) COMMENT '折扣',
    case coupon_type_code
        when 3201 then concat('满',condition_amount,'元减',benefit_amount,'元')
        when 3202 then concat('满',condition_num,'件打',benefit_discount,'折')
        when 3203 then concat('无门槛减',benefit_amount,'元')
    end `benefit_rule`     ,--STRING COMMENT '优惠规则:满元*减*元，满*件打*折',
    `create_time`      ,-- STRING COMMENT '创建时间',
    `range_type_code`  ,--STRING COMMENT '优惠范围类型编码',
    `range_type_name`  ,--STRING COMMENT '优惠范围类型名称',
    `limit_num`        ,-- BIGINT COMMENT '最多领取次数',
    `taken_count`      ,-- BIGINT COMMENT '已领取次数',
    `start_time`       ,-- STRING COMMENT '可以领取的开始时间',
    `end_time`         ,-- STRING COMMENT '可以领取的结束时间',
    `operate_time`     ,-- STRING COMMENT '修改时间',
    `expire_time`      -- STRING COMMENT '过期时间'
from(
    select
        `id`           ,--       STRING COMMENT '优惠券编号',
    `coupon_name`      ,-- STRING COMMENT '优惠券名称',
    coupon_type `coupon_type_code` ,--STRING COMMENT '优惠券类型编码',
    --`coupon_type_name` ,--STRING COMMENT '优惠券类型名称',
    `condition_amount` ,--DECIMAL(16, 2) COMMENT '满额数',
    `condition_num`    ,-- BIGINT COMMENT '满件数',
    `activity_id`      ,-- STRING COMMENT '活动编号',
    `benefit_amount`   ,--DECIMAL(16, 2) COMMENT '减免金额',
    `benefit_discount` ,--DECIMAL(16, 2) COMMENT '折扣',
    --`benefit_rule`     ,--STRING COMMENT '优惠规则:满元*减*元，满*件打*折',
    `create_time`      ,-- STRING COMMENT '创建时间',
    range_type `range_type_code`  ,--STRING COMMENT '优惠范围类型编码',
    --`range_type_name`  ,--STRING COMMENT '优惠范围类型名称',
    `limit_num`        ,-- BIGINT COMMENT '最多领取次数',
    `taken_count`      ,-- BIGINT COMMENT '已领取次数',
    `start_time`       ,-- STRING COMMENT '可以领取的开始时间',
    `end_time`         ,-- STRING COMMENT '可以领取的结束时间',
    `operate_time`     ,-- STRING COMMENT '修改时间',
    `expire_time`      -- STRING COMMENT '过期时间'
from ods_coupon_info_full
where dt = '2022-06-08'
) as coupon
left join (
    select
        dic_code,
        dic_name as coupon_type_name
    from ods_base_dic_full
    where dt = '2022-06-08'
    and parent_code = '32'   -- 优化,过滤出不需要的数据,减少join关联的数据量
) as dic1 on dic1.dic_code = coupon.coupon_type_code
left join (
    select
        dic_code,
        dic_name as range_type_name
    from ods_base_dic_full
    where dt = '2022-06-08'
    and parent_code = '33'   -- 优化,过滤出不需要的数据,减少join关联的数据量
) as dic2 on dic2.dic_code = coupon.range_type_code;






--- TODO 活动维度表
    -- 活动相关的表
        -- activity_rule 活动规则表
        -- activity_sku  活动商品关联表  (不需要,关联表不应该作为维度进行分析)
        -- activity_info 活动信息表
    -- 主维表：
        -- activity_rule,因为我们主要开活动的优惠力度来购买商品
    -- 相关维表
        -- activity_info 活动信息表

-- 建表
DROP TABLE IF EXISTS dim_activity_full;
CREATE EXTERNAL TABLE dim_activity_full
(
    `activity_rule_id`   STRING COMMENT '活动规则ID',
    `activity_id`         STRING COMMENT '活动ID',
    `activity_name`       STRING COMMENT '活动名称',
    `activity_type_code` STRING COMMENT '活动类型编码',
    `activity_type_name` STRING COMMENT '活动类型名称',
    `activity_desc`       STRING COMMENT '活动描述',
    `start_time`           STRING COMMENT '开始时间',
    `end_time`             STRING COMMENT '结束时间',
    `create_time`          STRING COMMENT '创建时间',
    `condition_amount`    DECIMAL(16, 2) COMMENT '满减金额',
    `condition_num`       BIGINT COMMENT '满减件数',
    `benefit_amount`      DECIMAL(16, 2) COMMENT '优惠金额',
    `benefit_discount`   DECIMAL(16, 2) COMMENT '优惠折扣',
    `benefit_rule`        STRING COMMENT '优惠规则',
    `benefit_level`       STRING COMMENT '优惠级别'
) COMMENT '活动维度表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dim/dim_activity_full/'
    TBLPROPERTIES ('orc.compress' = 'snappy');


-- 装载数据
insert overwrite table dim_activity_full partition(dt='2022-06-08')
select
    `activity_rule_id`  ,-- STRING COMMENT '活动规则ID',
    `activity_id`       ,--  STRING COMMENT '活动ID',
    `activity_name`     ,--  STRING COMMENT '活动名称',
    `activity_type_code`,-- STRING COMMENT '活动类型编码',
    `activity_type_name`,-- STRING COMMENT '活动类型名称',
    `activity_desc`     ,--  STRING COMMENT '活动描述',
    `start_time`        ,--   STRING COMMENT '开始时间',
    `end_time`          ,--   STRING COMMENT '结束时间',
    `create_time`       ,--   STRING COMMENT '创建时间',
    `condition_amount`  ,--  DECIMAL(16, 2) COMMENT '满减金额',
    `condition_num`     ,--  BIGINT COMMENT '满减件数',
    `benefit_amount`    ,--  DECIMAL(16, 2) COMMENT '优惠金额',
    `benefit_discount`  ,-- DECIMAL(16, 2) COMMENT '优惠折扣',
    `benefit_rule`      ,--  STRING COMMENT '优惠规则',
    `benefit_level`     --  STRING COMMENT '优惠级别'
from(
    select
        id `activity_rule_id`   ,--STRING COMMENT '活动规则ID',
        `activity_id`        ,-- STRING COMMENT '活动ID',
        -- `activity_name`      ,-- STRING COMMENT '活动名称',
        activity_type `activity_type_code` ,--STRING COMMENT '活动类型编码',
        -- `activity_type_name` ,--STRING COMMENT '活动类型名称',
        -- `activity_desc`      ,-- STRING COMMENT '活动描述',
        -- `start_time`         ,--  STRING COMMENT '开始时间',
        -- `end_time`           ,--  STRING COMMENT '结束时间',
        `create_time`        ,--  STRING COMMENT '创建时间',
        `condition_amount`   ,-- DECIMAL(16, 2) COMMENT '满减金额',
        `condition_num`      ,-- BIGINT COMMENT '满减件数',
        `benefit_amount`     ,-- DECIMAL(16, 2) COMMENT '优惠金额',
        `benefit_discount`   ,--DECIMAL(16, 2) COMMENT '优惠折扣',
        case activity_type
            when '3101' then concat("满",condition_amount,"元减",benefit_amount,"元")
            when '3102' then concat("满",condition_num,"件打",benefit_discount,"折")
            when '3103' then concat("无门槛打",benefit_discount,"折")
        end `benefit_rule`       ,-- STRING COMMENT '优惠规则',
        `benefit_level`      -- STRING COMMENT '优惠级别'
    from ods_activity_rule_full
    where dt = '2022-06-08'
) as rule
left join (
    select
        id,
        activity_name,
        activity_desc,
        start_time,
        end_time
    from ods_activity_info_full
    where dt = '2022-06-08'
)as info on rule.activity_id = info.id
left join (
    select
        dic_code,
        dic_name as activity_type_name
    from ods_base_dic_full
    where dt = '2022-06-08'
    and parent_code = '31'  -- 活动类型，过滤出不需要的数据，减少join数据量
) as dic on rule.activity_type_code = dic.dic_code;













--- TODO 省份维度表
    -- 主维表：ods_base_province_full  省份表
    -- 相关维表：ods_base_region_full    地区表

-- 建表
DROP TABLE IF EXISTS dim_province_full;
CREATE EXTERNAL TABLE dim_province_full
(
    `id`              STRING COMMENT '省份ID',
    `province_name` STRING COMMENT '省份名称',
    `area_code`     STRING COMMENT '地区编码',
    `iso_code`      STRING COMMENT '旧版国际标准地区编码，供可视化使用',
    `iso_3166_2`    STRING COMMENT '新版国际标准地区编码，供可视化使用',
    `region_id`     STRING COMMENT '地区ID',
    `region_name`   STRING COMMENT '地区名称'
) COMMENT '地区维度表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dim/dim_province_full/'
    TBLPROPERTIES ('orc.compress' = 'snappy');

-- 装载数据
insert overwrite table dim_province_full partition(dt='2022-06-08')
select
    prv.`id`            ,--  STRING COMMENT '省份ID',
    `province_name` ,--STRING COMMENT '省份名称',
    `area_code`     ,--STRING COMMENT '地区编码',
    `iso_code`      ,--STRING COMMENT '旧版国际标准地区编码，供可视化使用',
    `iso_3166_2`    ,--STRING COMMENT '新版国际标准地区编码，供可视化使用',
    `region_id`     ,--STRING COMMENT '地区ID',
    `region_name`   --STRING COMMENT '地区名称'
from(
    select
        `id`        ,--      STRING COMMENT '省份ID',
    name `province_name` ,--STRING COMMENT '省份名称',
    `area_code`     ,--STRING COMMENT '地区编码',
    `iso_code`      ,--STRING COMMENT '旧版国际标准地区编码，供可视化使用',
    `iso_3166_2`    ,--STRING COMMENT '新版国际标准地区编码，供可视化使用',
    `region_id`     --STRING COMMENT '地区ID',
    -- `region_name`   --STRING COMMENT '地区名称'
    from ods_base_province_full
    where dt="2022-06-08"
) as prv
left join (
    select
        id,
        region_name
    from ods_base_region_full
    where dt="2022-06-08"
)as region on prv.region_id = region.id;




--- TODO 营销坑位维度表(营销坑位: 商品放置的位置)
-- 建表
DROP TABLE IF EXISTS dim_promotion_pos_full;
CREATE EXTERNAL TABLE dim_promotion_pos_full
(
    `id`                 STRING COMMENT '营销坑位ID',
    `pos_location`     STRING COMMENT '营销坑位位置',
    `pos_type`          STRING COMMENT '营销坑位类型 ',
    `promotion_type`   STRING COMMENT '营销类型',
    `create_time`       STRING COMMENT '创建时间',
    `operate_time`      STRING COMMENT '修改时间'
) COMMENT '营销坑位维度表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dim/dim_promotion_pos_full/'
    TBLPROPERTIES ('orc.compress' = 'snappy');


-- 装载数据
insert overwrite table dim_promotion_pos_full partition(dt='2022-06-08')
select
    `id`,
    `pos_location`,
    `pos_type`,
    `promotion_type`,
    `create_time`,
    `operate_time`
from ods_promotion_pos_full
where dt='2022-06-08';



--- TODO 销售渠道表
-- 建表
DROP TABLE IF EXISTS dim_promotion_refer_full;
CREATE EXTERNAL TABLE dim_promotion_refer_full
(
    `id`                    STRING COMMENT '营销渠道ID',
    `refer_name`          STRING COMMENT '营销渠道名称',
    `create_time`         STRING COMMENT '创建时间',
    `operate_time`        STRING COMMENT '修改时间'
) COMMENT '营销渠道维度表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dim/dim_promotion_refer_full/'
    TBLPROPERTIES ('orc.compress' = 'snappy');

-- 装载数据
insert overwrite table dim_promotion_refer_full partition(dt='2022-06-08')
select
    `id`,
    `refer_name`,
    `create_time`,
    `operate_time`
from ods_promotion_refer_full
where dt='2022-06-08';





--- TODO 日期维度表
-- 建表
    -- 日期维度表没有full后缀，因为一年中的日期是固定的
    -- 日期维度表没有分区，因为按日期分区，一个分区就条数据，没必要分。就算是十年的数据最多也就3650条数据，在大数据场景中，算是小数据集。
DROP TABLE IF EXISTS dim_date;
CREATE EXTERNAL TABLE dim_date
(
    `date_id`    STRING COMMENT '日期ID',
    `week_id`    STRING COMMENT '周ID,一年中的第几周',
    `week_day`   STRING COMMENT '周几',
    `day`         STRING COMMENT '每月的第几天',
    `month`       STRING COMMENT '一年中的第几月',
    `quarter`    STRING COMMENT '一年中的第几季度',
    `year`        STRING COMMENT '年份',
    `is_workday` STRING COMMENT '是否是工作日',
    `holiday_id` STRING COMMENT '节假日'
) COMMENT '日期维度表'
    STORED AS ORC
    LOCATION '/warehouse/gmall/dim/dim_date/'
    TBLPROPERTIES ('orc.compress' = 'snappy');

-- 装载数据
    -- 注意：日期数据不存在业务系统中，日期有可预见性，国家每年都会发布下一年的日期安排表
    -- 但是，国家发布的格式一般是tsv格式或者csv格式，所以我们需要将格式转化为orc格式
    -- 创建一张临时表，用于存储行式数据，读取到临时表中，在内存中转化为orc格式写入dim_date维度表
-- 1.创建临时表
DROP TABLE IF EXISTS tmp_dim_date_info;
CREATE EXTERNAL TABLE tmp_dim_date_info (
    `date_id`       STRING COMMENT '日',
    `week_id`       STRING COMMENT '周ID',
    `week_day`      STRING COMMENT '周几',
    `day`            STRING COMMENT '每月的第几天',
    `month`          STRING COMMENT '第几月',
    `quarter`       STRING COMMENT '第几季度',
    `year`           STRING COMMENT '年',
    `is_workday`    STRING COMMENT '是否是工作日',
    `holiday_id`    STRING COMMENT '节假日'
) COMMENT '时间维度表'
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
LOCATION '/warehouse/gmall/tmp/tmp_dim_date_info/';
-- 2.将日期tsv文件放在"/warehouse/gmall/tmp/tmp_dim_date_info/"HDFS路径下
-- 3.将数据查询出来插入到dim_date维度表
insert overwrite table dim_date select * from tmp_dim_date_info;







--- TODO 用户维度表(重难点)
    -- 难点
        -- 用户表的数据量巨大，如果每天做一次全量,资源不够,所以采用zip(拉链表/压缩表)
        -- 拉链表,记录用户的信息，并且增加了两个字段-> start_date,end_date: 用来表示用户这个状态生命周期
            -- 例如: 1001 小明 111(电话) 2022-06-13 2024-12-13 -> 表示1001这个用户的这状态的生命周期为2022-06-13到2024-12-13,后续的状态可能发生改变
            -- 1001 小明 111(电话) 2025-01-01 9999-12-31 -> 1001用户的状态情况，从2025-01-01至今都是这个状态
-- 建表
DROP TABLE IF EXISTS dim_user_zip;
CREATE EXTERNAL TABLE dim_user_zip
(
    `id`           STRING COMMENT '用户ID',
    `name`         STRING COMMENT '用户姓名',
    `phone_num`    STRING COMMENT '手机号码',
    `email`        STRING COMMENT '邮箱',
    `user_level`   STRING COMMENT '用户等级',
    `birthday`     STRING COMMENT '生日',
    `gender`       STRING COMMENT '性别',
    `create_time`  STRING COMMENT '创建时间',
    `operate_time` STRING COMMENT '操作时间',
    `start_date`   STRING COMMENT '开始日期',       -- 这个字段没有,是我们自己维护的一个字段
    `end_date`     STRING COMMENT '结束日期'        -- 这个字段没有,是我们自己维护的一个字段
) COMMENT '用户维度表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dim/dim_user_zip/'
    TBLPROPERTIES ('orc.compress' = 'snappy');


-- 装载数据
    -- 难点
        -- ods_user_info_inc 是一张增量表,所以需要区分首日全量和每天增量
            -- 全量
                -- 将所有用户的信息统计之后按照end_date时间进行分区,如果按照start_date时间进行分区取到的数据不准确
                    -- 例如按照start_date取数据
                        -- 第一条 1001 ...(用户信息) 2022-06-08 2025-10-10 -> 这是一个历史数据
                        -- 第二条 1002 ...(用户信息) 2022-06-08 9999-12-31 -> 这是现在这个用户的数据,需要过滤筛选
                -- 第一次全量的时候，由于业务数据库(MySQL)不存历史数据，所以用户的数据都是最新状态，所以我们第一次全量的时候认为用户状态的起始时间就是第一次全量的时间

            -- 增量
                -- 采集用户表每一天的变化状态(insert,update,没有delete,不会物理意义删除数据)
                    -- insert: 新增数据 -> 状态起始时间(当前时间的前一天,因为我们的操作都是在数据发生之后的第二天做的分析),结束时间(9999-12-31)
                    -- update: 修改数据
                        -- old(之前的状态): 对于用户的前一个状态，我们要修改前一个状态的结束时间(修改为当前时间的前一天),按照结束时间存储到别的分区中,
                            -- 9999-12-31这个分区是存储现在状态的分区
                        -- new(新的状态): 跟新增数据一样
                    -- 注意点: 如果一个用户在用一天内发生的多次状态修改,我们按照最后一次为准,由于我们的采集是每天进行一次,对于同一天内之前的状态对我们来说没有用
                        -- 例如，一天内,一个用户修改了多次地址,但是我们是按天进行分析的,同一天内之前的状态对我们来说使用不到,我们的分析是一天为单位的,
                            -- 如果说以后我们的采集是每个小时进行一次,那么一天内修改多次的数据才对我们有用
        -- 增量表的数据格式是json格式,所以我们采集数据到ods层的时候是按照json的格式进行解析的,所以查询的ods_user_info_inc的时候,数据在data结构体中


-- 首日全量(类型 type:bootstrap-insert)
insert overwrite table dim_user_zip partition (dt="2022-06-08")
select
    data.`id`          ,-- STRING COMMENT '用户ID',
    data.`name`        ,-- STRING COMMENT '用户姓名',
    data.`phone_num`   ,-- STRING COMMENT '手机号码',
    data.`email`       ,-- STRING COMMENT '邮箱',
    data.`user_level`  ,-- STRING COMMENT '用户等级',
    data.`birthday`    ,-- STRING COMMENT '生日',
    data.`gender`      ,-- STRING COMMENT '性别',
    data.`create_time` ,-- STRING COMMENT '创建时间',
    data.`operate_time`,-- STRING COMMENT '操作时间',
    "2022-06-08" `start_date`  ,-- STRING COMMENT '开始日期',       -- 这个字段没有,是我们自己维护的一个字段
    "9999-12-31" `end_date`    -- STRING COMMENT '结束日期'        -- 这个字段没有,是我们自己维护的一个字段
from ods_user_info_inc
where dt = "2022-06-08"
and type = "bootstrap-insert";


-- 每天增量
    -- 假设是在2022-06-10 做的每日增量同步
        -- 步骤一：查询到前一天采集的数据与用户最新的状态数据进行比对，看看是否用户的状态发生了变化，如果发生的变化修改前一个状态的结束时间
insert overwrite table dim_user_zip partition (dt)
select
    `id`           ,--STRING COMMENT '用户ID',
    `name`         ,--STRING COMMENT '用户姓名',
    `phone_num`    ,--STRING COMMENT '手机号码',
    `email`        ,--STRING COMMENT '邮箱',
    `user_level`   ,--STRING COMMENT '用户等级',
    `birthday`     ,--STRING COMMENT '生日',
    `gender`       ,--STRING COMMENT '性别',
    `create_time`  ,--STRING COMMENT '创建时间',
    `operate_time` ,--STRING COMMENT '操作时间',
    `start_date`   ,--STRING COMMENT '开始日期',
    `if`(rn = 1, "9999-12-31", date_sub("2022-06-09",1))`end_date`    , --STRING COMMENT '结束日期'
    `if`(rn = 1, "9999-12-31", date_sub("2022-06-09",1))
from(
        select
            `id`           ,--STRING COMMENT '用户ID',
            `name`         ,--STRING COMMENT '用户姓名',
            `phone_num`    ,--STRING COMMENT '手机号码',
            `email`        ,--STRING COMMENT '邮箱',
            `user_level`   ,--STRING COMMENT '用户等级',
            `birthday`     ,--STRING COMMENT '生日',
            `gender`       ,--STRING COMMENT '性别',
            `create_time`  ,--STRING COMMENT '创建时间',
            `operate_time` ,--STRING COMMENT '操作时间',
            `start_date`   ,--STRING COMMENT '开始日期',
            `end_date`     ,--STRING COMMENT '结束日期'
            -- 排名为2的数据表示有同一用户的数据，并且开始时间是之前的
            row_number() over (partition by id order by start_date desc ) rn
        from(
                select
                    `id`           ,--STRING COMMENT '用户ID',
                    `name`         ,--STRING COMMENT '用户姓名',
                    `phone_num`    ,--STRING COMMENT '手机号码',
                    `email`        ,--STRING COMMENT '邮箱',
                    `user_level`   ,--STRING COMMENT '用户等级',
                    `birthday`     ,--STRING COMMENT '生日',
                    `gender`       ,--STRING COMMENT '性别',
                    `create_time`  ,--STRING COMMENT '创建时间',
                    `operate_time` ,--STRING COMMENT '操作时间',
                    `start_date`   ,--STRING COMMENT '开始日期',
                    `end_date`     --STRING COMMENT '结束日期'
                from dim_user_zip
                where dt = "9999-12-31" -- 之前的数据
                    union   -- 注意,这里只能使用union,(不能使用)union all会将所有行的数据(包含)都合并在一块,如果进行的重试(分布式),会导致数据重复
                select
                    `id`           ,--STRING COMMENT '用户ID',
                    `name`         ,--STRING COMMENT '用户姓名',
                    `phone_num`    ,--STRING COMMENT '手机号码',
                    `email`        ,--STRING COMMENT '邮箱',
                    `user_level`   ,--STRING COMMENT '用户等级',
                    `birthday`     ,--STRING COMMENT '生日',
                    `gender`       ,--STRING COMMENT '性别',
                    `create_time`  ,--STRING COMMENT '创建时间',
                    `operate_time` ,--STRING COMMENT '操作时间',
                    "2022-06-09" `start_date`  ,-- STRING COMMENT '开始日期',
                    "9999-12-31" `end_date`    -- STRING COMMENT '结束日期'
                from (
                        select
                            data.`id`          ,-- STRING COMMENT '用户ID',
                            data.`name`        ,-- STRING COMMENT '用户姓名',
                            data.`phone_num`   ,-- STRING COMMENT '手机号码',
                            data.`email`       ,-- STRING COMMENT '邮箱',
                            data.`user_level`  ,-- STRING COMMENT '用户等级',
                            data.`birthday`    ,-- STRING COMMENT '生日',
                            data.`gender`      ,-- STRING COMMENT '性别',
                            data.`create_time` ,-- STRING COMMENT '创建时间',
                            data.`operate_time`,-- STRING COMMENT '操作时间',
                            row_number() over (partition by data.id order by ts desc ) rn
                        from ods_user_info_inc
                        where dt = "2022-06-09"    -- 今天过来的数据
                )tmp
                where tmp.rn = 1
        ) t1
)t2;


