-- ===================================================
-- ODS 层数据装载：业务数据
-- 用途：将 HDFS 原始数据装载到 ODS 表分区
-- 参数：${do_date} — 日期，格式 yyyy-MM-dd
-- ===================================================

-- ==================== 全量表装载 ====================

LOAD DATA INPATH '/origin_data/gmall/db/activity_info_full/${do_date}'
OVERWRITE INTO TABLE gmall.ods_activity_info_full
PARTITION (dt = '${do_date}');

LOAD DATA INPATH '/origin_data/gmall/db/activity_rule_full/${do_date}'
OVERWRITE INTO TABLE gmall.ods_activity_rule_full
PARTITION (dt = '${do_date}');

LOAD DATA INPATH '/origin_data/gmall/db/base_category1_full/${do_date}'
OVERWRITE INTO TABLE gmall.ods_base_category1_full
PARTITION (dt = '${do_date}');

LOAD DATA INPATH '/origin_data/gmall/db/base_category2_full/${do_date}'
OVERWRITE INTO TABLE gmall.ods_base_category2_full
PARTITION (dt = '${do_date}');

LOAD DATA INPATH '/origin_data/gmall/db/base_category3_full/${do_date}'
OVERWRITE INTO TABLE gmall.ods_base_category3_full
PARTITION (dt = '${do_date}');

LOAD DATA INPATH '/origin_data/gmall/db/base_dic_full/${do_date}'
OVERWRITE INTO TABLE gmall.ods_base_dic_full
PARTITION (dt = '${do_date}');

LOAD DATA INPATH '/origin_data/gmall/db/base_province_full/${do_date}'
OVERWRITE INTO TABLE gmall.ods_base_province_full
PARTITION (dt = '${do_date}');

LOAD DATA INPATH '/origin_data/gmall/db/base_region_full/${do_date}'
OVERWRITE INTO TABLE gmall.ods_base_region_full
PARTITION (dt = '${do_date}');

LOAD DATA INPATH '/origin_data/gmall/db/base_trademark_full/${do_date}'
OVERWRITE INTO TABLE gmall.ods_base_trademark_full
PARTITION (dt = '${do_date}');

LOAD DATA INPATH '/origin_data/gmall/db/cart_info_full/${do_date}'
OVERWRITE INTO TABLE gmall.ods_cart_info_full
PARTITION (dt = '${do_date}');

LOAD DATA INPATH '/origin_data/gmall/db/coupon_info_full/${do_date}'
OVERWRITE INTO TABLE gmall.ods_coupon_info_full
PARTITION (dt = '${do_date}');

LOAD DATA INPATH '/origin_data/gmall/db/sku_attr_value_full/${do_date}'
OVERWRITE INTO TABLE gmall.ods_sku_attr_value_full
PARTITION (dt = '${do_date}');

LOAD DATA INPATH '/origin_data/gmall/db/sku_info_full/${do_date}'
OVERWRITE INTO TABLE gmall.ods_sku_info_full
PARTITION (dt = '${do_date}');

LOAD DATA INPATH '/origin_data/gmall/db/sku_sale_attr_value_full/${do_date}'
OVERWRITE INTO TABLE gmall.ods_sku_sale_attr_value_full
PARTITION (dt = '${do_date}');

LOAD DATA INPATH '/origin_data/gmall/db/spu_info_full/${do_date}'
OVERWRITE INTO TABLE gmall.ods_spu_info_full
PARTITION (dt = '${do_date}');

LOAD DATA INPATH '/origin_data/gmall/db/promotion_pos_full/${do_date}'
OVERWRITE INTO TABLE gmall.ods_promotion_pos_full
PARTITION (dt = '${do_date}');

LOAD DATA INPATH '/origin_data/gmall/db/promotion_refer_full/${do_date}'
OVERWRITE INTO TABLE gmall.ods_promotion_refer_full
PARTITION (dt = '${do_date}');

-- ==================== 增量表装载 ====================

LOAD DATA INPATH '/origin_data/gmall/db/cart_info_inc/${do_date}'
OVERWRITE INTO TABLE gmall.ods_cart_info_inc
PARTITION (dt = '${do_date}');

LOAD DATA INPATH '/origin_data/gmall/db/comment_info_inc/${do_date}'
OVERWRITE INTO TABLE gmall.ods_comment_info_inc
PARTITION (dt = '${do_date}');

LOAD DATA INPATH '/origin_data/gmall/db/coupon_use_inc/${do_date}'
OVERWRITE INTO TABLE gmall.ods_coupon_use_inc
PARTITION (dt = '${do_date}');

LOAD DATA INPATH '/origin_data/gmall/db/favor_info_inc/${do_date}'
OVERWRITE INTO TABLE gmall.ods_favor_info_inc
PARTITION (dt = '${do_date}');

LOAD DATA INPATH '/origin_data/gmall/db/order_detail_inc/${do_date}'
OVERWRITE INTO TABLE gmall.ods_order_detail_inc
PARTITION (dt = '${do_date}');

LOAD DATA INPATH '/origin_data/gmall/db/order_detail_activity_inc/${do_date}'
OVERWRITE INTO TABLE gmall.ods_order_detail_activity_inc
PARTITION (dt = '${do_date}');

LOAD DATA INPATH '/origin_data/gmall/db/order_detail_coupon_inc/${do_date}'
OVERWRITE INTO TABLE gmall.ods_order_detail_coupon_inc
PARTITION (dt = '${do_date}');

LOAD DATA INPATH '/origin_data/gmall/db/order_info_inc/${do_date}'
OVERWRITE INTO TABLE gmall.ods_order_info_inc
PARTITION (dt = '${do_date}');

LOAD DATA INPATH '/origin_data/gmall/db/order_refund_info_inc/${do_date}'
OVERWRITE INTO TABLE gmall.ods_order_refund_info_inc
PARTITION (dt = '${do_date}');

LOAD DATA INPATH '/origin_data/gmall/db/order_status_log_inc/${do_date}'
OVERWRITE INTO TABLE gmall.ods_order_status_log_inc
PARTITION (dt = '${do_date}');

LOAD DATA INPATH '/origin_data/gmall/db/payment_info_inc/${do_date}'
OVERWRITE INTO TABLE gmall.ods_payment_info_inc
PARTITION (dt = '${do_date}');

LOAD DATA INPATH '/origin_data/gmall/db/refund_payment_inc/${do_date}'
OVERWRITE INTO TABLE gmall.ods_refund_payment_inc
PARTITION (dt = '${do_date}');

LOAD DATA INPATH '/origin_data/gmall/db/user_info_inc/${do_date}'
OVERWRITE INTO TABLE gmall.ods_user_info_inc
PARTITION (dt = '${do_date}');
