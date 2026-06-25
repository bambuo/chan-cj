package trade.core

import std.collection.*
import trade.types.*

// ──────────────────────────────────────────────
// 包含处理（M2 管线第一级）
//
// 使用运算符重载后的 ChanKline：
//   包含判定 → a >= b || b >= a
//   方向判定 → curr > prev → Up,  curr < prev → Down
//   向上合并 → a + b
//   向下合并 → a - b
// ──────────────────────────────────────────────

public class ContainProcessor {
    private let elements: ArrayList<ChanKline>
    private var trend: ChanTrend

    public init() {
        this.elements = ArrayList<ChanKline>()
        this.trend = ChanTrend.Up
    }

    /// 处理一根原始 K 线，返回是否产生了新的非包含元素
    public func process(kline: Kline): Bool {
        let ck = ChanKline(kline.openTime, kline.high, kline.low)
        let oldSize = elements.size

        elements.add(ck)
        resolveContainment()

        elements.size != oldSize
    }

    /// 获取当前所有非包含元素（只读快照）
    public func getElements(): ArrayList<ChanKline> {
        let copy = ArrayList<ChanKline>()
        for (e in elements) { copy.add(e) }
        copy
    }

    /// 获取当前趋势方向
    public func getTrend(): ChanTrend { trend }

    /// 重置状态
    public func reset(): Unit {
        elements.clear()
        trend = ChanTrend.Up
    }

    // ── 内部：循环包含处理 ──

    private func resolveContainment(): Unit {
        var done = false
        while (!done && elements.size >= 2) {
            let lastIdx = elements.size - 1
            let a = elements[lastIdx - 1]
            let b = elements[lastIdx]

            // 运算符重载版包含判定：a >= b || b >= a
            if (!(a >= b || b >= a)) {
                done = true
            } else {
                // 更新方向
                trend = determineTrend(lastIdx - 1)

                // 运算符重载版合并
                let merged = match (trend) {
                    case ChanTrend.Up => a + b   // 向上合并：取高点更高、低点更高
                    case ChanTrend.Down => a - b // 向下合并：取高点更低、低点更低
                }

                elements.remove(at: lastIdx)
                elements.remove(at: lastIdx - 1)
                elements.add(merged)
            }
        }
    }

    /// 以最后两个元素为基准判定方向（缠论 AND 条件）
    private func determineTrend(idx: Int64): ChanTrend {
        if (idx > 0) {
            let prev = elements[idx - 1]
            let curr = elements[idx]

            // 运算符重载版方向判定
            if (curr > prev) { return ChanTrend.Up }     // 高点更高 且 低点更高
            if (curr < prev) { return ChanTrend.Down }    // 高点更低 且 低点更低
        }
        ChanTrend.Up
    }
}
