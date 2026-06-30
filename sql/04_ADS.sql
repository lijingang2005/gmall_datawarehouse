-- ADS层(Application Data Service: 应用数据服务层)
    -- 最终的统计分析结果对外提供服务
        -- 数据量不多，不需要分区
        -- TSV数据格式，使用MySQL中间件对外提供服务
        -- gzip压缩格式，不需要再进行统计了，我们更看重空间
    -- 数据来源
        -- 可能基于DWS层的表(优先考虑)
        -- 也可能是基于 DWD+DIM 层的表(DWS层存储中间计算结果，但是中间计算结果只给一个需求使用就没必要存，只能基于DWD+DIM层)

-- 统计分析体系(方法)
    -- 第一步：确定原子性指标
        -- 取哪张表(业务过程)中的哪个字段(度量值)，做什么计算(聚合逻辑)
    -- 第二步：确定派生指标
        -- 派生指标：基于原子性指标，进行组合
        -- 统计周期: 统计的时间范围(where过滤，针对分区)
        -- 业务限定: 统计的限定业务条件(where过滤，针对业务范围)
        -- 统计粒度: 统计的角度(group by,维度表)
    -- 第三步：确定衍生指标
        -- 衍生指标：基于派生指标，进行组合
        -- 例如比率，比例等指标，需要两个派生指标进行计算才能得出


--- 需求一: 各品牌商品下单统计
/*
 需求说明如下
统计周期	        统计粒度	    指标	        说明
最近1、7、30日	品牌	        下单数	    略
最近1、7、30日	品牌      	下单人数	    略
 */
-- 建表
DROP TABLE IF EXISTS ads_order_stats_by_tm;
CREATE EXTERNAL TABLE ads_order_stats_by_tm
(
    `dt`               STRING COMMENT '统计日期',
    `recent_days`      BIGINT COMMENT '最近天数,1:最近1天,7:最近7天,30:最近30天',
    `tm_id`            STRING COMMENT '品牌ID',
    `tm_name`          STRING COMMENT '品牌名称',
    `order_count`      BIGINT COMMENT '下单数',
    `order_user_count` BIGINT COMMENT '下单人数'
) COMMENT '各品牌商品下单统计'
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    LOCATION '/warehouse/gmall/ads/ads_order_stats_by_tm/';


-- 装载数据
    -- 没有分区的概念，全部数据都保存在一个表中
    -- 并且使用的是overwrite，避免重试造成数据重复,所以使用的是覆盖
    -- 覆盖会导致之前的数据不见，所以我们取出 old + new -> overwrite -> old
insert overwrite table ads_order_stats_by_tm
select dt,recent_days,tm_id,tm_name,order_count,order_user_count from ads_order_stats_by_tm
union  -- 从原表中取出数据处理之后在返回去，这里必须使用union，不然重试会导致处理过的数据重复
select dt,recent_days,tm_id,tm_name,order_count,order_user_count from (
    -- 最近一天各品牌的下单统计
    select "2022-06-08" dt,
           1 recent_days,
           tm_id,
           tm_name,
           count(distinct order_id) order_count,
           count(distinct user_id)  order_user_count
    from (select sku_id,
                 order_id,
                 user_id
          from dwd_trade_order_detail_inc
          where dt = '2022-06-08') od
             left join (select id,
                               tm_id,
                               tm_name
                        from dim_sku_full
                        where dt = '2022-06-08') sku on od.sku_id = sku.id
    group by "2022-06-08", 1, tm_id, tm_name
    union all   -- 合并所有数据，不管是否重复(我们这里肯定不会重复，统计周期是常量，并且都不相同)
    -- 最近7天各品牌的下单统计
        -- 商品维度表只需要取最后一天的就可以，不需要把前7天的都取到
        -- 业务数据库中不会物理删除数据，使用的是逻辑删除
        -- 所以最后一天的商品维度表包含了前七天的数据
    select
        "2022-06-08",
        7,
        tm_id,
        tm_name,
        count(distinct order_id) order_count,
        count(distinct user_id)  order_user_count
    from (select sku_id,
                 order_id,
                 user_id
          from dwd_trade_order_detail_inc
          where dt >= date_sub('2022-06-08', 6)
            and dt <= '2022-06-08') od
             left join (select id,
                               tm_id,
                               tm_name
                        from dim_sku_full
                        where dt = '2022-06-08') sku on od.sku_id = sku.id
    group by "2022-06-08", 7, tm_id, tm_name
    union all
    -- 最近30天各品牌的下单统计
    select
        "2022-06-08",
        30,
        tm_id,
        tm_name,
        count(distinct order_id) order_count,
        count(distinct user_id)  order_user_count
    from (select sku_id,
                 order_id,
                 user_id
          from dwd_trade_order_detail_inc
          where dt >= date_sub('2022-06-08', 29)
            and dt <= '2022-06-08') od
             left join (select id,
                               tm_id,
                               tm_name
                        from dim_sku_full
                        where dt = '2022-06-08') sku on od.sku_id = sku.id
    group by "2022-06-08", 30, tm_id, tm_name
)t1;
--------------------------------------------------------------------
    /*
     TODO 优化
        -这个sql中存在了数据的重复读取以及重复计算
            -- 30天的数据中包含了一天的数据和7天的数据
            -- 我们可以将一天的汇总结果统计到一张汇总表中
            -- 一个星期和一个月的统计汇总可以基于1天的汇总表进行统计计算
        -我们将中间的计算结果放入DWS层中
     */
-----------------------------------------------------------------------
-- 优化之后的sql
    -- 基于dws层的交易域用户商品粒度订单最近1日汇总表和最近n日汇总表进行计算，减少数据的重复计算，提高查询效率
insert overwrite table ads_order_stats_by_tm
select * from ads_order_stats_by_tm
union
select
    '2022-06-08' dt,
    recent_days,
    tm_id,
    tm_name,
    order_count,
    order_user_count
from
(
    select
        1 recent_days,
        tm_id,
        tm_name,
        sum(order_count_1d) order_count,
        count(distinct(user_id)) order_user_count
    from dws_trade_user_sku_order_1d
    where dt='2022-06-08'
    group by 1, tm_id, tm_name
    union all
    select
        recent_days,
        tm_id,
        tm_name,
        sum(order_count),
        count(distinct(if(order_count>0,user_id,null)))
    from
    (
        select
            recent_days,
            user_id,
            tm_id,
            tm_name,
            case recent_days
                when 7 then order_count_7d
                when 30 then order_count_30d
            end order_count
        from dws_trade_user_sku_order_nd
            lateral view explode(array(7,30)) tmp as recent_days  -- 使用炸裂函数，将一行数据炸裂成两行
        where dt='2022-06-08'
    )t1
    group by recent_days,tm_id,tm_name
)odr;







--- 需求二: 各分类商品下单统计
/*
 需求说明如下
统计周期	        统计粒度	    指标	        说明
最近1、7、30日	品类	        下单数	    略
最近1、7、30日	品类	        下单人数	    略
 */

-- 建表
DROP TABLE IF EXISTS ads_order_stats_by_cate;
CREATE EXTERNAL TABLE ads_order_stats_by_cate
(
    `dt`                      STRING COMMENT '统计日期',
    `recent_days`             BIGINT COMMENT '最近天数,1:最近1天,7:最近7天,30:最近30天',
    `category1_id`            STRING COMMENT '一级品类ID',
    `category1_name`          STRING COMMENT '一级品类名称',
    `category2_id`            STRING COMMENT '二级品类ID',
    `category2_name`          STRING COMMENT '二级品类名称',
    `category3_id`            STRING COMMENT '三级品类ID',
    `category3_name`          STRING COMMENT '三级品类名称',
    `order_count`             BIGINT COMMENT '下单数',
    `order_user_count`        BIGINT COMMENT '下单人数'
) COMMENT '各品类商品下单统计'
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    LOCATION '/warehouse/gmall/ads/ads_order_stats_by_cate/';


-- 数据装载(基于用户商品粒度订单一日表和用户商品粒度订单nd表)
insert overwrite table ads_order_stats_by_cate
select * from ads_order_stats_by_cate
union
select
    '2022-06-08'                     ,-- STRING COMMENT '统计日期',
    `recent_days`            ,-- BIGINT COMMENT '最近天数,1:最近1天,7:最近7天,30:最近30天',
    `category1_id`           ,-- STRING COMMENT '一级品类ID',
    `category1_name`         ,-- STRING COMMENT '一级品类名称',
    `category2_id`           ,-- STRING COMMENT '二级品类ID',
    `category2_name`         ,-- STRING COMMENT '二级品类名称',
    `category3_id`           ,-- STRING COMMENT '三级品类ID',
    `category3_name`         ,-- STRING COMMENT '三级品类名称',
    `order_count`            ,-- BIGINT COMMENT '下单数',
    `order_user_count`       -- BIGINT COMMENT '下单人数'
    from
(
    -- 1天
    select
        '2022-06-08'                     ,--STRING COMMENT '统计日期',
        1   recent_days         ,--BIGINT COMMENT '最近天数,1:最近1天,7:最近7天,30:最近30天',
        `category1_id`           ,--STRING COMMENT '一级品类ID',
        `category1_name`         ,--STRING COMMENT '一级品类名称',
        `category2_id`           ,--STRING COMMENT '二级品类ID',
        `category2_name`         ,--STRING COMMENT '二级品类名称',
        `category3_id`           ,--STRING COMMENT '三级品类ID',
        `category3_name`         ,--STRING COMMENT '三级品类名称',
        sum(order_count_1d) `order_count`            ,--BIGINT COMMENT '下单数',
        count(distinct user_id) `order_user_count`       --BIGINT COMMENT '下单人数'
    from dws_trade_user_sku_order_1d
    where dt='2022-06-08'
    group by `category1_id`,`category1_name`,`category2_id`,`category2_name`,`category3_id`,`category3_name`
    union all
    -- 7天
    select
        '2022-06-08',
        7 recent_days,
        `category1_id`,
        `category1_name`,
        `category2_id`,
        `category2_name`,
        `category3_id`,
        `category3_name`,
        sum(order_count_7d) `order_count`,
        count(distinct user_id) `order_user_count`
    from dws_trade_user_sku_order_nd
    where dt='2022-06-08'
    group by `category1_id`,`category1_name`,`category2_id`,`category2_name`,`category3_id`,`category3_name`
    union all
    -- 30天
    select
        '2022-06-08',
        30 recent_days,
        `category1_id`,
        `category1_name`,
        `category2_id`,
        `category2_name`,
        `category3_id`,
        `category3_name`,
        sum(order_count_30d) `order_count`,
        count(distinct user_id) `order_user_count`
    from dws_trade_user_sku_order_nd
    where dt='2022-06-08'
    group by `category1_id`,`category1_name`,`category2_id`,`category2_name`,`category3_id`,`category3_name`
) t1;


--- 统计新增下单用户数量
-- 建表语句
DROP TABLE IF EXISTS ads_new_order_user_stats;
CREATE EXTERNAL TABLE ads_new_order_user_stats
(
    `dt`                   STRING COMMENT '统计日期',
    `recent_days`          BIGINT COMMENT '最近天数,1:最近1天,7:最近7天,30:最近30天',
    `new_order_user_count` BIGINT COMMENT '新增下单人数'
) COMMENT '新增下单用户统计'
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    LOCATION '/warehouse/gmall/ads/ads_new_order_user_stats/';

-- 数据装载（优化前，没有使用dws计算中间结果）
-- 1天
select
    '2022-06-08'                  dt,
    1 recent_days,
    count(distinct user_id) new_order_user_count
from dwd_trade_order_detail_inc
where dt = '2022-06-08'
and user_id not in (
        select user_id
        from dwd_trade_order_detail_inc
        where dt < '2022-06-08'
    )
union all
-- 7天
select
    '2022-06-08'                  dt,
    7 recent_days,
    count(distinct user_id) new_order_user_count
from dwd_trade_order_detail_inc
where dt >= date_sub('2022-06-08',6) and dt <= '2022-06-08'
and user_id not in (
        select user_id
        from dwd_trade_order_detail_inc
        where dt < date_sub('2022-06-08',6)
    )
union all
-- 30天
select
    '2022-06-08'                  dt,
    30 recent_days,
    count(distinct user_id) new_order_user_count
from dwd_trade_order_detail_inc
where dt >= date_sub('2022-06-08',29) and dt <= '2022-06-08'
and user_id not in (
        select user_id
        from dwd_trade_order_detail_inc
        where dt < date_sub('2022-06-08',29)
    );
/*
 TODO 上述的sql执行效率特别低
    原因：
        1，dwd_trade_order_detail_inc表数据量特别大，数据量越大，执行时间越长
        2.每一次都是全表扫描，并且执行了三次
    优化思路：
        1，创建一张表用于存储用户第一次下单的时间（历史表，截至到今天为止）
        2，统计新增下单用户的时候直接查询这张表，给定时间范围，直接count统计就可以了
    创建 dws_trade_user_order_td 交易域用户粒度订单历史至今汇总表
*/

------------------------------------------上述引出了DWS层的重要性---------------------------------------------------------
------------------------------------------下面是ADS层的需求实现---------------------------------------------------------

-----------------------------------------------流量主题的需求---------------------------------------------------------
--- TODO 需求一: 各渠道流量统计
-- 需求说明
/*
统计周期	        统计粒度	    指标	                    说明
最近1/7/30日	    渠道	        访客数	                统计访问人数
最近1/7/30日	    渠道	        会话平均停留时长	        统计会话平均停留时长
最近1/7/30日	    渠道	        会话平均浏览页面数	        统计会话平均浏览页面数
最近1/7/30日	    渠道	        会话总数	                统计会话总数
最近1/7/30日	    渠道	        跳出率	                统计只有一个页面的会话的比例
 */
-- 建表语句
DROP TABLE IF EXISTS ads_traffic_stats_by_channel;
CREATE EXTERNAL TABLE ads_traffic_stats_by_channel
(
    `dt`               STRING COMMENT '统计日期',
    `recent_days`      BIGINT COMMENT '最近天数,1:最近1天,7:最近7天,30:最近30天',
    `channel`          STRING COMMENT '渠道',
    `uv_count`         BIGINT COMMENT '访客人数',
    `avg_duration_sec` BIGINT COMMENT '会话平均停留时长，单位为秒',
    `avg_page_count`   BIGINT COMMENT '会话平均浏览页面数',
    `sv_count`         BIGINT COMMENT '会话数',
    `bounce_rate`      DECIMAL(16, 2) COMMENT '跳出率'
) COMMENT '各渠道流量统计'
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    LOCATION '/warehouse/gmall/ads/ads_traffic_stats_by_channel/';
/*
 实现思路：
    方式一：
        从dws_traffic_session_page_view_1d中分别查询最近 1天、最近 7天、最近30天 的会话数据，然后根据渠道分组统计指标值，最后合并结果集
            -- 缺点：重复读取数据，效率低
    方式二：
        1.从dws_traffic_session_page_view_1d中查询最近30天的数据(30天的数据包含7天和1天的数据)
        2.将三十天的数据炸裂成三分数据，每一份数据都打上一个炸裂标记（1、7、30）
        3.将数据进行过滤，一天的数据只保留最近1天的数据，7天的数据只保留最近7天的数据，30天的数据只保留最近30天的数据
            where dt >= date_sub('2022-06-08',recent_days - 1) and dt <= '2022-06-08'
        4.将数据根据recent_days，channel分组统计指标值
            -- 优点：效率高，只读取一次数据
            -- 缺点:需要在内存中进行炸裂，内存占用高
*/
insert overwrite table ads_traffic_stats_by_channel
select * from ads_traffic_stats_by_channel
union
select
    '2022-06-08',
    recent_days,
    channel,
    count(distinct mid_id),
    avg(during_time_1d / 1000),
    avg(page_count_1d),
    count(distinct session_id),
    sum( if(page_count_1d = 1,1,0) ) / count(distinct session_id)
from(
    select
        channel,
        mid_id,
        during_time_1d,
        page_count_1d,
        session_id,
        dt
    from dws_traffic_session_page_view_1d
    where dt >= date_sub('2022-06-08',29) and dt <= '2022-06-08'
) t lateral view explode( array(1,7,30) ) tmp as recent_days
where dt >= date_sub('2022-06-08',recent_days - 1) and dt <= '2022-06-08'
group by recent_days,channel;



--- TODO 需求二: 路径分析
/*
 需求说明：
     起始页面   跳转页面   访问次数
*/
-- 建表语句
DROP TABLE IF EXISTS ads_page_path;
CREATE EXTERNAL TABLE ads_page_path
(
    `dt`          STRING COMMENT '统计日期',
    `source`      STRING COMMENT '跳转起始页面ID',
    `target`      STRING COMMENT '跳转终到页面ID',
    `path_count`  BIGINT COMMENT '跳转次数'
) COMMENT '页面浏览路径分析'
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    LOCATION '/warehouse/gmall/ads/ads_page_path/';
/*
 实现思路：
    数据来源: DWD层：dwd_traffic_page_view_inc 页面浏览日志表
    注意点：
        1.需要保证页面跳转的连续性，以及顺序性
            -- 同一个会话中才会有连续跳转的概念
        2.我们不关注当前页面的上一个页面，只关注当前页面的下一个页面
            -- 因为我们的需求是统计页面跳转的次数，而不是页面的访问次数
            -- 如果第一次访问页面，上一个页面为null，我们可以忽略不计
        3. 如果当前页面的下一个页面为null，我们需要打上标记，例如：'out'
        4. 我们使用图形化工具展示桑吉图，不能够出现有环图的情况，但是页面浏览会出现环图的情况，所以我们给每个页面添加一个前缀，例如：'step_1'
    实现步骤：
        1.根据会话id分组，访问时间升序，进行lead()开窗，统计每个页面的下一个页面
        2.根据会话id分组，访问时间升序，进行row_number()开窗，标记每一个步骤，用于拼接路径
        3.根据页面路径分组，统计跳转次数
*/
insert overwrite table ads_page_path
select * from ads_page_path
union
select
    '2022-06-08',
    source,
    target,
    count(*) as path_count
from(
    select
        concat('step-',rn,':',page_id) as source,
        concat('step-',rn+1,':',next_page) as target
    from(
        select
            page_id,
            lead(page_id,1,'out') over (partition by session_id order by view_time) as next_page,
            row_number() over (partition by session_id order by view_time) as rn
        from dwd_traffic_page_view_inc
    ) t
)t1 group by source,target;


---------------------------------------------- 用户主题 --------------------------------------------------------------
-- TODO 需求三: 用户变动统计
/*
 需求说明：
    指标	            说明
    流失用户数	之前活跃(登录)过的用户，最近一段时间未活跃，就称为流失用户。此处要求统计7日前（只包含7日前当天）活跃，但最近7日未活跃的用户总数。
    回流用户数	之前的活跃用户，一段时间未活跃（流失），今日又活跃了，就称为回流用户。此处要求统计回流用户总数。

 概念说明：
    流失用户: 末次登录是在7天前的当天
        -- 示例： 8，7，6，5，4，3，2，1(login)，31  只有（有且只有）末次是在一号登录的用户才算，
                末次在31号的用户也不算，因为这个用户在7号的时候统计了
        -- 规律: 有且只有末次登录在7天前的当天的用户才算流失用户，其他用户都不算流失用户。

    回流用户: 最近7天没有登录，末次登录是在 7 天之前的用户，中间间隔了 7 天没有登录
        -- 示例：8（login），7，6，5，4，3，2，1，31（login）
        -- 规律: 必须在当天登录，并且上一次登录时间距离现在相差 >= 8

 */
-- 建表语句
DROP TABLE IF EXISTS ads_user_change;
CREATE EXTERNAL TABLE ads_user_change
(
    `dt`               STRING COMMENT '统计日期',
    `user_churn_count` BIGINT COMMENT '流失用户数',
    `user_back_count`  BIGINT COMMENT '回流用户数'
) COMMENT '用户变动统计'
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    LOCATION '/warehouse/gmall/ads/ads_user_change/';

/*
    实现思路：
        1.数据来源：dws_user_user_login_td 用户登录历史至今汇总表
        2.先查询出来流失用户，where login_date_last = date_sub('2022-06-08',7)
        3.查询回流用户，当天有登录并且 末次登录距离现在相差 >= 8 天
        4.合并流失用户和回流用户，统计每个用户的变动次数
*/
insert overwrite table ads_user_change
select * from ads_user_change
union
select
    '2022-06-08',
    user_churn_count,
    user_back_count
from(
    -- 流失用户数
    select
        '2022-06-08' as dt,
        count(user_id) user_churn_count
    from dws_user_user_login_td
    where dt = '2022-06-08'
    and login_date_last = date_sub('2022-06-08',7)
) t1
join (
    -- 回流用户数
    select
        '2022-06-08' as dt,
        count(a.user_id) user_back_count
    from(
        -- 当天登录的用户
        select
            user_id
        from dws_user_user_login_td
        where dt = '2022-06-08'
        and login_date_last = '2022-06-08'
    ) a
    join(
        -- 前7天登录的用户
        select
            user_id
        from dws_user_user_login_td
        where dt = date_sub("2022-06-08",1)
        and login_date_last <= date_sub("2022-06-08",8)
    ) b on a.user_id = b.user_id
) t2 on t1.dt = t2.dt;



-- TODO 需求四: 新增用户留存统计
/*
 需求说明：
    统计范围   用户时间            指标              说明
     1-7天    用户注册时间         新增用户数      当天新增的用户数量
     1-7天    用户注册时间         留存率         注册后活跃的用户数据 / 新增用户数
*/
-- 建表语句
DROP TABLE IF EXISTS ads_user_retention;
CREATE EXTERNAL TABLE ads_user_retention
(
    `dt`              STRING COMMENT '统计日期',
    `create_date`     STRING COMMENT '用户新增日期',
    `retention_day`   INT COMMENT '截至当前日期留存天数',
    `retention_count` BIGINT COMMENT '留存用户数量',
    `new_user_count`  BIGINT COMMENT '新增用户数量',
    `retention_rate`  DECIMAL(16, 2) COMMENT '留存率'
) COMMENT '用户留存率'
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    LOCATION '/warehouse/gmall/ads/ads_user_retention/';
/*
 实现思路：
    1.数据来源：dws_user_user_login_td 用户登录历史至今汇总表(第一次登录就是注册)
    2.先查询7天内所有的注册用户(8号统计的话就要查询之前7天注册的用户)
        where login_date_last >= date_sub('2022-06-08',7) and login_date_last < '2022-06-08'
    3.根据注册日期进行分组，统计出之前7天每天的注册人数
    4.统计8号登录的用户数量(由于条件是7天内的注册用户,所以8号登录的用户都是新增的用户)
        sum(if( login_date_last = '2022-06-08', 1, 0))
    5.统计出每个用户的留存率
 */
select
    '2022-06-08' as dt,
    login_date_first as create_date,
    datediff('2022-06-08', login_date_first) as retention_day,
    sum(if( login_date_last = '2022-06-08', 1, 0)) as retention_count,
    count(user_id) as new_user_count,
    cast(sum(if(login_date_last = '2022-06-08', 1, 0)) / count(*) * 100 as decimal(16, 2)) retention_rate
from dws_user_user_login_td
where dt = '2022-06-08'
and login_date_first >= date_sub('2022-06-08',7) and login_date_first < '2022-06-08'  -- 7天内的注册用户
group by login_date_first;


--- TODO 需求五: 新增用户留存统计(按天统计)
/*
 需求说明如下
    统计周期	        指标	        指标说明
    最近1、7、30日	新增用户数	注册人数
    最近1、7、30日	活跃用户数	登录人数
 */
-- 建表语句
DROP TABLE IF EXISTS ads_user_stats;
CREATE EXTERNAL TABLE ads_user_stats
(
    `dt`                STRING COMMENT '统计日期',
    `recent_days`       BIGINT COMMENT '最近n日,1:最近1日,7:最近7日,30:最近30日',
    `new_user_count`    BIGINT COMMENT '新增用户数',
    `active_user_count` BIGINT COMMENT '活跃用户数'
) COMMENT '用户新增活跃统计'
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    LOCATION '/warehouse/gmall/ads/ads_user_stats/';
/*
 实现思路：
    1.数据来源，dws_user_user_login_td 用户登录历史至今汇总表
    2.当天的登录人数中包含了注册人数，因为第一次注册也是登录
    3.30天的统计中包含了7天和1天的统计，所以只需要统计30天即可(炸裂函数)
*/
insert overwrite table ads_user_stats
select * from ads_user_stats
union
select
    '2022-06-08' as dt,
    recent_days,
    case recent_days
        when 1 then new_user_count_1d
        when 7 then new_user_count_7d
        when 30 then new_user_count_30d
    end as new_user_count,
    case recent_days
        when 1 then active_user_count_1d
        when 7 then active_user_count_7d
        when 30 then active_user_count_30d
    end as active_user_count
from(
    select
        1,
        sum(if(login_date_first = '2022-06-08', 1, 0)) as new_user_count_1d,   -- 当天注册的用户数(1)
        sum(if(login_date_last = '2022-06-08', 1, 0)) as active_user_count_1d , -- 当天登录的用户数(1)
        7,
        sum(if(login_date_first >= date_sub('2022-06-08',6) and login_date_first <= '2022-06-08', 1, 0))
            as new_user_count_7d, -- 7天内注册的用户数(7)
        sum(if(login_date_last >= date_sub('2022-06-08',6) and login_date_last <= '2022-06-08', 1, 0))
            as active_user_count_7d, -- 7天内登录的用户数(7)
        30,
        sum(if(login_date_first >= date_sub('2022-06-08',29) and login_date_first <= '2022-06-08', 1, 0))
            as new_user_count_30d, -- 30天内注册的用户数(30)
        sum(if(login_date_last >= date_sub('2022-06-08',29) and login_date_last <= '2022-06-08', 1, 0))
            as active_user_count_30d -- 30天内登录的用户数(30)
    from dws_user_user_login_td
    where dt = '2022-06-08'
    and login_date_last >= date_sub('2022-06-08',29) and login_date_last <= '2022-06-08'  -- 30天的登录数据
) t lateral view explode(array(1,7,30)) tmp as recent_days;


--- TODO 需求六: 用户行为漏斗分析
/*
 需求说明：
    统计周期	指标          	说明
    最近1 日	首页浏览人数	    略
    最近1 日	商品详情页浏览人数	略
    最近1 日	加购人数	        略
    最近1 日	下单人数	        略
    最近1 日	支付人数	        支付成功人数

 */
-- 建表语句
DROP TABLE IF EXISTS ads_user_action;
CREATE EXTERNAL TABLE ads_user_action
(
    `dt`                STRING COMMENT '统计日期',
    `home_count`        BIGINT COMMENT '浏览首页人数',
    `good_detail_count` BIGINT COMMENT '浏览商品详情页人数',
    `cart_count`        BIGINT COMMENT '加购人数',
    `order_count`       BIGINT COMMENT '下单人数',
    `payment_count`     BIGINT COMMENT '支付人数'
) COMMENT '用户行为漏斗分析'
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    LOCATION '/warehouse/gmall/ads/ads_user_action/';
/*
 实现思路：
    1.数据来源：
        dws_traffic_page_visitor_page_view_1d(用户页面访问详情1d表)
        dws_trade_user_cart_add_1d(用户加1d表)
        dws_trade_user_order_1d(用户下单1d表)
        dws_trade_user_payment_1d(用户支付1d表)
    2.分别统计首页人数，商品详情页人数，加购人数，下单人数，支付人数，在通过join关联到一起
 */
insert overwrite table ads_user_action
select * from ads_user_action
union
select
    pv.`dt`                ,--STRING COMMENT '统计日期',
    `home_count`        ,--BIGINT COMMENT '浏览首页人数',
    `good_detail_count` ,--BIGINT COMMENT '浏览商品详情页人数',
    `cart_count`        ,--BIGINT COMMENT '加购人数',
    `order_count`       ,--BIGINT COMMENT '下单人数',
    `payment_count`     --BIGINT COMMENT '支付人数'
from (
    select
        '2022-06-08' as dt,
        sum(if(page_id = 'home', 1, 0)) as home_count,
        sum(if(page_id = 'good_detail', 1, 0)) as good_detail_count
    from dws_traffic_page_visitor_page_view_1d
    where dt = '2022-06-08'
    and (page_id = 'home' or page_id like 'good_detail')
) pv
join(
    select
        '2022-06-08' as dt,
        count(*) as cart_count
    from dws_trade_user_cart_add_1d
    where dt = '2022-06-08'
) cart on pv.dt = cart.dt
join(
    select
         '2022-06-08' as dt,
        count(*) as order_count
    from dws_trade_user_order_1d
    where dt = '2022-06-08'
) od on pv.dt = od.dt
join(
    select
         '2022-06-08' as dt,
        count(*) as payment_count
    from dws_trade_user_payment_1d
    where dt = '2022-06-08'
) pay on pv.dt = pay.dt;



--- TODO 需求七: 新增用户下单统计
/*
 需求说明如下
    统计周期	        指标	        说明
    最近1、7、30日	新增下单人数	略
 */
-- 建表语句
DROP TABLE IF EXISTS ads_new_order_user_stats;
CREATE EXTERNAL TABLE ads_new_order_user_stats
(
    `dt`                   STRING COMMENT '统计日期',
    `recent_days`          BIGINT COMMENT '最近天数,1:最近1天,7:最近7天,30:最近30天',
    `new_order_user_count` BIGINT COMMENT '新增下单人数'
) COMMENT '新增下单用户统计'
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    LOCATION '/warehouse/gmall/ads/ads_new_order_user_stats/';
/*
 实现思路：
    1.数据来源：dws_trade_user_order_td(用户下单1d表)
    2.新增下单人数：历史至今第一次下单的用户数
    3.30天内包含7天和1天，读取一次表，使用炸裂函数实现
*/
insert overwrite table ads_new_order_user_stats
select * from ads_new_order_user_stats
union
select
    '2022-06-08',
    recent_days,
    case recent_days
        when 1 then new_order_user_count_1d
        when 7 then new_order_user_count_7d
        when 30 then new_order_user_count_30d
    end as new_order_user_count
from (
    select
        count(`if`(order_date_first = '2022-06-08', user_id, null)) new_order_user_count_1d,
        count(`if`(order_date_first >= date_sub('2022-06-08', 6) and order_date_first <= '2022-06-08', user_id, null)) new_order_user_count_7d,
        count(user_id) new_order_user_count_30d
    from dws_trade_user_order_td
    where dt = '2022-06-08'
    and order_date_first >= date_sub('2022-06-08', 29) and order_date_first <= '2022-06-08'
) t lateral view explode(array(1,7,30)) tmp as recent_days;



--- TODO 需求八: 最近7天内连续3天下单用户数
-- 建表语句
DROP TABLE IF EXISTS ads_order_continuously_user_count;
CREATE EXTERNAL TABLE ads_order_continuously_user_count
(
    `dt`                            STRING COMMENT '统计日期',
    `recent_days`                   BIGINT COMMENT '最近天数,7:最近7天',
    `order_continuously_user_count` BIGINT COMMENT '连续3日下单用户数'
) COMMENT '最近7日内连续3日下单用户数统计'
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    LOCATION '/warehouse/gmall/ads/ads_order_continuously_user_count/';
/*
 实现思路：
    1.数据来源：dws_trade_user_order_1d(用户下单1d表)
    2.取最近7天内的数据，通过开窗函数实现连续3日下单的用户数
    3.开窗函数：
        lead(): 取下面第二行的值   partition by user_id order by dt desc
        求两者之间的插值是否等于2，即为连续3日下单的用户数
    注意：需要去重处理，如果连续3天以上下单，只统计一次
 */
insert overwrite table ads_order_continuously_user_count
select * from ads_order_continuously_user_count
union
select
    '2022-06-08',
    7,
    count(distinct user_id) as order_continuously_user_count
from (
    select
        user_id,
        datediff(dt,lead(dt,1,'0000-00-00') over(partition by user_id order by dt desc)) as diff
    from dws_trade_user_order_1d
    where dt >= date_sub('2022-06-08', 6) and dt <= '2022-06-08'
) t where diff = 2;


------------------------------------------------ 商品主题 ---------------------------------------------------------
--- TODO 需求九: 最近30天各品牌复购率
/*
 需求说明如下。
    统计周期	    统计粒度	    指标	    说明
    最近30日	    品牌	        复购率	重复购买人数占购买人数比例
 */
-- 建表语句
DROP TABLE IF EXISTS ads_repeat_purchase_by_tm;
CREATE EXTERNAL TABLE ads_repeat_purchase_by_tm
(
    `dt`                  STRING COMMENT '统计日期',
    `recent_days`       BIGINT COMMENT '最近天数,30:最近30天',
    `tm_id`              STRING COMMENT '品牌ID',
    `tm_name`            STRING COMMENT '品牌名称',
    `order_repeat_rate` DECIMAL(16, 2) COMMENT '复购率'
) COMMENT '最近30日各品牌复购率统计'
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    LOCATION '/warehouse/gmall/ads/ads_repeat_purchase_by_tm/';
/*
 实现思路：
    1.数据来源：dws_trade_user_sku_order_nd(最近N天用户下单商品明细表)
    2.购买的总人数: 通过品牌分组聚合，统计人数
    3.重复购买的人数：通过品牌分组，求购买次数(根据品牌和用户分组)次数大于1次的人数

    注意：
    数据源粒度：user + sku
    中间结果：user + tm      用户在每个品牌的下单次数
    统计指标： tm        每个品牌中，重复购买人数占购买人数的比例
 */
insert overwrite table ads_repeat_purchase_by_tm
select * from ads_repeat_purchase_by_tm
union
select
    '2022-06-08',
    30,
    tm_id,
    tm_name,
    cast(sum(if(tm_order_count_30d >= 2, 1, 0)) / sum(if(tm_order_count_30d >= 1, 1, 0)) as decimal(16,2)) as repeat_user_count
from(
    -- 购买次数
    select
        tm_id,
        tm_name,
        sum(order_count_30d) as tm_order_count_30d
    from dws_trade_user_sku_order_nd
    where dt = '2022-06-08'
    group by user_id,tm_id,tm_name
) t
group by tm_id,tm_name;




--- TODO 需求十: 各品牌商品下单统计
/*
 需求说明如下
    统计周期	        统计粒度	    指标	    说明
    最近1、7、30日	品牌	        下单数	略
    最近1、7、30日	品牌	        下单人数	略
 */
-- 建表语句
DROP TABLE IF EXISTS ads_order_stats_by_tm;
CREATE EXTERNAL TABLE ads_order_stats_by_tm
(
    `dt`                      STRING COMMENT '统计日期',
    `recent_days`             BIGINT COMMENT '最近天数,1:最近1天,7:最近7天,30:最近30天',
    `tm_id`                   STRING COMMENT '品牌ID',
    `tm_name`                 STRING COMMENT '品牌名称',
    `order_count`             BIGINT COMMENT '下单数',
    `order_user_count`        BIGINT COMMENT '下单人数'
) COMMENT '各品牌商品下单统计'
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    LOCATION '/warehouse/gmall/ads/ads_order_stats_by_tm/';
/*
 实现思路：
    1.数据来源：dws_trade_user_sku_order_nd(最近一天用户下单汇总表)    dws_trade_user_sku_order_nd(最近N天用户下单商品明细表)
    2.数据源的粒度： user+sku  -> user+tm -> 统计每个用户在该品牌的下单数
    3.统计粒度： tm  -> 统计用户人数，7天内的下单数量 >= 1的才算一个下单用户
*/
insert overwrite table ads_order_stats_by_tm
select * from ads_order_stats_by_tm
union
select
    dt,
    recent_days,
    tm_id,
    tm_name,
    order_count,
    order_user_count
from(
    -- 1日
    select
        '2022-06-08' dt,
        1 recent_days,
        tm_id,
        tm_name,
        sum(order_count_1d) order_count,
        count(distinct user_id) order_user_count
    from dws_trade_user_sku_order_1d
    where dt = '2022-06-08'
    group by tm_id,tm_name
    union all
    -- 7天和30天
    select
        '2022-06-08',
        recent_days,
        tm_id,
        tm_name,
        sum(if(recent_days = 7, tm_order_count_7d, tm_order_count_30d)) as order_count, -- 7天和30天下单数
         count(distinct if(recent_days = 7 and tm_order_count_7d >= 1, user_id,
                         if(recent_days = 30 and tm_order_count_30d >= 1, user_id, null))) as order_user_count -- 7天和30天下单人数
    from(
        select
            user_id,
            tm_id,
            tm_name,
            sum(order_count_7d) tm_order_count_7d,    -- 用户7天下单数
            sum(order_count_30d) tm_order_count_30d  -- 用户30天下单数
        from dws_trade_user_sku_order_nd
        group by tm_id,tm_name,user_id
    ) t lateral view explode(array(7,30)) tmp as recent_days
    group by recent_days,tm_id,tm_name
) t1;



--- TODO 需求十一: 各品类商品下单统计
/*
 需求说明如下
    统计周期	        统计粒度	    指标	    说明
    最近1、7、30日	品类	        下单数	略
    最近1、7、30日	品类	        下单人数	略
*/
-- 建表语句
DROP TABLE IF EXISTS ads_order_stats_by_cate;
CREATE EXTERNAL TABLE ads_order_stats_by_cate
(
    `dt`                      STRING COMMENT '统计日期',
    `recent_days`             BIGINT COMMENT '最近天数,1:最近1天,7:最近7天,30:最近30天',
    `category1_id`            STRING COMMENT '一级品类ID',
    `category1_name`          STRING COMMENT '一级品类名称',
    `category2_id`            STRING COMMENT '二级品类ID',
    `category2_name`          STRING COMMENT '二级品类名称',
    `category3_id`            STRING COMMENT '三级品类ID',
    `category3_name`          STRING COMMENT '三级品类名称',
    `order_count`             BIGINT COMMENT '下单数',
    `order_user_count`        BIGINT COMMENT '下单人数'
) COMMENT '各品类商品下单统计'
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    LOCATION '/warehouse/gmall/ads/ads_order_stats_by_cate/';
/*
 实现思路：
    1.数据来源：dws_trade_user_sku_order_nd(最近N天用户商品粒度订单统计表)
    2.数据源的粒度： user+sku  -> user+cate -> 统计每个用户在该品类下的下单数
    3.统计粒度： cate  -> 统计用户人数，7天内的下单数量 >= 1的才算一个下单用户
 */
insert overwrite table ads_order_stats_by_cate
select * from ads_order_stats_by_cate
union
select
    `dt`               ,
    `recent_days`      ,
    `category1_id`     ,
    `category1_name`   ,
    `category2_id`     ,
    `category2_name`   ,
    `category3_id`     ,
    `category3_name`   ,
    `order_count`      ,
    `order_user_count`
from (
    -- 一天
    select
        '2022-06-08' dt,
        1 recent_days,
        category1_id,
        category1_name,
        category2_id,
        category2_name,
        category3_id,
        category3_name,
        sum(order_count_1d) order_count,
        count(distinct user_id) order_user_count
    from dws_trade_user_sku_order_1d
    where dt = '2022-06-08'
    group by category1_id,category1_name,category2_id,category2_name,category3_id,category3_name,user_id
    union all
    -- 7天和30天
    select
        '2022-06-08' dt,
        recent_days,
        category1_id,
        category1_name,
        category2_id,
        category2_name,
        category3_id,
        category3_name,
        sum(`if`(recent_days = 7, cate_order_count_7d,cate_order_count_30d) ) as order_ount,
        count(
        case
            when recent_days = 7  and cate_order_count_7d >= 1  then user_id
            when recent_days = 30 and cate_order_count_30d >= 1 then user_id
        end
        ) as order_user_count
    from (
        select
            user_id,
            '2022-06-08' `dt`    ,
            `category1_id`     ,
            `category1_name`   ,
            `category2_id`     ,
            `category2_name`   ,
            `category3_id`     ,
            `category3_name`   ,
            sum(order_count_7d) `cate_order_count_7d`  , -- 7天下单数
            sum(order_count_30d) `cate_order_count_30d` -- 30天下单数
        from dws_trade_user_sku_order_nd
        where dt = '2022-06-08'
        group by user_id,category1_id,category1_name,category2_id,category2_name,category3_id,category3_name
    ) t1 lateral view explode(array(7,30)) tmp as recent_days
    group by recent_days,category1_id,category1_name,category2_id,category2_name,category3_id,category3_name
) t;



--- TODO 需求十二： 各品类商品购物车存量Top3
-- 建表语句
DROP TABLE IF EXISTS ads_sku_cart_num_top3_by_cate;
CREATE EXTERNAL TABLE ads_sku_cart_num_top3_by_cate
(
    `dt`             STRING COMMENT '统计日期',
    `category1_id`   STRING COMMENT '一级品类ID',
    `category1_name` STRING COMMENT '一级品类名称',
    `category2_id`   STRING COMMENT '二级品类ID',
    `category2_name` STRING COMMENT '二级品类名称',
    `category3_id`   STRING COMMENT '三级品类ID',
    `category3_name` STRING COMMENT '三级品类名称',
    `sku_id`         STRING COMMENT 'SKU_ID',
    `sku_name`       STRING COMMENT 'SKU名称',
    `cart_num`       BIGINT COMMENT '购物车中商品数量',
    `rk`             BIGINT COMMENT '排名'
) COMMENT '各品类商品购物车存量Top3'
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    LOCATION '/warehouse/gmall/ads/ads_sku_cart_num_top3_by_cate/';
/*
 实现思路：
    1.数据来源：dwd_trade_cart_full(购物车周期快照事实表) + dim_sku_full(商品维度表)
    2.根据品类进行分组聚合商品数量
    3.使用开窗函数rank统计排名，并过滤出前三
 */
insert overwrite table ads_sku_cart_num_top3_by_cate
select * from ads_sku_cart_num_top3_by_cate
union
select
    `dt`             ,--STRING COMMENT '统计日期',
    `category1_id`   ,--STRING COMMENT '一级品类ID',
    `category1_name` ,--STRING COMMENT '一级品类名称',
    `category2_id`   ,--STRING COMMENT '二级品类ID',
    `category2_name` ,--STRING COMMENT '二级品类名称',
    `category3_id`   ,--STRING COMMENT '三级品类ID',
    `category3_name` ,--STRING COMMENT '三级品类名称',
    `sku_id`         ,--STRING COMMENT 'SKU_ID',
    `sku_name`       ,--STRING COMMENT 'SKU名称',
    `cart_num`       ,--BIGINT COMMENT '购物车中商品数量',
    `rk`             --BIGINT COMMENT '排名'
from (
    select
        '2022-06-08' dt            ,--STRING COMMENT '统计日期',
        `category1_id`   ,--STRING COMMENT '一级品类ID',
        `category1_name` ,--STRING COMMENT '一级品类名称',
        `category2_id`   ,--STRING COMMENT '二级品类ID',
        `category2_name` ,--STRING COMMENT '二级品类名称',
        `category3_id`   ,--STRING COMMENT '三级品类ID',
        `category3_name` ,--STRING COMMENT '三级品类名称',
        `sku_id`         ,--STRING COMMENT 'SKU_ID',
        `sku_name`       ,--STRING COMMENT 'SKU名称',
        sum( sku_num )`cart_num`       ,--BIGINT COMMENT '购物车中商品数量',
        rank() over (partition by category3_id order by sum( sku_num ) desc )`rk`             --BIGINT COMMENT '排名'
    from(
        select
            sku_id,
            sku_num
        from dwd_trade_cart_full
    ) cart
    left join (
        select
            id,
            `category1_id`   ,
            `category1_name` ,
            `category2_id`   ,
            `category2_name` ,
            `category3_id`   ,
            `category3_name` ,
            `sku_name`
        from dim_sku_full
    ) sku on cart.sku_id = sku.id
    group by category1_id,category1_name,category2_id,category2_name,category3_id,category3_name,sku_id,sku_name
) t where t.rk <= 3;



--- TODO 需求十三： 各品牌商品收藏次数Top3
-- 建表语句
DROP TABLE IF EXISTS ads_sku_favor_count_top3_by_tm;
CREATE EXTERNAL TABLE ads_sku_favor_count_top3_by_tm
(
    `dt`          STRING COMMENT '统计日期',
    `tm_id`       STRING COMMENT '品牌ID',
    `tm_name`     STRING COMMENT '品牌名称',
    `sku_id`      STRING COMMENT 'SKU_ID',
    `sku_name`    STRING COMMENT 'SKU名称',
    `favor_count` BIGINT COMMENT '被收藏次数',
    `rk`          BIGINT COMMENT '排名'
) COMMENT '各品牌商品收藏次数Top3'
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    LOCATION '/warehouse/gmall/ads/ads_sku_favor_count_top3_by_tm/';
/*
 实现思路：
    1.数据来源：dws_interaction_sku_favor_add_1d(商品粒度收藏商品一日表)
    2.根据(品牌 + 商品) -> 存在所属关系(商品属于品牌) -> 商品 ->  粒度进行统计数量
    3.根据开窗函数进行排序
*/
insert overwrite table ads_sku_favor_count_top3_by_tm
select * from ads_sku_favor_count_top3_by_tm
union
select
    '2022-06-08' dt,
    tm_id,
    tm_name,
    sku_id,
    sku_name,
    favor_add_count_1d,
    rk
from
(
    select
        tm_id,
        tm_name,
        sku_id,
        sku_name,
        favor_add_count_1d,
        rank() over (partition by tm_id order by favor_add_count_1d desc) rk
    from dws_interaction_sku_favor_add_1d
    where dt='2022-06-08'
)t1
where rk<=3;





-------------------------------------------------- 交易主题  -------------------------------------------------------------
--- TODO 需求十四: 下单到支付间隔时间的平均值
/*
 指标说明: 最近1日完成支付的订单的下单时间到支付时间的时间间隔的平均值。
 */
-- 建表语句
DROP TABLE IF EXISTS ads_order_to_pay_interval_avg;
CREATE EXTERNAL TABLE ads_order_to_pay_interval_avg
(
    `dt`                        STRING COMMENT '统计日期',
    `order_to_pay_interval_avg` BIGINT COMMENT '下单到支付时间间隔平均值,单位为秒'
) COMMENT '下单到支付时间间隔平均值统计'
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    LOCATION '/warehouse/gmall/ads/ads_order_to_pay_interval_avg/';
/*
 实现思路：
    1.数据来源：dwd_trade_trade_flow_acc(交易域交易流程累计快照事实表)
    2.先过滤出已经支付的流程
    3.计算下单到支付的间隔时间

 注意点：
    我们需要的交易流程是最近一天刚好支付的流程，dwd_trade_trade_flow_acc但是这个表是按照完成时间分区的(支付完不一定完成，需要发货)
    where dt in ('2022-06-08','9999-12-31')
        -- 9999-12-31表示未完成, 2022-06-08表示完成(可能当天支付当天送到完成)
 */
insert overwrite table ads_order_to_pay_interval_avg
select * from ads_order_to_pay_interval_avg
union
select
    '2022-06-08' dt,
    cast(avg(to_unix_timestamp(payment_time)-to_unix_timestamp(order_time)) as bigint)
from dwd_trade_trade_flow_acc
where dt in ('9999-12-31','2022-06-08')
and payment_date_id='2022-06-08';



--- TODO 需求十五：各省份交易统计
/*
需求说明如下。
    统计周期	        统计粒度	指标	    说明
    最近1、7、30日	省份	    订单数	略
    最近1、7、30日	省份	    订单金额	略
*/
-- 建表语句
DROP TABLE IF EXISTS ads_order_by_province;
CREATE EXTERNAL TABLE ads_order_by_province
(
    `dt`                 STRING COMMENT '统计日期',
    `recent_days`        BIGINT COMMENT '最近天数,1:最近1天,7:最近7天,30:最近30天',
    `province_id`        STRING COMMENT '省份ID',
    `province_name`      STRING COMMENT '省份名称',
    `area_code`          STRING COMMENT '地区编码',
    `iso_code`           STRING COMMENT '旧版国际标准地区编码，供可视化使用',
    `iso_code_3166_2`    STRING COMMENT '新版国际标准地区编码，供可视化使用',
    `order_count`        BIGINT COMMENT '订单数',
    `order_total_amount` DECIMAL(16, 2) COMMENT '订单金额'
) COMMENT '各省份交易统计'
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    LOCATION '/warehouse/gmall/ads/ads_order_by_province/';
/*
 实现思路：
    1.数据来源：dws_trade_province_order_nd(交易域省份订单最近N日统计表) dws_trade_province_order_1d(交易域省份订单最近1日统计表)
    2.1天 -> 过滤出当天的订单数据 -> 直接可以使用(统计粒度没有变化，不需要进一步聚合)
    3.7天，30天 -> nd表 -> 数据包含7天和30天 -> 炸裂函数 -> 分别使用
*/

insert overwrite table ads_order_by_province
select * from ads_order_by_province
union
-- 1天
select
    `dt`                 ,
    1 `recent_days`      ,
    `province_id`        ,
    `province_name`      ,
    `area_code`          ,
    `iso_code`           ,
    iso_3166_2 `iso_code_3166_2`    ,
    order_count_1d `order_count`        ,
    order_total_amount_1d `order_total_amount`
from dws_trade_province_order_1d
where dt = '2022-06-08'
union
-- 7天和30天
select
    `dt`                ,
    recent_days,
    `province_id`       ,
    `province_name`     ,
    `area_code`         ,
    `iso_code`          ,
    iso_3166_2,
    `if`(recent_days = 7,order_count_7d,order_count_30d) `order_count`,
    `if`(recent_days = 7,order_total_amount_7d,order_total_amount_30d) `order_total_amount`
from(
    select
        `dt`                ,
        `province_id`       ,
        `province_name`     ,
        `area_code`         ,
        `iso_code`          ,
        iso_3166_2,
        order_count_7d,
        order_total_amount_7d,
        order_count_30d,
        order_total_amount_30d
    from dws_trade_province_order_nd
    where dt = '2022-06-08'
) t lateral view explode(array(7,30)) tmp as recent_days;



-------------------------------------------------- 优惠卷主题 ------------------------------------------------------------
--- TODO 需求十六：优惠卷使用统计
/*
 需求说明如下。
    统计周期	统计粒度	指标	说明
    最近1日	优惠券	使用次数	支付才算使用
    最近1日	优惠券	使用人数	支付才算使用
*/
-- 建表语句
DROP TABLE IF EXISTS ads_coupon_stats;
CREATE EXTERNAL TABLE ads_coupon_stats
(
    `dt`              STRING COMMENT '统计日期',
    `coupon_id`       STRING COMMENT '优惠券ID',
    `coupon_name`     STRING COMMENT '优惠券名称',
    `used_count`      BIGINT COMMENT '使用次数',
    `used_user_count` BIGINT COMMENT '使用人数'
) COMMENT '优惠券使用统计'
    ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
    LOCATION '/warehouse/gmall/ads/ads_coupon_stats/';
/*
 实现思路：
    1.数据源：dws_tool_user_coupon_coupon_used_1d(工具域用户优惠卷粒度优惠券使用最近1日统计表)
    2.数据源粒度：user + coupon  -> 统计粒度：coupon
    3.使用人数； 根据coupon分组，聚合人数
    4.使用次数：sum(用户使用次数)
*/
insert overwrite table ads_coupon_stats
select * from ads_coupon_stats
union
select
    '2022-06-08' dt,
    coupon_id,
    coupon_name,
    cast(sum(used_count_1d) as bigint) used_count,
    cast(count(user_id) as bigint) used_user_count
from dws_tool_user_coupon_coupon_used_1d
where dt = '2022-06-08'
group by coupon_id,coupon_name;


