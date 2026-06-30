#!/bin/bash
# ===================================================
# 每周离线数仓调度
# 用途：执行周粒度统计任务（通常在周一触发）
# 触发：DolphinScheduler 每周一 02:00 触发
# 参数：$1 - 日期（可选，默认 T-1）
# ===================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

source ${PROJECT_ROOT}/script/common/env.sh
source ${PROJECT_ROOT}/script/common/date_util.sh

DO_DATE=$(get_do_date "$1")

# 仅在周一执行（可选检查）
if ! is_monday "$DO_DATE"; then
    echo "[INFO] 今天不是周一，跳过周调度 (日期: ${DO_DATE})"
    exit 0
fi

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║   GMall 离线数仓 — 每周调度                                  ║"
echo "║   日期: ${DO_DATE}                                           ║"
echo "╚══════════════════════════════════════════════════════════════╝"

WEEK_START=$(get_before_date "$DO_DATE" 6)
WEEK_LABEL="week_${WEEK_START}_${DO_DATE}"

echo "[INFO] 统计周期: ${WEEK_START} ~ ${DO_DATE}"

# 执行周粒度 ADS 报表（使用 hive_util）
${HIVE_HOME}/bin/hive --hiveconf do_date="${DO_DATE}" \
    --hiveconf week_start="${WEEK_START}" << EOF

USE ${HIVE_DB};

-- ==================== 周粒度流量统计 ====================
INSERT OVERWRITE TABLE ads_traffic_stats_by_channel
SELECT
    '${DO_DATE}'                                     AS dt,
    7                                                  AS recent_days,
    channel,
    COUNT(DISTINCT mid)                               AS uv_count,
    CAST(AVG(during_time_sec) AS BIGINT)              AS avg_duration_sec,
    CAST(AVG(page_count) AS BIGINT)                   AS avg_page_count,
    COUNT(DISTINCT session_id)                        AS sv_count,
    CAST(SUM(IF(page_count = 1, 1, 0)) * 100.0
         / COUNT(DISTINCT session_id) AS DECIMAL(16,2)) AS bounce_rate
FROM dws_traffic_session_page_view_1d
WHERE dt >= '${WEEK_START}' AND dt <= '${DO_DATE}'
GROUP BY channel;

EOF

echo "[INFO] 周调度完成"
