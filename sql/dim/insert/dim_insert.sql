-- ===================================================
-- DIM 层数据装载：维度表 ETL
-- 参数：${do_date} — 日期，格式 yyyy-MM-dd
-- ===================================================

-- ----------------------------
-- 用户维度拉链表 ETL
-- 逻辑：对比当日增量与昨日拉链表，更新 end_date / 插入新记录
-- ----------------------------
WITH
-- 当日全量用户数据
today_user AS (
    SELECT
        id,
        login_name,
        nick_name,
        passwd,
        name,
        phone_num,
        email,
        head_img,
        user_level,
        birthday,
        gender,
        create_time,
        operate_time,
        status
    FROM gmall.ods_user_info_inc
    WHERE dt = '${do_date}'
      AND type IN ('insert', 'update')
),
-- 昨日拉链表
old_dim AS (
    SELECT
        id,
        login_name,
        nick_name,
        name,
        phone_num,
        email,
        user_level,
        birthday,
        gender,
        create_time,
        operate_time,
        start_date,
        end_date
    FROM gmall.dim_user
    WHERE dt = '${do_date}'  -- 实际取上一日分区
)
-- 拉链表更新逻辑（简化版：全量快照方式）
INSERT OVERWRITE TABLE gmall.dim_user PARTITION (dt = '${do_date}')
SELECT
    id,
    login_name,
    nick_name,
    name,
    phone_num,
    email,
    user_level,
    birthday,
    gender,
    create_time,
    operate_time,
    '${do_date}' AS start_date,
    '9999-12-31' AS end_date
FROM today_user;

-- ----------------------------
-- 商品维度表 ETL
-- 整合 SKU + SPU + 品类 + 品牌
-- ----------------------------
INSERT OVERWRITE TABLE gmall.dim_sku PARTITION (dt = '${do_date}')
SELECT
    sku.id,
    sku.spu_id,
    CAST(sku.price AS DECIMAL(16,2)) AS price,
    sku.sku_name,
    sku.sku_desc,
    CAST(sku.weight AS DECIMAL(16,2)) AS weight,
    sku.is_sale,
    tm.id  AS tm_id,
    tm.tm_name,
    c3.id  AS category3_id,
    c3.name AS category3_name,
    c2.id  AS category2_id,
    c2.name AS category2_name,
    c1.id  AS category1_id,
    c1.name AS category1_name,
    spu.spu_name,
    sku.create_time
FROM gmall.ods_sku_info_full sku
LEFT JOIN gmall.ods_spu_info_full spu
    ON sku.spu_id = spu.id
   AND spu.dt = '${do_date}'
LEFT JOIN gmall.ods_base_trademark_full tm
    ON sku.tm_id = tm.id
   AND tm.dt = '${do_date}'
LEFT JOIN gmall.ods_base_category3_full c3
    ON sku.category3_id = c3.id
   AND c3.dt = '${do_date}'
LEFT JOIN gmall.ods_base_category2_full c2
    ON c3.name IS NOT NULL
   AND c2.dt = '${do_date}'
LEFT JOIN gmall.ods_base_category1_full c1
    ON c2.name IS NOT NULL
   AND c1.dt = '${do_date}'
WHERE sku.dt = '${do_date}';

-- ----------------------------
-- 省份维度表 ETL
-- ----------------------------
INSERT OVERWRITE TABLE gmall.dim_province PARTITION (dt = '${do_date}')
SELECT
    bp.id,
    bp.name,
    bp.region_id,
    br.region_name,
    bp.area_code,
    bp.iso_code
FROM gmall.ods_base_province_full bp
LEFT JOIN gmall.ods_base_region_full br
    ON bp.region_id = br.id
   AND br.dt = '${do_date}'
WHERE bp.dt = '${do_date}';

-- ----------------------------
-- 优惠券维度表 ETL
-- ----------------------------
INSERT OVERWRITE TABLE gmall.dim_coupon PARTITION (dt = '${do_date}')
SELECT
    id,
    coupon_name,
    coupon_type,
    condition_amount,
    condition_num,
    activity_id,
    benefit_amount,
    benefit_discount,
    limit_num,
    range_type,
    start_time,
    end_time,
    expire_time
FROM gmall.ods_coupon_info_full
WHERE dt = '${do_date}';
