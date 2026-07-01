-- ===================================================
-- DIM 层数据装载：维度表 ETL
-- 参数：${do_date} — 日期，格式 yyyy-MM-dd
-- ===================================================

-- -------------------------------------------------
-- 1. 商品维度表 ETL
-- 整合 SKU + SPU + 品类 + 品牌 + 平台属性 + 销售属性
-- -------------------------------------------------
INSERT OVERWRITE TABLE gmall.dim_sku_full PARTITION (dt = '${do_date}')
SELECT
    sku.`id`,
    `price`,
    `sku_name`,
    `sku_desc`,
    `weight`,
    `is_sale`,
    `spu_id`,
    `spu_name`,
    `category3_id`,
    `category3_name`,
    `category2_id`,
    `category2_name`,
    `category1_id`,
    `category1_name`,
    `tm_id`,
    `tm_name`,
    `sku_attr_values`,
    `sku_sale_attr_values`,
    `create_time`
FROM (
    SELECT
        `id`,
        `price`,
        `sku_name`,
        `sku_desc`,
        `weight`,
        `is_sale`,
        `spu_id`,
        `category3_id`,
        `tm_id`,
        create_time
    FROM gmall.ods_sku_info_full
    WHERE dt = '${do_date}'
) AS sku
LEFT JOIN (
    SELECT id, spu_name
    FROM gmall.ods_spu_info_full
    WHERE dt = '${do_date}'
) AS spu ON sku.spu_id = spu.id
LEFT JOIN (
    SELECT id, name AS category3_name, category2_id
    FROM gmall.ods_base_category3_full
    WHERE dt = '${do_date}'
) AS c3 ON sku.category3_id = c3.id
LEFT JOIN (
    SELECT id, name AS category2_name, category1_id
    FROM gmall.ods_base_category2_full
    WHERE dt = '${do_date}'
) AS c2 ON c3.category2_id = c2.id
LEFT JOIN (
    SELECT id, name AS category1_name
    FROM gmall.ods_base_category1_full
    WHERE dt = '${do_date}'
) AS c1 ON c2.category1_id = c1.id
LEFT JOIN (
    SELECT id, tm_name
    FROM gmall.ods_base_trademark_full
    WHERE dt = '${do_date}'
) AS tm ON sku.tm_id = tm.id
LEFT JOIN (
    SELECT
        sku_id,
        collect_list(named_struct("attr_id",attr_id,"value_id",value_id,"attr_name",attr_name,"value_name",value_name)) AS sku_attr_values
    FROM gmall.ods_sku_attr_value_full
    WHERE dt = '${do_date}'
    GROUP BY sku_id
) AS attrs ON sku.id = attrs.sku_id
LEFT JOIN (
    SELECT
        sku_id,
        collect_list(named_struct("sale_attr_id",sale_attr_id,"sale_attr_value_id",sale_attr_value_id,"sale_attr_name",sale_attr_name,"sale_attr_value_name",sale_attr_value_name)) AS sku_sale_attr_values
    FROM gmall.ods_sku_sale_attr_value_full
    WHERE dt = '${do_date}'
    GROUP BY sku_id
) AS sale ON sale.sku_id = sku.id;

-- -------------------------------------------------
-- 2. 优惠券维度表 ETL
-- 关联字典表获取类型名称和范围名称，计算优惠规则
-- -------------------------------------------------
INSERT OVERWRITE TABLE gmall.dim_coupon_full PARTITION (dt = '${do_date}')
SELECT
    `id`,
    `coupon_name`,
    `coupon_type_code`,
    `coupon_type_name`,
    `condition_amount`,
    `condition_num`,
    `activity_id`,
    `benefit_amount`,
    `benefit_discount`,
    CASE coupon_type_code
        WHEN '3201' THEN concat('满',condition_amount,'元减',benefit_amount,'元')
        WHEN '3202' THEN concat('满',condition_num,'件打',benefit_discount,'折')
        WHEN '3203' THEN concat('无门槛减',benefit_amount,'元')
    END `benefit_rule`,
    `create_time`,
    `range_type_code`,
    `range_type_name`,
    `limit_num`,
    `taken_count`,
    `start_time`,
    `end_time`,
    `operate_time`,
    `expire_time`
FROM (
    SELECT
        `id`,
        `coupon_name`,
        coupon_type `coupon_type_code`,
        `condition_amount`,
        `condition_num`,
        `activity_id`,
        `benefit_amount`,
        `benefit_discount`,
        `create_time`,
        range_type `range_type_code`,
        `limit_num`,
        `taken_count`,
        `start_time`,
        `end_time`,
        `operate_time`,
        `expire_time`
    FROM gmall.ods_coupon_info_full
    WHERE dt = '${do_date}'
) AS coupon
LEFT JOIN (
    SELECT dic_code, dic_name AS coupon_type_name
    FROM gmall.ods_base_dic_full
    WHERE dt = '${do_date}' AND parent_code = '32'
) AS dic1 ON dic1.dic_code = coupon.coupon_type_code
LEFT JOIN (
    SELECT dic_code, dic_name AS range_type_name
    FROM gmall.ods_base_dic_full
    WHERE dt = '${do_date}' AND parent_code = '33'
) AS dic2 ON dic2.dic_code = coupon.range_type_code;

-- -------------------------------------------------
-- 3. 活动维度表 ETL
-- 活动规则为主维表，关联活动信息表 + 字典表
-- -------------------------------------------------
INSERT OVERWRITE TABLE gmall.dim_activity_full PARTITION (dt = '${do_date}')
SELECT
    `activity_rule_id`,
    `activity_id`,
    `activity_name`,
    `activity_type_code`,
    `activity_type_name`,
    `activity_desc`,
    `start_time`,
    `end_time`,
    `create_time`,
    `condition_amount`,
    `condition_num`,
    `benefit_amount`,
    `benefit_discount`,
    `benefit_rule`,
    `benefit_level`
FROM (
    SELECT
        id `activity_rule_id`,
        `activity_id`,
        activity_type `activity_type_code`,
        `create_time`,
        `condition_amount`,
        `condition_num`,
        `benefit_amount`,
        `benefit_discount`,
        CASE activity_type
            WHEN '3101' THEN concat('满',condition_amount,'元减',benefit_amount,'元')
            WHEN '3102' THEN concat('满',condition_num,'件打',benefit_discount,'折')
            WHEN '3103' THEN concat('无门槛打',benefit_discount,'折')
        END `benefit_rule`,
        `benefit_level`
    FROM gmall.ods_activity_rule_full
    WHERE dt = '${do_date}'
) AS rule
LEFT JOIN (
    SELECT id, activity_name, activity_desc, start_time, end_time
    FROM gmall.ods_activity_info_full
    WHERE dt = '${do_date}'
) AS info ON rule.activity_id = info.id
LEFT JOIN (
    SELECT dic_code, dic_name AS activity_type_name
    FROM gmall.ods_base_dic_full
    WHERE dt = '${do_date}' AND parent_code = '31'
) AS dic ON rule.activity_type_code = dic.dic_code;

-- -------------------------------------------------
-- 4. 省份维度表 ETL
-- -------------------------------------------------
INSERT OVERWRITE TABLE gmall.dim_province_full PARTITION (dt = '${do_date}')
SELECT
    prv.`id`,
    `province_name`,
    `area_code`,
    `iso_code`,
    `iso_3166_2`,
    `region_id`,
    `region_name`
FROM (
    SELECT
        `id`,
        name `province_name`,
        `area_code`,
        `iso_code`,
        `iso_3166_2`,
        `region_id`
    FROM gmall.ods_base_province_full
    WHERE dt = '${do_date}'
) AS prv
LEFT JOIN (
    SELECT id, region_name
    FROM gmall.ods_base_region_full
    WHERE dt = '${do_date}'
) AS region ON prv.region_id = region.id;

-- -------------------------------------------------
-- 5. 营销坑位维度表 ETL
-- -------------------------------------------------
INSERT OVERWRITE TABLE gmall.dim_promotion_pos_full PARTITION (dt = '${do_date}')
SELECT
    `id`,
    `pos_location`,
    `pos_type`,
    `promotion_type`,
    `create_time`,
    `operate_time`
FROM gmall.ods_promotion_pos_full
WHERE dt = '${do_date}';

-- -------------------------------------------------
-- 6. 营销渠道维度表 ETL
-- -------------------------------------------------
INSERT OVERWRITE TABLE gmall.dim_promotion_refer_full PARTITION (dt = '${do_date}')
SELECT
    `id`,
    `refer_name`,
    `create_time`,
    `operate_time`
FROM gmall.ods_promotion_refer_full
WHERE dt = '${do_date}';

-- -------------------------------------------------
-- 7. 日期维度表 ETL
-- 数据从临时表 tmp_dim_date_info 导入（仅首次执行）
-- -------------------------------------------------
-- 注：日期维度表只需初始化一次，日常调度不执行
-- INSERT OVERWRITE TABLE gmall.dim_date SELECT * FROM gmall.tmp_dim_date_info;

-- -------------------------------------------------
-- 8. 用户维度拉链表 ETL（重难点）
-- 首日全量：type='bootstrap-insert'，所有用户 start_date=首日, end_date='9999-12-31'
-- 每日增量：对比当日变更与当前有效状态，更新旧记录 end_date，插入新记录
-- -------------------------------------------------

-- 8.1 首日全量装载（仅首次执行，type='bootstrap-insert'）
-- INSERT OVERWRITE TABLE gmall.dim_user_zip PARTITION (dt = '9999-12-31')
-- SELECT
--     data.`id`,
--     data.`login_name`,
--     data.`nick_name`,
--     data.`name`,
--     data.`phone_num`,
--     data.`email`,
--     data.`user_level`,
--     data.`birthday`,
--     data.`gender`,
--     data.`create_time`,
--     data.`operate_time`,
--     '${do_date}' `start_date`,
--     '9999-12-31' `end_date`
-- FROM gmall.ods_user_info_inc
-- WHERE dt = '${do_date}'
--   AND type = 'bootstrap-insert';

-- 8.2 每日增量装载
-- 逻辑：
--   1) 取 dt='9999-12-31' 分区的当前有效记录
--   2) UNION 当日变更（ods_user_info_inc 中 type IN ('insert','update')）
--   3) 按 id 分组，start_date DESC 排序，rn=1 的为新状态（end_date='9999-12-31'），
--      rn=2 的为旧状态（end_date = do_date - 1天）
--   4) 动态分区写入：end_date='9999-12-31' → 写入 9999-12-31 分区，
--      其他 end_date → 写入对应日期分区
INSERT OVERWRITE TABLE gmall.dim_user_zip PARTITION (dt)
SELECT
    `id`,
    `login_name`,
    `nick_name`,
    `name`,
    `phone_num`,
    `email`,
    `user_level`,
    `birthday`,
    `gender`,
    `create_time`,
    `operate_time`,
    `start_date`,
    IF(rn = 1, '9999-12-31', date_sub('${do_date}', 1)) `end_date`,
    IF(rn = 1, '9999-12-31', date_sub('${do_date}', 1)) AS dt
FROM (
    SELECT
        `id`,
        `login_name`,
        `nick_name`,
        `name`,
        `phone_num`,
        `email`,
        `user_level`,
        `birthday`,
        `gender`,
        `create_time`,
        `operate_time`,
        `start_date`,
        `end_date`,
        row_number() OVER (PARTITION BY id ORDER BY start_date DESC) rn
    FROM (
        -- 当前有效记录（9999-12-31 分区）
        SELECT
            `id`,
            `login_name`,
            `nick_name`,
            `name`,
            `phone_num`,
            `email`,
            `user_level`,
            `birthday`,
            `gender`,
            `create_time`,
            `operate_time`,
            `start_date`,
            `end_date`
        FROM gmall.dim_user_zip
        WHERE dt = '9999-12-31'
        UNION
        -- 当日增量数据（取每个用户最新的一条变更）
        SELECT
            data.`id`,
            data.`login_name`,
            data.`nick_name`,
            data.`name`,
            data.`phone_num`,
            data.`email`,
            data.`user_level`,
            data.`birthday`,
            data.`gender`,
            data.`create_time`,
            data.`operate_time`,
            '${do_date}' `start_date`,
            '9999-12-31' `end_date`
        FROM (
            SELECT
                data,
                row_number() OVER (PARTITION BY data.id ORDER BY ts DESC) rn
            FROM gmall.ods_user_info_inc
            WHERE dt = '${do_date}'
        ) tmp
        WHERE tmp.rn = 1
    ) t1
) t2;
