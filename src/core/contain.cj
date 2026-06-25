package trade.core

import std.collection.*
import trade.types.*

// ──────────────────────────────────────────────
// 包含处理（流式）
// RingBuffer 固定容量 3，自动淘汰最旧
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
    private let tail: RingBuffer<IndexedKline>   // 容量 3，自动淘汰
    private var trend: ChanTrend
    private var counter: Int64

    public init() {
        this.tail = RingBuffer<IndexedKline>(3)
        this.trend = ChanTrend.Up
        this.counter = 0
    }

    public func process(kline: Kline): ?ChanKline {
        let idx = counter; counter++
        // 转为临时 ArrayList 做包含合并
        let list = tail.toArrayList()
        list.add(IndexedKline(ChanKline(kline.openTime, kline.high, kline.low), idx))
        resolveContainment(list)

        // 写回 RingBuffer（保留最后 3 个）
        tail.clear()
        let start = if (list.size > 3) { list.size - 3 } else { 0 }
        for (i in start .. list.size) {
            tail.add(list[i])
        }

        if (tail.size() > 0) {
            match (tail.last()) {
                case Some(ik) => Some(ik.kline)
                case None => None
            }
        } else { None }
    }

    /// 获取最后 N 个元素及其在全局序列中的起始偏移
    public func getLastWithOffset(n: Int64): (ArrayList<ChanKline>, Int64) {
        let list = tail.toArrayList()
        let result = ArrayList<ChanKline>()
        let start = if (list.size > n) { list.size - n } else { 0 }
        let offset = if (list.size > 0) { list[start].index } else { 0 }
        for (i in start .. list.size) { result.add(list[i].kline) }
        (result, offset)
    }

    /// 获取最后 N 个元素（不含索引，兼容旧调用）
    public func getLast(n: Int64): ArrayList<ChanKline> {
        let (r, _) = getLastWithOffset(n)
        r
    }

    public func getLatest(): ?ChanKline {
        match (tail.last()) {
            case Some(ik) => Some(ik.kline)
            case None => None
        }
    }

    public func reset(): Unit {
        tail.clear()
        trend = ChanTrend.Up
        counter = 0
    }

    // ── 内部 ──

    private func resolveContainment(list: ArrayList<IndexedKline>): Unit {
        var done = false
        while (!done && list.size >= 2) {
            let a = list[list.size - 2].kline
            let b = list[list.size - 1].kline
            if (!(a >= b || b >= a)) { done = true } else {
                trend = determineTrend(list, list.size - 2)
                let merged = match (trend) {
                    case ChanTrend.Up => a + b
                    case ChanTrend.Down => a - b
                }
                let mergedIdx = list[list.size - 2].index
                list.remove(at: list.size - 1)
                list.remove(at: list.size - 1)
                list.add(IndexedKline(merged, mergedIdx))
            }
        }
    }

    private func determineTrend(list: ArrayList<IndexedKline>, idx: Int64): ChanTrend {
        if (idx > 0 && idx < list.size) {
            let prev = list[idx - 1].kline; let curr = list[idx].kline
            if (curr > prev) { return ChanTrend.Up }
            if (curr < prev) { return ChanTrend.Down }
        }
        ChanTrend.Up
    }
}
