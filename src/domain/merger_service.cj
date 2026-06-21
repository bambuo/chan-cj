package trade.domain

import std.collection.*

// ──────────────────────────────────────────────
// Domain Service — 缠论 K 线包含处理
// ──────────────────────────────────────────────

public class MergerService {
    private let merged: ArrayList<ChanKline>

    public init() {
        this.merged = ArrayList<ChanKline>()
    }

    /// 获取当前合并序列的不可变快照
    public func getMergedKlines(): ArrayList<ChanKline> {
        let copy = ArrayList<ChanKline>()
        for (ck in merged) { copy.add(ck) }
        return copy
    }

    /// 处理一条新 K 线：追加 → 循环包含处理
    public func processKline(kline: Kline): Unit {
        let ck = ChanKline(kline.openTime, kline.high, kline.low)
        merged.add(ck)

        var done = false
        while (!done && merged.size >= 2) {
            let lastIdx = merged.size - 1
            let a = merged[lastIdx - 1]
            let b = merged[lastIdx]

            if (!isContained(a, b)) {
                done = true
            } else {
                let trend = determineTrend(lastIdx - 1)
                merged.remove(at: lastIdx)
                merged.remove(at: lastIdx - 1)
                let mergedCk = mergePair(a, b, trend)
                merged.add(mergedCk)
            }
        }
    }

    private func isContained(a: ChanKline, b: ChanKline): Bool {
        return (a.high >= b.high && a.low <= b.low) ||
               (b.high >= a.high && b.low <= a.low)
    }

    private func determineTrend(idx: Int64): ChanTrend {
        if (idx > 0) {
            let prev = merged[idx - 1]
            let curr = merged[idx]
            if (curr.high > prev.high && curr.low > prev.low) {
                return ChanTrend.Up
            }
            if (curr.high < prev.high && curr.low < prev.low) {
                return ChanTrend.Down
            }
        }
        return ChanTrend.Up
    }

    private func mergePair(a: ChanKline, b: ChanKline, trend: ChanTrend): ChanKline {
        match (trend) {
            case ChanTrend.Up =>
                let upHigh = if (a.high > b.high) { a.high } else { b.high }
                let upLow  = if (a.low  > b.low)  { a.low  } else { b.low }
                ChanKline(a.time, upHigh, upLow)
            case ChanTrend.Down =>
                let dnHigh = if (a.high < b.high) { a.high } else { b.high }
                let dnLow  = if (a.low  < b.low)  { a.low  } else { b.low }
                ChanKline(a.time, dnHigh, dnLow)
        }
    }
}
