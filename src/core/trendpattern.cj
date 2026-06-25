package trade.core

import std.collection.*
import trade.types.*

// 走势类型（流式）
// RingBuffer 保留最近 1 个走势类型做延续判断

public class TrendPatternProcessor {
    private let patterns: RingBuffer<AlgoTrendPattern>

    public init() {
        this.patterns = RingBuffer<AlgoTrendPattern>(1)
    }

    public func process(newZones: ArrayList<AlgoPivotZone>): ArrayList<AlgoTrendPattern> {
        let result = ArrayList<AlgoTrendPattern>()
        for (z in newZones) {
            let lastOpt = patterns.last()
            match (lastOpt) {
                case Some(last) =>
                    if (!last.completed && last.direction == z.direction) {
                        let prev = last.zones[last.zones.size - 1]
                        let ok = match (z.direction) {
                            case ChanDirection.Up => z.zd > prev.zg
                            case ChanDirection.Down => z.zg < prev.zd
                        }
                        if (ok) {
                            last.zones.add(z)
                            if (last.zones.size >= 2) { last.isTrend = true }
                            continue
                        } else {
                            last.completed = true
                            result.add(last)
                        }
                    } else {
                        last.completed = true
                        result.add(last)
                    }
                case None => ()
            }
            let zones = ArrayList<AlgoPivotZone>()
            zones.add(z)
            let np = AlgoTrendPattern(z.direction, false, zones, false, "")
            patterns.add(np)
            result.add(np)
        }
        result
    }

    public func getPatterns(): ArrayList<AlgoTrendPattern> { patterns.toArrayList() }
    public func markLastCompleted(reason: String): Unit {
        match (patterns.last()) {
            case Some(p) => p.completed = true; p.completionReason = reason
            case None => ()
        }
    }
    public func reset(): Unit { patterns.clear() }
}
