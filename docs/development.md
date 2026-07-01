# 开发规范

## 概述

本文档定义了 GMall 离线数据仓库项目的开发规范，确保代码风格统一、可维护性强、团队协作高效。

---

## 一、命名规范

### 1.1 数据库命名

| 对象 | 规范 | 示例 |
|------|------|------|
| 数据库名 | 小写 + 下划线 | `gmall` |
| Hive 库名 | 小写 | `gmall` |
| 报表库名 | 小写 + 下划线 | `gmall_report` |

### 1.2 表命名

```
{层级}_{主题域}_{业务过程}_{周期标识}
```

| 层级 | 前缀 | 示例 |
|------|------|------|
| ODS | `ods_` | `ods_order_info_full`, `ods_log_inc` |
| DIM | `dim_` | `dim_user_zip`, `dim_sku_full`, `dim_coupon_full` |
| DWD | `dwd_` | `dwd_trade_order_detail_inc`, `dwd_traffic_page_view_inc` |
| DWS | `dws_` | `dws_trade_user_sku_order_1d`, `dws_trade_user_sku_order_nd` |
| ADS | `ads_` | `ads_traffic_stats_by_channel` |

**周期标识**：

| 标识 | 含义 |
|------|------|
| `full` | 全量快照 |
| `inc` | 增量数据 |
| `1d` | 最近 1 天 |
| `nd` | 最近 N 天（7/30） |
| `td` | 历史累计至今 |

### 1.3 字段命名

- 使用**小写 + 下划线**：`user_id`, `create_time`, `order_amount`
- 布尔字段使用 `is_` 前缀：`is_new`, `is_checked`, `is_cancel`
- 时间字段统一后缀：`_time`（时间戳毫秒）、`_date`（日期字符串）
- 金额字段使用 `_amount`：`total_amount`, `reduce_amount`

---

## 二、SQL 编写规范

### 2.1 风格规范

```sql
-- 关键字大写，字段名/表名小写
-- 复杂查询添加注释
-- 缩进使用 4 个空格

SELECT
    t1.user_id,
    t1.order_count,
    t2.user_level,
    t2.gender
FROM (
    SELECT
        user_id,
        COUNT(DISTINCT order_id) AS order_count
    FROM gmall.dwd_trade_order_detail_inc
    WHERE dt = '2022-06-08'
    GROUP BY user_id
) t1
LEFT JOIN gmall.dim_user_zip t2
    ON t1.user_id = t2.id
   AND t2.end_date = '9999-12-31'  -- 拉链表取当前有效记录
;
```

### 2.2 DDL 规范

```sql
-- 1. 建表前先 DROP IF EXISTS
DROP TABLE IF EXISTS gmall.dwd_xxx;

-- 2. 使用 CREATE EXTERNAL TABLE（外部表）
CREATE EXTERNAL TABLE gmall.dwd_xxx
(
    `id`        STRING COMMENT '主键ID',
    `name`      STRING COMMENT '名称',
    ...
)
COMMENT '表说明'
PARTITIONED BY (`dt` STRING)       -- 按日分区
STORED AS ORC                     -- 列式存储
LOCATION '/warehouse/gmall/dwd/dwd_xxx/'
TBLPROPERTIES ('orc.compress'='snappy');
```

### 2.3 分区规范

- 所有表按 `dt`（日期，格式 YYYY-MM-DD）分区
- 分区字段统一为 `STRING` 类型
- 写入数据时指定分区：`INSERT OVERWRITE TABLE xxx PARTITION(dt='2022-06-08')`

### 2.4 存储格式

| 层 | 存储格式 | 压缩 |
|----|----------|------|
| ODS | TEXTFILE | gzip |
| DIM | ORC | snappy |
| DWD | ORC | snappy |
| DWS | ORC | snappy |
| ADS | ORC | snappy |

---

## 三、Shell 脚本规范

### 3.1 脚本结构

```bash
#!/bin/bash

# ===================================================
# 脚本名称: xxx.sh
# 功能描述: xxx
# 参数说明: $1 - 日期（可选，默认 T-1）
# 使用示例: bash xxx.sh 2022-06-08
# ===================================================

set -e  # 遇到错误立即退出
set -u  # 使用未定义变量时报错

# 环境变量
source $(dirname $0)/../common/env.sh

# 日期参数处理
do_date=${1:-$(date -d "-1 day" +%F)}

# 主逻辑
main() {
    # 业务代码
    echo "Processing date: ${do_date}"
}

main
```

### 3.2 日志规范

```bash
# 日志函数
log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" >&2
}

log_info "开始执行 ODS 层数据装载，日期: ${do_date}"
```

---

## 四、Git 提交规范

### 4.1 Commit Message 格式

```
<type>(<scope>): <subject>

<body>
```

### 4.2 Type 类型

| Type | 说明 |
|------|------|
| `feat` | 新功能 |
| `fix` | 修复 Bug |
| `docs` | 文档更新 |
| `style` | 代码格式（不影响功能） |
| `refactor` | 重构 |
| `perf` | 性能优化 |
| `test` | 测试相关 |
| `chore` | 构建/工具/依赖更新 |

### 4.3 示例

```
feat(dwd): 新增交易域下单明细表

- 新增 dwd_trade_order_detail_inc 表
- 实现 ods_order_info 到 DWD 的 ETL 逻辑
- 添加活动减免/优惠券减免金额字段
```

---

## 五、分支管理规范

```
main                # 主分支，稳定的发布版本
  │
  ├── dev            # 开发分支
  │     │
  │     ├── feat/ods-xxx    # 功能分支
  │     ├── feat/dwd-xxx
  │     └── fix/xxx
  │
  └── release/v1.0    # 发布分支
```

**规则**：
- `main` 分支只接受来自 `dev` 或 `release` 的 PR
- 功能开发在 `feat/*` 分支进行，完成后合并到 `dev`
- Bug 修复在 `fix/*` 分支进行

---

## 六、配置文件脱敏规范

所有提交到仓库的配置文件**必须脱敏**，敏感信息用占位符替代：

```properties
# 正确示例（已脱敏）
mysql.username=root
mysql.password=<PASSWORD>
mysql.host=<HOST>

# 错误示例（泄露密码）
mysql.password=123456
```

敏感信息类型：
- 数据库密码
- 服务器 IP 地址
- API Key / Secret
- 内部域名
