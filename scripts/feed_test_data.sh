#!/bin/bash
# ──────────────────────────────────────────────────────
# 缠论分析系统 — 测试数据喂入脚本
#
# 向 Redis Stream 写入模拟 K 线数据，
# chan-cj 系统会通过 XREADGROUP 消费并处理。
#
# 用法:
#   chmod +x scripts/feed_test_data.sh
#   ./scripts/feed_test_data.sh              # 默认写入 BTCUSDT
#   ./scripts/feed_test_data.sh ETHUSDT      # 写入指定交易对
# ──────────────────────────────────────────────────────

SYMBOL="${1:-BTCUSDT}"
PREFIX="trade:kline"
GROUP="chan-cj-group"
STREAM_KEY="${PREFIX}:${SYMBOL}"

echo "═╤═══════════════════════════════════════════"
echo " │ 缠论测试数据喂入"
echo " │ Stream: ${STREAM_KEY}"
echo " │ Group:  ${GROUP}"
echo "═╧═══════════════════════════════════════════"

# 确保 consumer group 存在
redis-cli XGROUP CREATE "${STREAM_KEY}" "${GROUP}" "0" MKSTREAM 2>/dev/null || true

# ── 模拟 K 线数据 ──
# 生成从当前时间开始的 1 分钟 K 线
# 用正弦波模拟价格走势

BASE_PRICE=50000
OPEN_TIME=$(date +%s)000

echo ""
echo "喂入数据中... (按 Ctrl+C 停止)"

COUNT=0
while true; do
    # 用当前秒数产生正弦波动
    TICK=$(date +%s)
    PHASE=$(echo "scale=4; s(${TICK} * 0.1)" | bc -l 2>/dev/null || echo 0)
    CHANGE=$(echo "scale=0; ${PHASE} * 1000 / 1" | bc 2>/dev/null || echo 0)

    OPEN=$((BASE_PRICE + CHANGE))
    HIGH=$((OPEN + 200))
    LOW=$((OPEN - 200))
    CLOSE=$((OPEN + CHANGE / 2))
    VOLUME=$(echo "scale=2; ${RANDOM} * 0.1" | bc 2>/dev/null || echo 1.0)
    IS_CLOSED="false"

    # 每 5 根 K 线收盘一次
    if [ $((COUNT % 5)) -eq 4 ]; then
        IS_CLOSED="true"
    fi

    TS="${OPEN_TIME}"

    redis-cli XADD "${STREAM_KEY}" "MAXLEN" "1000" "*" \
        symbol "${SYMBOL}" \
        openTime "${TS}" \
        closeTime "$((TS + 60000))" \
        open "${OPEN}" \
        high "${HIGH}" \
        low "${LOW}" \
        close "${CLOSE}" \
        volume "${VOLUME}" \
        isClosed "${IS_CLOSED}" \
        > /dev/null

    echo "  [${COUNT}] ${SYMBOL} O=${OPEN} H=${HIGH} L=${LOW} C=${CLOSE} closed=${IS_CLOSED}"

    COUNT=$((COUNT + 1))
    OPEN_TIME=$((OPEN_TIME + 60000))
    BASE_PRICE=$((BASE_PRICE + 50 + RANDOM % 100))

    sleep 0.25
done
