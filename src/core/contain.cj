package trade.core

import std.collection.*
import trade.types.*

// ──────────────────────────────────────────────
// 包含处理（流式）
// 维护末尾最少元素用于下次包含判定
// ──────────────────────────────────────────────

/// 带全局索引的合并元素
private struct IndexedKline {
    let kline: ChanKline
    let index: Int64

    public init(kline: ChanKline, index: Int64) {
        this.kline = kline
        this.index = index
    }
}

public class ContainProcessor {
    private let tail: ArrayList<IndexedKline>
    private var trend: ChanTrend
    private var counter: Int64

    public init() {
        this.tail = ArrayList<IndexedKline>()
        this.trend = ChanTrend.Up
        this.counter = 0
    }

    public func process(kline: Kline): ?ChanKline {
        let idx = counter; counter++
        tail.add(IndexedKline(ChanKline(kline.openTime, kline.high, kline.low), idx))
        resolveContainment()
        if (tail.size > 0) { Some(tail[tail.size - 1].kline) } else { None }
    }

    /// 获取最后 N 个元素及其在全局序列中的起始偏移
    public func getLastWithOffset(n: Int64): (ArrayList<ChanKline>, Int64) {
        let result = ArrayList<ChanKline>()
        let start = if (tail.size > n) { tail.size - n } else { 0 }
        let offset = if (tail.size > 0) { tail[start].index } else { 0 }
        for (i in start .. tail.size) { result.add(tail[i].kline) }
        (result, offset)
    }

    /// 获取最后 N 个元素（不含索引，兼容旧调用）
    public func getLast(n: Int64): ArrayList<ChanKline> {
        let (r, _) = getLastWithOffset(n)
        r
    }

    public func getLatest(): ?ChanKline {
        if (tail.size > 0) { Some(tail[tail.size - 1].kline) } else { None }
    }

    public func trim(): Unit {
        if (tail.size > 3) {
            let keep = ArrayList<IndexedKline>()
            for (i in tail.size - 3 .. tail.size) { keep.add(tail[i]) }
            tail.clear()
            for (e in keep) { tail.add(e) }
        }
    }

    public func reset(): Unit {
        tail.clear()
        trend = ChanTrend.Up
    }

    private func resolveContainment(): Unit {
        var done = false
        while (!done && tail.size >= 2) {
            let a = tail[tail.size - 2].kline
            let b = tail[tail.size - 1].kline
            if (!(a >= b || b >= a)) { done = true } else {
                trend = determineTrend(tail.size - 2)
                let merged = match (trend) {
                    case ChanTrend.Up => a + b
                    case ChanTrend.Down => a - b
                }
                // 合并后保留较早的索引
                let mergedIdx = tail[tail.size - 2].index
                tail.remove(at: tail.size - 1)
                tail.remove(at: tail.size - 1)
                tail.add(IndexedKline(merged, mergedIdx))
            }
        }
    }

    private func determineTrend(idx: Int64): ChanTrend {
        if (idx > 0 && idx < tail.size) {
            let prev = tail[idx - 1].kline; let curr = tail[idx].kline
            if (curr > prev) { return ChanTrend.Up }
            if (curr < prev) { return ChanTrend.Down }
        }
        ChanTrend.Up
    }
}
