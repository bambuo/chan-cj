package trade.core

import std.collection.*
import trade.types.*

// 走势类型（流式）

public class TrendPatternProcessor {
    private let patterns: ArrayList<AlgoTrendPattern>

    public init() { this.patterns = ArrayList<AlgoTrendPattern>() }

    public func process(newZones: ArrayList<AlgoPivotZone>): ArrayList<AlgoTrendPattern> {
        let result = ArrayList<AlgoTrendPattern>()
        for (z in newZones) {
            if (patterns.size > 0) {
                let last = patterns[patterns.size - 1]
                if (!last.completed && last.direction == z.direction) {
                    let prev = last.zones[last.zones.size - 1]
                    let ok = match (z.direction) {
                        case ChanDirection.Up => z.zd > prev.zg
                        case ChanDirection.Down => z.zg < prev.zd
                    }
                    if (ok) { last.zones.add(z)
                        if (last.zones.size >= 2) { last.isTrend = true }; continue
                    } else { last.completed = true; result.add(last) }
                } else { last.completed = true; result.add(last) }
            }
            let zones = ArrayList<AlgoPivotZone>(); zones.add(z)
            patterns.add(AlgoTrendPattern(z.direction, false, zones, false, ""))
        }
        result
    }

    public func getPatterns(): ArrayList<AlgoTrendPattern> { let c = ArrayList<AlgoTrendPattern>(); for (p in patterns) { c.add(p) }; c }
    public func markLastCompleted(reason: String): Unit { if (patterns.size > 0) { patterns[patterns.size - 1].completed = true; patterns[patterns.size - 1].completionReason = reason } }
    public func reset(): Unit { patterns.clear() }
}
