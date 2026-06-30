-- DWD层(Data Warehouse Detail: 数据明细层)
    -- 事实表(记录业务过程的客观事件)
        -- 核心组成：维度外键 + 度量值(可数值化统计的指标)
    -- 数据格式
        -- orc: 列式存储,便于统计分析
        -- snappy: 压缩格式,看重压缩速度,提高计算效率
    -- 事实表分类
        -- 事务性事实表(Transaction Fact Table)
            -- 特点：记录每个业务事件,粒度最细,实时插入,不可变
            -- 适用场景：订单明细、支付流水、浏览日志
            -- 设计步骤：
                -- ① 选择业务过程  -> 确定表(下单/支付/退款...)
                -- ② 声明粒度     -> 确定行(每行代表什么,如：订单中的每个商品项)
                -- ③ 确认维度     -> 确定列(时间/用户/商品/地区/渠道等多维度)
                -- ④ 确认事实     -> 确定度量值(数量/金额/次数等可累加数值)

        -- 周期快照事实表(Periodic Snapshot Fact Table)
            -- 特点：按固定时间间隔汇总,记录某时刻的状态
            -- 适用场景：每日销售汇总、每月库存余额、用户每日活跃统计
            -- 设计要点：
                -- ① 确定快照周期(天/周/月)
                -- ② 确定汇总维度(按商品/按地区/按用户)
                -- ③ 确定累积度量(累计销售额/累计访问量)
            -- 示例：
                -- fact_daily_sales_snapshot(每日销售快照)
                --   分区字段：stat_date(统计日期)
                --   维度：product_id, region_id
                --   度量：daily_total_amount(当日总额), daily_order_count(当日订单数)

        -- 累积快照事实表(Accumulating Snapshot Fact Table)
            -- 特点：跟踪业务流程的多个关键节点,一行数据会多次更新
            -- 适用场景：订单生命周期(下单→支付→发货→签收)、贷款申请流程
            -- 设计要点：
                -- ① 识别业务流程的关键里程碑
                -- ② 为每个里程碑设置时间字段
                -- ③ 计算相邻节点的时间间隔(时效分析)
            -- 示例：
                -- fact_order_accumulating(订单累积快照)
                --   维度：order_id, user_id, product_id
                --   时间字段：order_time, pay_time, ship_time, receive_time
                --   度量：total_amount, order_to_pay_interval(下单到支付时长)



--- TODO 交易域加购事务事实表
    /*
     数据域	业务过程
     交易域	加购、下单、取消订单、支付成功、退单、退款成功
     流量域	页面浏览、启动应用、动作、曝光、错误
     用户域	注册、登录
     互动域	收藏、评价
     工具域	优惠券领取、优惠券使用（下单）、优惠券使用（支付）
        数据域是对业务进行分类管理
     */
-- 建表
DROP TABLE IF EXISTS dwd_trade_cart_add_inc;
CREATE EXTERNAL TABLE dwd_trade_cart_add_inc
(
    `id`                  STRING COMMENT '编号',
    `user_id`            STRING COMMENT '用户ID',
    `sku_id`             STRING COMMENT 'SKU_ID',
    `date_id`            STRING COMMENT '日期ID',     -- 年月日
    `create_time`        STRING COMMENT '加购时间',     -- 时分秒
    `sku_num`            BIGINT COMMENT '加购物车件数'
) COMMENT '交易域加购事务事实表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_trade_cart_add_inc/'
    TBLPROPERTIES ('orc.compress' = 'snappy');


-- 装载数据
    -- 对接的数据源：ods_cart_info_inc 有首日全量,和每日增量数据

-- 首日数据装载
    -- 业务数据库中只保存了购物车表的最终结果状态，数据仓库又是第一次启动，没有之前的历史数据
        -- 所以认为第一次都是加购的行为
    -- 分区策略,哪一天加购的数据放在哪一个分区中,采用动态分区,业务数据库不只存在一天的数据
set hive.exec.dynamic.partition.mode=nonstrict;
insert overwrite table dwd_trade_cart_add_inc partition(dt)
select
    data.`id`               ,--   STRING COMMENT '编号',
    data.`user_id`          ,--  STRING COMMENT '用户ID',
    data.`sku_id`           ,--  STRING COMMENT 'SKU_ID',
    date_format(data.`create_time`,"yyyy-MM-dd") `date_id`,  -- STRING COMMENT '日期ID'
    data.`create_time`      ,--  STRING COMMENT '加购时间',
    data.`sku_num`          ,--  BIGINT COMMENT '加购物车件数'
    date_format(data.`create_time`,"yyyy-MM-dd")
from ods_cart_info_inc
where dt="2022-06-08"
and type = 'bootstrap-insert';     -- 首日新增数据


-- 每日装载数据
    -- 新增的数据 -> 加购行为
    -- 修改的数据 -> 如果商品数量发现了改变，并且是增加 -> 加购行为
insert overwrite table dwd_trade_cart_add_inc partition(dt="2022-06-09")
select
    data.`id`               ,--   STRING COMMENT '编号',
    data.`user_id`          ,--  STRING COMMENT '用户ID',
    data.`sku_id`           ,--  STRING COMMENT 'SKU_ID',
    date_format(if(type = "insert",data.`create_time`,data.operate_time) ,"yyyy-MM-dd") `date_id`,   -- STRING COMMENT '日期ID'
    if(type = "insert",data.`create_time`,data.operate_time) create_time    ,--  STRING COMMENT '加购时间',
    if(type = "insert", data.`sku_num`, data.sku_num - old["sku_num"])    sku_num    --  BIGINT COMMENT '加购物车件数'
from ods_cart_info_inc
where dt="2022-06-09"
and type = 'insert'     -- 新增 -> 加购
or (
    -- 修改，商品数量变多了 -> 加购
    type = "update"
        and
    array_contains(map_keys(old), 'sku_num')
        and
    data.sku_num > cast(old["sku_num"] as bigint)
    );








--- TODO 交易域下单事务事实表
-- 建表
DROP TABLE IF EXISTS dwd_trade_order_detail_inc;
CREATE EXTERNAL TABLE dwd_trade_order_detail_inc
(
    `id`                     STRING COMMENT '编号',
    `order_id`              STRING COMMENT '订单ID',
    `user_id`               STRING COMMENT '用户ID',
    `sku_id`                STRING COMMENT '商品ID',
    `province_id`          STRING COMMENT '省份ID',
    `activity_id`          STRING COMMENT '参与活动ID',
    `activity_rule_id`    STRING COMMENT '参与活动规则ID',
    `coupon_id`             STRING COMMENT '使用优惠券ID',
    `date_id`               STRING COMMENT '下单日期ID',
    `create_time`           STRING COMMENT '下单时间',
    `sku_num`                BIGINT COMMENT '商品数量',
    `split_original_amount` DECIMAL(16, 2) COMMENT '原始价格',
    `split_activity_amount` DECIMAL(16, 2) COMMENT '活动优惠分摊',
    `split_coupon_amount`   DECIMAL(16, 2) COMMENT '优惠券优惠分摊',
    `split_total_amount`    DECIMAL(16, 2) COMMENT '最终价格分摊'
) COMMENT '交易域下单事务事实表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_trade_order_detail_inc/'
    TBLPROPERTIES ('orc.compress' = 'snappy');


-- 装载数据
    -- 下单行为会导致业务数据库中的订单表、订单明细表、订单明细优惠卷关联表、订单明细活动关联表的数据发生改变(insert)
    -- 根据订单明细表，订单表，订单明细优惠卷关联表，订单明细活动关联表 进行关联推断出用户的行为
-- 首日数据装载
    -- 分区策略: 动态分区,业务数据库中订单相关的表不止保存一天的数据，ods层第一次采集的时候会采集业务数据库的所有数据
        -- 我们需要根据不懂的日期放到不同的分区中
set hive.exec.dynamic.partition.mode=nonstrict;
insert overwrite table dwd_trade_order_detail_inc partition(dt)
select
    od.`id`                   ,--  STRING COMMENT '编号',
    `order_id`             ,-- STRING COMMENT '订单ID',
    `user_id`              ,-- STRING COMMENT '用户ID',
    `sku_id`               ,-- STRING COMMENT '商品ID',
    `province_id`          ,--STRING COMMENT '省份ID',
    `activity_id`          ,--STRING COMMENT '参与活动ID',
    `activity_rule_id`     ,--STRING COMMENT '参与活动规则ID',
    `coupon_id`            ,-- STRING COMMENT '使用优惠券ID',
    `date_id`              ,-- STRING COMMENT '下单日期ID',
    `create_time`          ,-- STRING COMMENT '下单时间',
    `sku_num`              ,--  BIGINT COMMENT '商品数量',
    `split_original_amount`,-- DECIMAL(16, 2) COMMENT '原始价格',
    `split_activity_amount`,-- DECIMAL(16, 2) COMMENT '活动优惠分摊',
    `split_coupon_amount`  ,-- DECIMAL(16, 2) COMMENT '优惠券优惠分摊',
    `split_total_amount`   ,-- DECIMAL(16, 2) COMMENT '最终价格分摊'
    date_id
from(
        select
            data.`id`                   ,--  STRING COMMENT '编号',
            data.`order_id`             ,-- STRING COMMENT '订单ID',
            data.`sku_id`               ,-- STRING COMMENT '商品ID',
            data.`sku_num`              ,--  BIGINT COMMENT '商品数量',
            data.order_price * data.`sku_num` as split_original_amount ,-- DECIMAL(16, 2) COMMENT '原始价格',
            nvl(data.`split_activity_amount`,0.0) split_activity_amount,-- DECIMAL(16, 2) COMMENT '活动优惠分摊',
            nvl(data.`split_coupon_amount`,0.0) split_coupon_amount ,-- DECIMAL(16, 2) COMMENT '优惠券优惠分摊',
            data.`split_total_amount`   -- DECIMAL(16, 2) COMMENT '最终价格分摊'
        from ods_order_detail_inc   -- 订单明细表
        where dt = "2022-06-08" and type = 'bootstrap-insert'
    ) od
left join (
        select
            data.id,
            data.`user_id`              ,-- STRING COMMENT '用户ID',
            data.`province_id`          ,--STRING COMMENT '省份ID',
            date_format(data.`create_time`,"yyyy-MM-dd") `date_id`              ,-- STRING COMMENT '下单日期ID',
            data.`create_time`          -- STRING COMMENT '下单时间',
        from ods_order_info_inc     -- 订单表
        where dt = "2022-06-08" and type = 'bootstrap-insert'
    ) oi on od.order_id = oi.id
left join (
        select
            data.order_detail_id,
            data.`coupon_id`            -- STRING COMMENT '使用优惠券ID',
        from ods_order_detail_coupon_inc  -- 订单明细优惠卷关联表
        where dt = "2022-06-08" and type = 'bootstrap-insert'
    ) coupon on od.id = coupon.order_detail_id
left join (
        select
            data.order_detail_id,
            data.`activity_id`          ,--STRING COMMENT '参与活动ID',
            data.`activity_rule_id`     -- STRING COMMENT '参与活动规则ID',
        from ods_order_detail_activity_inc -- 订单明细活动关联表
        where dt = "2022-06-08" and type = 'bootstrap-insert'
    ) act on od.id = act.order_detail_id;



-- 每日数据装载
    -- 每天采集一次到ods层中，只有新增的数据(可能有update的表就是订单表,但是不算下单)，不需要要额外的处理
insert overwrite table dwd_trade_order_detail_inc partition(dt="2022-06-09")
select
    od.`id`                   ,--  STRING COMMENT '编号',
    `order_id`             ,-- STRING COMMENT '订单ID',
    `user_id`              ,-- STRING COMMENT '用户ID',
    `sku_id`               ,-- STRING COMMENT '商品ID',
    `province_id`          ,--STRING COMMENT '省份ID',
    `activity_id`          ,--STRING COMMENT '参与活动ID',
    `activity_rule_id`     ,--STRING COMMENT '参与活动规则ID',
    `coupon_id`            ,-- STRING COMMENT '使用优惠券ID',
    `date_id`              ,-- STRING COMMENT '下单日期ID',
    `create_time`          ,-- STRING COMMENT '下单时间',
    `sku_num`              ,--  BIGINT COMMENT '商品数量',
    `split_original_amount`,-- DECIMAL(16, 2) COMMENT '原始价格',
    `split_activity_amount`,-- DECIMAL(16, 2) COMMENT '活动优惠分摊',
    `split_coupon_amount`  ,-- DECIMAL(16, 2) COMMENT '优惠券优惠分摊',
    `split_total_amount`   -- DECIMAL(16, 2) COMMENT '最终价格分摊'
from(
        select
            data.`id`                   ,--  STRING COMMENT '编号',
            data.`order_id`             ,-- STRING COMMENT '订单ID',
            data.`sku_id`               ,-- STRING COMMENT '商品ID',
            data.`sku_num`              ,--  BIGINT COMMENT '商品数量',
            data.order_price * data.`sku_num` as split_original_amount ,-- DECIMAL(16, 2) COMMENT '原始价格',
            nvl(data.`split_activity_amount`,0.0) split_activity_amount,-- DECIMAL(16, 2) COMMENT '活动优惠分摊',
            nvl(data.`split_coupon_amount`,0.0) split_coupon_amount ,-- DECIMAL(16, 2) COMMENT '优惠券优惠分摊',
            data.`split_total_amount`   -- DECIMAL(16, 2) COMMENT '最终价格分摊'
        from ods_order_detail_inc   -- 订单明细表
        where dt = "2022-06-09" and type = 'insert'
    ) od
left join (
        select
            data.id,
            data.`user_id`              ,-- STRING COMMENT '用户ID',
            data.`province_id`          ,--STRING COMMENT '省份ID',
            date_format(data.`create_time`,"yyyy-MM-dd") `date_id`              ,-- STRING COMMENT '下单日期ID',
            data.`create_time`          -- STRING COMMENT '下单时间',
        from ods_order_info_inc     -- 订单表
        where dt = "2022-06-09" and type = 'insert'
    ) oi on od.order_id = oi.id
left join (
        select
            data.order_detail_id,
            data.`coupon_id`            -- STRING COMMENT '使用优惠券ID',
        from ods_order_detail_coupon_inc  -- 订单明细优惠卷关联表
        where dt = "2022-06-09" and type = 'insert'
    ) coupon on od.id = coupon.order_detail_id
left join (
        select
            data.order_detail_id,
            data.`activity_id`          ,--STRING COMMENT '参与活动ID',
            data.`activity_rule_id`     -- STRING COMMENT '参与活动规则ID',
        from ods_order_detail_activity_inc -- 订单明细活动关联表
        where dt = "2022-06-09" and type = 'insert'
    ) act on od.id = act.order_detail_id;








--- 交易域支付成功事务事实表
DROP TABLE IF EXISTS dwd_trade_pay_detail_suc_inc;
CREATE EXTERNAL TABLE dwd_trade_pay_detail_suc_inc
(
    `id`                      STRING COMMENT '编号',
    `order_id`               STRING COMMENT '订单ID',
    `user_id`                STRING COMMENT '用户ID',
    `sku_id`                 STRING COMMENT 'SKU_ID',
    `province_id`           STRING COMMENT '省份ID',
    `activity_id`           STRING COMMENT '参与活动ID',
    `activity_rule_id`     STRING COMMENT '参与活动规则ID',
    `coupon_id`              STRING COMMENT '使用优惠券ID',
    `payment_type_code`     STRING COMMENT '支付类型编码',
    `payment_type_name`     STRING COMMENT '支付类型名称',
    `date_id`                STRING COMMENT '支付日期ID',
    `callback_time`         STRING COMMENT '支付成功时间',
    `sku_num`                 BIGINT COMMENT '商品数量',
    `split_original_amount` DECIMAL(16, 2) COMMENT '应支付原始金额',
    `split_activity_amount` DECIMAL(16, 2) COMMENT '支付活动优惠分摊',
    `split_coupon_amount`   DECIMAL(16, 2) COMMENT '支付优惠券优惠分摊',
    `split_payment_amount`  DECIMAL(16, 2) COMMENT '支付金额'
) COMMENT '交易域支付成功事务事实表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_trade_pay_detail_suc_inc/'
    TBLPROPERTIES ('orc.compress' = 'snappy');


-- 装载数据
    -- 相关的表: 支付表, 订单表, 订单明细表, 订单明细优惠券关联表, 订单明细活动关联表
-- 首日装载数据
    -- 细节:
        -- 支付成功的时间是支付表中callback_time时间，callback_time是第三方支付平台回调通知我们平台的时间
        -- 支付表中的订单有不同的状态(支付成功，支付失败，取消支付),我们要的是支付成功的订单
        -- 支付的金额不是以订单明细中的金额，因为有些第三方平台可能也有优惠(例如,支付宝支付方式可能会存在优惠，所以以支付表中的金额为准)
        -- 与支付表的关联方式是join，必须要满足订单的支付状态是支付成功
    -- 分区策略：动态分区，首日数据状态存在历史数据
insert overwrite table dwd_trade_pay_detail_suc_inc partition(dt)
select
    od.`id`                   ,--   STRING COMMENT '编号',
    od.`order_id`             ,--  STRING COMMENT '订单ID',
    `user_id`              ,--  STRING COMMENT '用户ID',
    `sku_id`               ,--  STRING COMMENT 'SKU_ID',
    `province_id`          ,-- STRING COMMENT '省份ID',
    `activity_id`          ,-- STRING COMMENT '参与活动ID',
    `activity_rule_id`     ,-- STRING COMMENT '参与活动规则ID',
    `coupon_id`            ,--  STRING COMMENT '使用优惠券ID',
    `payment_type_code`    ,-- STRING COMMENT '支付类型编码',
    `payment_type_name`    ,-- STRING COMMENT '支付类型名称',
    `date_id`              ,--  STRING COMMENT '支付日期ID',
    `callback_time`        ,-- STRING COMMENT '支付成功时间',
    `sku_num`              ,--   BIGINT COMMENT '商品数量',
    `split_original_amount`,-- DECIMAL(16, 2) COMMENT '应支付原始金额',
    `split_activity_amount`,-- DECIMAL(16, 2) COMMENT '支付活动优惠分摊',
    `split_coupon_amount`  ,-- DECIMAL(16, 2) COMMENT '支付优惠券优惠分摊',
    `split_payment_amount` ,-- DECIMAL(16, 2) COMMENT '支付金额'
    date_id as dt
from(
        select
            data.`id`                   ,--  STRING COMMENT '编号',
            data.`order_id`             ,-- STRING COMMENT '订单ID',
            data.`sku_id`               ,-- STRING COMMENT '商品ID',
            data.`sku_num`              ,--  BIGINT COMMENT '商品数量',
            data.order_price * data.`sku_num` as split_original_amount ,-- DECIMAL(16, 2) COMMENT '原始价格',
            nvl(data.`split_activity_amount`,0.0) split_activity_amount,-- DECIMAL(16, 2) COMMENT '活动优惠分摊',
            nvl(data.`split_coupon_amount`,0.0) split_coupon_amount ,-- DECIMAL(16, 2) COMMENT '优惠券优惠分摊',
            data.`split_total_amount`   -- DECIMAL(16, 2) COMMENT '最终价格分摊'
        from ods_order_detail_inc   -- 订单明细表
        where dt = "2022-06-08" and type = 'bootstrap-insert'
    ) od
left join (
        select
            data.id,
            data.`user_id`              ,-- STRING COMMENT '用户ID',
            data.`province_id`          --STRING COMMENT '省份ID',
        from ods_order_info_inc     -- 订单表
        where dt = "2022-06-08" and type = 'bootstrap-insert'
    ) oi on od.order_id = oi.id
left join (
        select
            data.order_detail_id,
            data.`coupon_id`            -- STRING COMMENT '使用优惠券ID',
        from ods_order_detail_coupon_inc  -- 订单明细优惠卷关联表
        where dt = "2022-06-08" and type = 'bootstrap-insert'
    ) coupon on od.id = coupon.order_detail_id
left join (
        select
            data.order_detail_id,
            data.`activity_id`          ,--STRING COMMENT '参与活动ID',
            data.`activity_rule_id`     -- STRING COMMENT '参与活动规则ID',
        from ods_order_detail_activity_inc -- 订单明细活动关联表
        where dt = "2022-06-08" and type = 'bootstrap-insert'
    ) act on od.id = act.order_detail_id
join(
        select
            data.order_id,
            data.payment_type as payment_type_code,
            data.callback_time as callback_time,
            data.total_amount as split_payment_amount,
            date_format(data.callback_time,"yyyy-MM-dd") as date_id
        from ods_payment_info_inc       -- 支付表
        where dt = "2022-06-08" and type = 'bootstrap-insert'
        and data.payment_status = 1602  -- 支付成功
) as pay on od.order_id = pay.order_id
left join (
        select
            dic_code,
            dic_name as payment_type_name
        from ods_base_dic_full
        where parent_code = "11"
        and dt = "2022-06-08"
) as dic on pay.payment_type_code = dic.dic_code;



-- 每日装载
    -- 细节:
        -- 每日同步中订单增量表中我们要的数据一定是修改过的数据， 把订单支付状态从未支付修改为支付成功
        -- 特殊情况: 一张表的订单修改时间可能跨天，如上一天的23:50:00 下单，下一天的00:10:00 支付，那么这个订单的支付时间就是00:10:00
            -- 所以我们的订单的获取范围应该为支付成功的当天+前一天的数据
insert overwrite table dwd_trade_pay_detail_suc_inc partition(dt="2022-06-09")
select
    od.`id`                   ,--   STRING COMMENT '编号',
    od.`order_id`             ,--  STRING COMMENT '订单ID',
    `user_id`              ,--  STRING COMMENT '用户ID',
    `sku_id`               ,--  STRING COMMENT 'SKU_ID',
    `province_id`          ,-- STRING COMMENT '省份ID',
    `activity_id`          ,-- STRING COMMENT '参与活动ID',
    `activity_rule_id`     ,-- STRING COMMENT '参与活动规则ID',
    `coupon_id`            ,--  STRING COMMENT '使用优惠券ID',
    `payment_type_code`    ,-- STRING COMMENT '支付类型编码',
    `payment_type_name`    ,-- STRING COMMENT '支付类型名称',
    `date_id`              ,--  STRING COMMENT '支付日期ID',
    `callback_time`        ,-- STRING COMMENT '支付成功时间',
    `sku_num`              ,--   BIGINT COMMENT '商品数量',
    `split_original_amount`,-- DECIMAL(16, 2) COMMENT '应支付原始金额',
    `split_activity_amount`,-- DECIMAL(16, 2) COMMENT '支付活动优惠分摊',
    `split_coupon_amount`  ,-- DECIMAL(16, 2) COMMENT '支付优惠券优惠分摊',
    `split_payment_amount` -- DECIMAL(16, 2) COMMENT '支付金额'
from(
        select
            data.`id`                   ,--  STRING COMMENT '编号',
            data.`order_id`             ,-- STRING COMMENT '订单ID',
            data.`sku_id`               ,-- STRING COMMENT '商品ID',
            data.`sku_num`              ,--  BIGINT COMMENT '商品数量',
            data.order_price * data.`sku_num` as split_original_amount ,-- DECIMAL(16, 2) COMMENT '原始价格',
            nvl(data.`split_activity_amount`,0.0) split_activity_amount,-- DECIMAL(16, 2) COMMENT '活动优惠分摊',
            nvl(data.`split_coupon_amount`,0.0) split_coupon_amount ,-- DECIMAL(16, 2) COMMENT '优惠券优惠分摊',
            data.`split_total_amount`   -- DECIMAL(16, 2) COMMENT '最终价格分摊'
        from ods_order_detail_inc   -- 订单明细表
        where ( dt = "2022-06-09" or dt = date_sub("2022-06-09",1) )
          and ( type = 'insert' or type = 'bootstrap-insert')
    ) od
left join (
        select
            data.id,
            data.`user_id`              ,-- STRING COMMENT '用户ID',
            data.`province_id`          --STRING COMMENT '省份ID',
        from ods_order_info_inc     -- 订单表
        where ( dt = "2022-06-09" or dt = date_sub("2022-06-09",1) )
          and ( type = 'insert' or type = 'bootstrap-insert')
    ) oi on od.order_id = oi.id
left join (
        select
            data.order_detail_id,
            data.`coupon_id`            -- STRING COMMENT '使用优惠券ID',
        from ods_order_detail_coupon_inc  -- 订单明细优惠卷关联表
        where ( dt = "2022-06-09" or dt = date_sub("2022-06-09",1) )
          and ( type = 'insert' or type = 'bootstrap-insert')
    ) coupon on od.id = coupon.order_detail_id
left join (
        select
            data.order_detail_id,
            data.`activity_id`          ,--STRING COMMENT '参与活动ID',
            data.`activity_rule_id`     -- STRING COMMENT '参与活动规则ID',
        from ods_order_detail_activity_inc -- 订单明细活动关联表
        where ( dt = "2022-06-09" or dt = date_sub("2022-06-09",1) )
          and ( type = 'insert' or type = 'bootstrap-insert')
    ) act on od.id = act.order_detail_id
join(
        select
            data.order_id,
            data.payment_type as payment_type_code,
            data.callback_time as callback_time,
            data.total_amount as split_payment_amount,
            date_format(data.callback_time,"yyyy-MM-dd") as date_id
        from ods_payment_info_inc       -- TODO 支付表
        where dt = "2022-06-09" and
              type = "update"  and array_contains(map_keys(old),"payment_status")
        and data.payment_status = 1602  -- 支付成功
) as pay on od.order_id = pay.order_id
left join (
        select
            dic_code,
            dic_name as payment_type_name
        from ods_base_dic_full
        where parent_code = "11"
        and dt="2022-06-09"
) as dic on pay.payment_type_code = dic.dic_code;







--- 交易域购物车周期快照事实表
    -- 周期快照事实表: 周期性的记录一个状态
    -- 这里周期性的记录购物车中商品的情况
    -- 为什么不用事务事实表：
        -- 如果使用事务事实表，我们需要用户加购事务事实表，用户减购事务事实表，然后关联做差
        -- 缺点: 逻辑复杂,需要关联的表多,业务数据库中的购物车表已经有对应的字段，不需要再做一次
DROP TABLE IF EXISTS dwd_trade_cart_full;
CREATE EXTERNAL TABLE dwd_trade_cart_full
(
    `id`         STRING COMMENT '编号',
    `user_id`   STRING COMMENT '用户ID',
    `sku_id`    STRING COMMENT 'SKU_ID',
    `sku_name`  STRING COMMENT '商品名称',
    `sku_num`   BIGINT COMMENT '现存商品件数'
) COMMENT '交易域购物车周期快照事实表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_trade_cart_full/'
    TBLPROPERTIES ('orc.compress' = 'snappy');


-- 装载数据
    -- 每天记录一次购物车的状态，每日全量
    -- 在购物车中已经删除的商品不需要记录，但是业务数据库中不会物理删除，而是通过一个字段来标识是否还存在购物车中，因此我们要过滤出还存在在购物车中的商品
insert overwrite table dwd_trade_cart_full partition(dt="2022-06-08")
select
    `id`       ,--  STRING COMMENT '编号',
    `user_id`  ,-- STRING COMMENT '用户ID',
    `sku_id`   ,-- STRING COMMENT 'SKU_ID',
    `sku_name` ,-- STRING COMMENT '商品名称',
    `sku_num`  -- BIGINT COMMENT '现存商品件数'
from ods_cart_info_full
where dt="2022-06-08"
and is_ordered=0;   -- 购物车中未下单的商品









--- TODO 交易域交易流程累计快照事实表
    -- 交易域：交易相关的数据都存放在交易域中
    -- 交易流程: 完整的交易过程，包含了多个核心业务事件(如电商交易流程：下单->支付->收获)
    -- 累计快照事实表: 记录交易过程中的状态，汇总所有的交易流程(记录一个流程中不同的业务时间状态)
-- 建表语句
DROP TABLE IF EXISTS dwd_trade_trade_flow_acc;
CREATE EXTERNAL TABLE dwd_trade_trade_flow_acc
(
    `order_id`               STRING COMMENT '订单ID',
    `user_id`                STRING COMMENT '用户ID',
    `province_id`           STRING COMMENT '省份ID',
    `order_date_id`         STRING COMMENT '下单日期ID',
    `order_time`             STRING COMMENT '下单时间',
    `payment_date_id`        STRING COMMENT '支付日期ID',
    `payment_time`           STRING COMMENT '支付时间',
    `finish_date_id`         STRING COMMENT '确认收货日期ID',
    `finish_time`             STRING COMMENT '确认收货时间',
    `order_original_amount` DECIMAL(16, 2) COMMENT '下单原始价格',
    `order_activity_amount` DECIMAL(16, 2) COMMENT '下单活动优惠分摊',
    `order_coupon_amount`   DECIMAL(16, 2) COMMENT '下单优惠券优惠分摊',
    `order_total_amount`    DECIMAL(16, 2) COMMENT '下单最终价格分摊',
    `payment_amount`         DECIMAL(16, 2) COMMENT '支付金额'
) COMMENT '交易域交易流程累积快照事实表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_trade_trade_flow_acc/'
TBLPROPERTIES ('orc.compress' = 'snappy');


-- 装载数据
    -- 下单: 订单信息表(不需要订单明细表，这里的累计快照事实表不要求细粒度)
    -- 支付: 支付信息表
    -- 收货: 没有具体的收货信息表，但是有一个订单流水表，记录了订单的不同状态，并且是只有新增，没有修改，我们可以查看订单为收货状态的数据
-- 首日数据装载
set hive.exec.dynamic.partition.mode=nonstrict;
insert overwrite table dwd_trade_trade_flow_acc partition(dt)
select
    oi.`order_id`             ,--  STRING COMMENT '订单ID',
    `user_id`              ,--  STRING COMMENT '用户ID',
    `province_id`          ,-- STRING COMMENT '省份ID',
    `order_date_id`        ,-- STRING COMMENT '下单日期ID',
    `order_time`           ,--  STRING COMMENT '下单时间',
    `payment_date_id`      ,--  STRING COMMENT '支付日期ID',
    `payment_time`         ,--  STRING COMMENT '支付时间',
    `finish_date_id`       ,--  STRING COMMENT '确认收货日期ID',
    `finish_time`          ,--   STRING COMMENT '确认收货时间',
    `order_original_amount`,-- DECIMAL(16, 2) COMMENT '下单原始价格',
    nvl(`order_activity_amount`,0.0),-- DECIMAL(16, 2) COMMENT '下单活动优惠分摊',
    nvl(`order_coupon_amount`,0.0)  ,-- DECIMAL(16, 2) COMMENT '下单优惠券优惠分摊',
    `order_total_amount`   ,-- DECIMAL(16, 2) COMMENT '下单最终价格分摊',
    `payment_amount`       ,--  DECIMAL(16, 2) COMMENT '支付金额'
    if(finish_date_id is not null,finish_date_id,"9999-12-31")
from(
    select
        data.id `order_id`              ,-- STRING COMMENT '订单ID',
        data.`user_id`               ,-- STRING COMMENT '用户ID',
        data.`province_id`           ,--STRING COMMENT '省份ID',
        date_format(data.create_time,"yyyy-MM-dd") `order_date_id`         ,--STRING COMMENT '下单日期ID',
        data.create_time `order_time`            ,-- STRING COMMENT '下单时间',
        --data.`payment_date_id`       ,-- STRING COMMENT '支付日期ID',
        --data.`payment_time`          ,-- STRING COMMENT '支付时间',
        --data.`finish_date_id`        ,-- STRING COMMENT '确认收货日期ID',
        --data.`finish_time`           ,--  STRING COMMENT '确认收货时间',
        data.original_total_amount `order_original_amount` ,--DECIMAL(16, 2) COMMENT '下单原始价格',
        data.activity_reduce_amount `order_activity_amount` ,--DECIMAL(16, 2) COMMENT '下单活动优惠分摊',
        data.coupon_reduce_amount `order_coupon_amount`   ,--DECIMAL(16, 2) COMMENT '下单优惠券优惠分摊',
        data.total_amount `order_total_amount`    --DECIMAL(16, 2) COMMENT '下单最终价格分摊',
        -- data.`payment_amount`        -- DECIMAL(16, 2) COMMENT '支付金额'
    from ods_order_info_inc -- 订单信息表
    where dt="2022-06-08" and type="bootstrap-insert"
) oi
left join (
    select
        data.order_id,
        date_format(data.callback_time,"yyyy-MM-dd") payment_date_id,
        data.callback_time payment_time,
        data.total_amount payment_amount
    from ods_payment_info_inc   -- 支付表
    where dt="2022-06-08" and type="bootstrap-insert" and data.payment_status="1602"
) pay on oi.order_id=pay.order_id
left join (
    select
        data.order_id,
        date_format(data.create_time,"yyyy-MM-dd") finish_date_id,
        data.create_time finish_time
    from ods_order_status_log_inc        -- 订单状态流水表
    where dt="2022-06-08" and data.order_status="1004"
) log on oi.order_id = log.order_id;


-- 每日数据装载
    -- 需要取到历史的订单记录和当天新增的订单记录(历史订单记录可能存在未支付或者未收货的订单信息)
insert overwrite table dwd_trade_trade_flow_acc partition(dt)
select
        oi.`order_id`              ,-- STRING COMMENT '订单ID',
        `user_id`               ,-- STRING COMMENT '用户ID',
        `province_id`           ,--STRING COMMENT '省份ID',
        `order_date_id`         ,--STRING COMMENT '下单日期ID',
        `order_time`            ,-- STRING COMMENT '下单时间',
        if(pay.payment_time is not null,pay.payment_date_id, oi.order_date_id)       ,-- STRING COMMENT '支付日期ID',
        if(pay.`payment_time` is not null, pay.`payment_time`, oi.`payment_time`)          ,-- STRING COMMENT '支付时间',
        if(log.finish_time is not null,log.finish_date_id,oi.finish_date_id) `finish_date_id`        ,-- STRING COMMENT '确认收货日期ID',
        if(log.finish_time is not null,log.finish_time,oi.finish_time)`finish_time`           ,--  STRING COMMENT '确认收货时间',
        `order_original_amount` ,--DECIMAL(16, 2) COMMENT '下单原始价格',
        `order_activity_amount` ,--DECIMAL(16, 2) COMMENT '下单活动优惠分摊',
        `order_coupon_amount`   ,--DECIMAL(16, 2) COMMENT '下单优惠券优惠分摊',
        `order_total_amount`    ,--DECIMAL(16, 2) COMMENT '下单最终价格分摊',
        if(log.finish_time is not null,pay.payment_amount,oi.payment_amount)`payment_amount`       , -- DECIMAL(16, 2) COMMENT '支付金额'
        if(log.finish_date_id is not null,log.finish_date_id,"9999-12-31")
from(
    select
        `order_id`              ,-- STRING COMMENT '订单ID',
        `user_id`               ,-- STRING COMMENT '用户ID',
        `province_id`           ,--STRING COMMENT '省份ID',
        `order_date_id`         ,--STRING COMMENT '下单日期ID',
        `order_time`            ,-- STRING COMMENT '下单时间',
        `payment_date_id`       ,-- STRING COMMENT '支付日期ID',
        `payment_time`          ,-- STRING COMMENT '支付时间',
        `finish_date_id`        ,-- STRING COMMENT '确认收货日期ID',
        `finish_time`           ,--  STRING COMMENT '确认收货时间',
        `order_original_amount` ,--DECIMAL(16, 2) COMMENT '下单原始价格',
        `order_activity_amount` ,--DECIMAL(16, 2) COMMENT '下单活动优惠分摊',
        `order_coupon_amount`   ,--DECIMAL(16, 2) COMMENT '下单优惠券优惠分摊',
        `order_total_amount`    ,--DECIMAL(16, 2) COMMENT '下单最终价格分摊',
        `payment_amount`        -- DECIMAL(16, 2) COMMENT '支付金额'
    from dwd_trade_trade_flow_acc       -- TODO 历史订单数据
    where dt="9999-12-31"
    union    -- 只能使用union,如果使用union all的话,如果重试会导致数据重复
    select
            data.id `order_id`              ,-- STRING COMMENT '订单ID',
            data.`user_id`               ,-- STRING COMMENT '用户ID',
            data.`province_id`           ,--STRING COMMENT '省份ID',
            date_format(data.create_time,"yyyy-MM-dd") `order_date_id`         ,--STRING COMMENT '下单日期ID',
            data.create_time `order_time`            ,-- STRING COMMENT '下单时间',
            null       ,-- STRING COMMENT '支付日期ID',
            null          ,-- STRING COMMENT '支付时间',
            null        ,-- STRING COMMENT '确认收货日期ID',
            null           ,--  STRING COMMENT '确认收货时间',
            data.original_total_amount `order_original_amount` ,--DECIMAL(16, 2) COMMENT '下单原始价格',
            data.activity_reduce_amount `order_activity_amount` ,--DECIMAL(16, 2) COMMENT '下单活动优惠分摊',
            data.coupon_reduce_amount `order_coupon_amount`   ,--DECIMAL(16, 2) COMMENT '下单优惠券优惠分摊',
            data.total_amount `order_total_amount`    ,--DECIMAL(16, 2) COMMENT '下单最终价格分摊',
            null        -- DECIMAL(16, 2) COMMENT '支付金额'
        from ods_order_info_inc     -- TODO 新增的订单数据
        where dt="2022-06-09" and type="insert"
) oi
left join (
    select
        data.order_id,
        date_format(data.callback_time,"yyyy-MM-dd") payment_date_id,
        data.callback_time payment_time,
        data.total_amount payment_amount
    from ods_payment_info_inc   -- 支付表
    where dt='2022-06-09'
    and type='update'
    and array_contains(map_keys(old),'payment_status')
    and data.payment_status='1602'
) pay on oi.order_id=pay.order_id
left join (
    select
        data.order_id,
        date_format(data.create_time,"yyyy-MM-dd") finish_date_id,
        data.create_time finish_time
    from ods_order_status_log_inc        -- 订单状态流水表
    where dt="2022-06-09" and data.order_status="1004"
) log on oi.order_id = log.order_id;





--- TODO 工具域优惠卷使用事务事实表
-- 建表语句
DROP TABLE IF EXISTS dwd_tool_coupon_used_inc;
CREATE EXTERNAL TABLE dwd_tool_coupon_used_inc
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
    TBLPROPERTIES ("orc.compress" = "snappy");


-- 装载数据
    -- 只要支付成功使用的优惠卷，优惠卷可能会在下单的时候时候,只有支付成功优惠卷才会不存在
-- 首日装载数据
    -- 分区策略: 按照不同的使用时间动态分区
insert overwrite table dwd_tool_coupon_used_inc partition (dt)
select
    data.`id`           ,--STRING COMMENT '编号',
    data.`coupon_id`    ,--STRING COMMENT '优惠券ID',
    data.`user_id`      ,--STRING COMMENT '用户ID',
    data.`order_id`     ,--STRING COMMENT '订单ID',
    date_format(data.used_time,'yyyy-MM-dd') `date_id`      ,--STRING COMMENT '日期ID',
    data.`used_time` ,--STRING COMMENT '使用(支付)时间'
    date_format(data.used_time,'yyyy-MM-dd')
from ods_coupon_use_inc
where dt='2022-06-08' and type='bootstrap-insert'
and data.used_time is not null;     -- 只需要成功支付的优惠卷信息


-- 每日数据装载
insert overwrite table dwd_tool_coupon_used_inc partition (dt='2022-06-09')
select
    data.`id`           ,--STRING COMMENT '编号',
    data.`coupon_id`    ,--STRING COMMENT '优惠券ID',
    data.`user_id`      ,--STRING COMMENT '用户ID',
    data.`order_id`     ,--STRING COMMENT '订单ID',
    date_format(data.used_time,'yyyy-MM-dd') `date_id`      ,--STRING COMMENT '日期ID',
    data.`used_time` --STRING COMMENT '使用(支付)时间'
from ods_coupon_use_inc
where dt='2022-06-09' and type='update'  -- insert属于领取优惠卷,使用优惠卷会修改used_time，所以type类型 update
and array_contains(map_keys(old),'used_time');   -- 修改的字段是used_time








--- TODO 互动域收藏商品事务事实表
    -- 这里我们关注的是用户收藏商品的行为，不关注商品是否被取消收藏
-- 建表语句
DROP TABLE IF EXISTS dwd_interaction_favor_add_inc;
CREATE EXTERNAL TABLE dwd_interaction_favor_add_inc
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
    TBLPROPERTIES ("orc.compress" = "snappy");

-- 装载数据
    -- 收藏商品: insert -> 取消收藏 : update -> 收藏商品(不管是第一次还是之前取消现在再次收藏): insert
-- 首日装载数据
insert overwrite table dwd_interaction_favor_add_inc partition(dt)
select
    data.id,
    data.user_id,
    data.sku_id,
    date_format(data.create_time,'yyyy-MM-dd') date_id,
    data.create_time,
    date_format(data.create_time,'yyyy-MM-dd')
from ods_favor_info_inc
where dt='2022-06-08'
and type = 'bootstrap-insert';

-- 每日装载数据
insert overwrite table dwd_interaction_favor_add_inc partition(dt='2022-06-09')
select
    data.id,
    data.user_id,
    data.sku_id,
    date_format(data.create_time,'yyyy-MM-dd') date_id,
    data.create_time
from ods_favor_info_inc
where dt='2022-06-09'
and type = 'insert';






--- TODO 流量域页面浏览事务事实表
    -- 数据来源: 日志数据
-- 建表语句
DROP TABLE IF EXISTS dwd_traffic_page_view_inc;
CREATE EXTERNAL TABLE dwd_traffic_page_view_inc
(
    `province_id`    STRING COMMENT '省份ID',
    `brand`           STRING COMMENT '手机品牌',
    `channel`         STRING COMMENT '渠道',
    `is_new`          STRING COMMENT '是否首次启动',
    `model`           STRING COMMENT '手机型号',
    `mid_id`          STRING COMMENT '设备ID',
    `operate_system` STRING COMMENT '操作系统',
    `user_id`         STRING COMMENT '会员ID',
    `version_code`   STRING COMMENT 'APP版本号',
    `page_item`       STRING COMMENT '目标ID',
    `page_item_type` STRING COMMENT '目标类型',
    `last_page_id`    STRING COMMENT '上页ID',
    `page_id`          STRING COMMENT '页面ID ',
    `from_pos_id`     STRING COMMENT '点击坑位ID',
    `from_pos_seq`    STRING COMMENT '点击坑位位置',
    `refer_id`         STRING COMMENT '营销渠道ID',
    `date_id`          STRING COMMENT '日期ID',
    `view_time`       STRING COMMENT '跳入时间',
    `session_id`      STRING COMMENT '所属会话ID',
    `during_time`     BIGINT COMMENT '持续时间毫秒'
) COMMENT '流量域页面浏览事务事实表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_traffic_page_view_inc'
    TBLPROPERTIES ('orc.compress' = 'snappy');


-- 装载数据
    -- 日志数据是不保存历史数据并且只有insert操作
    -- 日志数据是通过flume采集过来的,不需要额外的"bootstrap"判断,首日和每日是相同的逻辑
set hive.cbo.enable=false;   -- hive的cbo优化对于结构体判空存在BUG，需要关闭优化
insert overwrite table dwd_traffic_page_view_inc partition (dt='2022-06-08')
select
    common.ar province_id,
    common.ba brand,
    common.ch channel,
    common.is_new is_new,
    common.md model,
    common.mid mid_id,
    common.os operate_system,
    common.uid user_id,
    common.vc version_code,
    page.item page_item,
    page.item_type page_item_type,
    page.last_page_id,
    page.page_id,
    page.from_pos_id,
    page.from_pos_seq,
    page.refer_id,
    date_format(from_utc_timestamp(ts,'GMT+8'),'yyyy-MM-dd') date_id,
    date_format(from_utc_timestamp(ts,'GMT+8'),'yyyy-MM-dd HH:mm:ss') view_time,
    common.sid session_id,
    page.during_time
from ods_log_inc
where dt='2022-06-08'
and page is not null;
set hive.cbo.enable=true;






--- 用户域用户注册事务事实表
-- 建表语句
DROP TABLE IF EXISTS dwd_user_register_inc;
CREATE EXTERNAL TABLE dwd_user_register_inc
(
    `user_id`          STRING COMMENT '用户ID',
    `date_id`          STRING COMMENT '日期ID',
    `create_time`     STRING COMMENT '注册时间',
    `channel`          STRING COMMENT '应用下载渠道',
    `province_id`     STRING COMMENT '省份ID',
    `version_code`    STRING COMMENT '应用版本',
    `mid_id`           STRING COMMENT '设备ID',
    `brand`            STRING COMMENT '设备品牌',
    `model`            STRING COMMENT '设备型号',
    `operate_system` STRING COMMENT '设备操作系统'
) COMMENT '用户域用户注册事务事实表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_user_register_inc/'
    TBLPROPERTIES ("orc.compress" = "snappy");

-- 装载数据
    -- 用户注册成功会在用户表中新增一条数据,关联用户日志数据拿到设备名称，渠道等字段
-- 首日数据装载
set hive.exec.dynamic.partition.mode=nonstrict;
insert overwrite table dwd_user_register_inc partition(dt)
select
    ui.user_id,
    date_format(create_time,'yyyy-MM-dd') date_id,
    create_time,
    channel,
    province_id,
    version_code,
    mid_id,
    brand,
    model,
    operate_system,
    date_format(create_time,'yyyy-MM-dd')
from(
    select
        data.id user_id,
        data.create_time
    from ods_user_info_inc
    where dt='2022-06-08'
    and type='bootstrap-insert'
)ui
left join(
    select
        common.ar province_id,
        common.ba brand,
        common.ch channel,
        common.md model,
        common.mid mid_id,
        common.os operate_system,
        common.uid user_id,
        common.vc version_code
    from ods_log_inc
    where dt='2022-06-08'
    and page.page_id='register'
    and common.uid is not null
)log
on ui.user_id=log.user_id;


-- 每日数据装载
    -- 跟首日一样，只是每日没有历史数据，使用静态分区
insert overwrite table dwd_user_register_inc partition(dt='2022-06-09')
select
    ui.user_id,
    date_format(create_time,'yyyy-MM-dd') date_id,
    create_time,
    channel,
    province_id,
    version_code,
    mid_id,
    brand,
    model,
    operate_system
from(
    select
        data.id user_id,
        data.create_time
    from ods_user_info_inc
    where dt='2022-06-09'
    and type='insert'
)ui
left join(
    select
        common.ar province_id,
        common.ba brand,
        common.ch channel,
        common.md model,
        common.mid mid_id,
        common.os operate_system,
        common.uid user_id,
        common.vc version_code
    from ods_log_inc
    where dt='2022-06-09'
    and page.page_id='register'
    and common.uid is not null
)log
on ui.user_id=log.user_id;





--- 用户域用户登录事务事实表
-- 建表语句
DROP TABLE IF EXISTS dwd_user_login_inc;
CREATE EXTERNAL TABLE dwd_user_login_inc
(
    `user_id`         STRING COMMENT '用户ID',
    `date_id`         STRING COMMENT '日期ID',
    `login_time`     STRING COMMENT '登录时间',
    `channel`         STRING COMMENT '应用下载渠道',
    `province_id`    STRING COMMENT '省份ID',
    `version_code`   STRING COMMENT '应用版本',
    `mid_id`          STRING COMMENT '设备ID',
    `brand`           STRING COMMENT '设备品牌',
    `model`           STRING COMMENT '设备型号',
    `operate_system` STRING COMMENT '设备操作系统'
) COMMENT '用户域用户登录事务事实表'
    PARTITIONED BY (`dt` STRING)
    STORED AS ORC
    LOCATION '/warehouse/gmall/dwd/dwd_user_login_inc/'
    TBLPROPERTIES ("orc.compress" = "snappy");

-- 装载数据
    -- 登录：uid不为空,并且同一个会话id，排名为第一个的是我们的用户登录日志
insert overwrite table dwd_user_login_inc partition (dt = '2022-06-08')
select user_id,
       date_format(from_utc_timestamp(ts, 'GMT+8'), 'yyyy-MM-dd')          date_id,
       date_format(from_utc_timestamp(ts, 'GMT+8'), 'yyyy-MM-dd HH:mm:ss') login_time,
       channel,
       province_id,
       version_code,
       mid_id,
       brand,
       model,
       operate_system
from (
         select user_id,
                channel,
                province_id,
                version_code,
                mid_id,
                brand,
                model,
                operate_system,
                ts
         from (select common.uid user_id,
                      common.ch  channel,
                      common.ar  province_id,
                      common.vc  version_code,
                      common.mid mid_id,
                      common.ba  brand,
                      common.md  model,
                      common.os  operate_system,
                      ts,
                      row_number() over (partition by common.sid order by ts) rn
               from ods_log_inc
               where dt = '2022-06-08'
                 and page is not null
                 and common.uid is not null) t1
         where rn = 1
     ) t2;










