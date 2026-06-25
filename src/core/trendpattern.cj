package trade.core

import std.collection.*
import trade.types.*

// ──────────────────────────────────────────────
// 走势类型分类（M2 管线第六级）
//
// 趋势：≥2 个互不重叠的同向中枢且逐次推进
// 盘整：只有 1 个中枢
// ──────────────────────────────────────────────

/// 走势类型（算法内部表示）
public class AlgoTrendPattern {
    public let direction: ChanDirection
    public var isTrend: Bool
    public let zones: ArrayList<AlgoPivotZone>
    public var completed: Bool
    public var completionReason: String

    public init(direction: ChanDirection, isTrend: Bool,
                zones: ArrayList<AlgoPivotZone>, completed: Bool,
                completionReason: String) {
        this.direction = direction
        this.isTrend = isTrend
        this.zones = zones
        this.completed = completed
        this.completionReason = completionReason
    }
}

public class TrendPatternProcessor {
    private let patterns: ArrayList<AlgoTrendPattern>

    public init() {
        this.patterns = ArrayList<AlgoTrendPattern>()
    }

    /// 基于中枢序列处理
    public func process(zones: ArrayList<AlgoPivotZone>): Unit {
        classify(zones)
    }

    /// 获取所有走势类型
    public func getPatterns(): ArrayList<AlgoTrendPattern> {
        let copy = ArrayList<AlgoTrendPattern>()
        for (p in patterns) { copy.add(p) }
        copy
    }

    /// 标记最后一个走势类型为已完成
    public func markLastCompleted(reason: String): Unit {
        if (patterns.size > 0) {
            let last = patterns[patterns.size - 1]
            last.completed = true
            last.completionReason = reason
        }
    }

    /// 重置
    public func reset(): Unit {
        patterns.clear()
    }

    // ── 内部 ──

    private func classify(zones: ArrayList<AlgoPivotZone>): Unit {
        var i = if (patterns.size > 0) {
            // 从最后一个走势类型之后的中枢开始
            let last = patterns[patterns.size - 1]
            last.zones[last.zones.size - 1].endIndex + 1
        } else { 0 }

        while (i < zones.size) {
            var zoneGroup = ArrayList<AlgoPivotZone>()
            zoneGroup.add(zones[i])
            var j = i + 1

            // 收集同向中枢
            while (j < zones.size) {
                let prev = zones[j - 1]
                let curr = zones[j]

                if (curr.direction != prev.direction) { break }

                // 检查是否重叠
                let overlap = !(prev.zg <= curr.zd || prev.zd >= curr.zg)
                if (overlap) { break }  // 重叠 → 扩展处理

                // 检查单调性（上涨趋势：后中枢 ZD > 前中枢 ZG）
                if (curr.direction == ChanDirection.Up) {
                    if (curr.zd <= prev.zg) { break }  // 未创新高
                } else {
                    if (curr.zg >= prev.zd) { break }  // 未创新低
                }

                zoneGroup.add(curr)
                j++
            }

            // 创建走势类型
            let direction = zoneGroup[0].direction
            let isTrend = zoneGroup.size >= 2
            let pattern = AlgoTrendPattern(direction, isTrend, zoneGroup, false, "")
            patterns.add(pattern)
            i = j
        }
    }
}
