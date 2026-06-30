#!/bin/bash
# ===================================================
# 每月离线数仓调度
# 用途：执行月粒度统计任务（通常在月初第一天触发）
# 触发：DolphinScheduler 每月 1 日 03:00 触发
# 参数：$1 - 日期（可选，默认 T-1）
# ===================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

source ${PROJECT_ROOT}/script/common/env.sh
source ${PROJECT_ROOT}/script/common/date_util.sh

DO_DATE=$(get_do_date "$1")

# 仅在每月第一天执行
if ! is_first_day_of_month "$DO_DATE"; then
    echo "[INFO] 今天不是月初第一天，跳过月调度 (日期: ${DO_DATE})"
    exit 0
fi

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║   GMall 离线数仓 — 每月调度                                  ║"
echo "║   日期: ${DO_DATE}                                           ║"
echo "╚══════════════════════════════════════════════════════════════╝"

MONTH_START="${DO_DATE:0:7}-01"
MONTH_LABEL="month_${DO_DATE:0:7}"

echo "[INFO] 统计月份: ${DO_DATE:0:7}"

# 执行月粒度 ADS 报表
${HIVE_HOME}/bin/hive --hiveconf do_date="${DO_DATE}" \
    --hiveconf month_start="${MONTH_START}" << EOF

USE ${HIVE_DB};

-- ==================== 月粒度流量统计 ====================
INSERT OVERWRITE TABLE ads_traffic_stats_by_channel
SELECT
    '${DO_DATE}'                                     AS dt,
    30                                                 AS recent_days,
    channel,
    COUNT(DISTINCT mid)                               AS uv_count,
    CAST(AVG(during_time_sec) AS BIGINT)              AS avg_duration_sec,
    CAST(AVG(page_count) AS BIGINT)                   AS avg_page_count,
    COUNT(DISTINCT session_id)                        AS sv_count,
    CAST(SUM(IF(page_count = 1, 1, 0)) * 100.0
         / COUNT(DISTINCT session_id) AS DECIMAL(16,2)) AS bounce_rate
FROM dws_traffic_session_page_view_1d
WHERE dt >= '${MONTH_START}' AND dt <= '${DO_DATE}'
GROUP BY channel;

EOF

echo "[INFO] 月调度完成"
