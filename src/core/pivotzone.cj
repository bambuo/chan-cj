package trade.core

import std.collection.*
import trade.types.*

// ──────────────────────────────────────────────
// 中枢识别（M2 管线第五级）
//
// 连续三段重叠 → ZG(高点中最小) / ZD(低点中最大)
// 延伸 → 依次检查后续段是否与中枢区间有交集
// 完成 → 第三类买卖点确认
// ──────────────────────────────────────────────

/// 中枢（算法内部表示）
public class AlgoPivotZone {
    public let zg: Float64
    public let zd: Float64
    public let startIndex: Int64
    public var endIndex: Int64
    public let direction: ChanDirection
    public var completed: Bool

    public init(zg: Float64, zd: Float64, startIndex: Int64, endIndex: Int64,
                direction: ChanDirection, completed: Bool) {
        this.zg = zg
        this.zd = zd
        this.startIndex = startIndex
        this.endIndex = endIndex
        this.direction = direction
        this.completed = completed
    }
}

public class PivotZoneProcessor {
    private let zones: ArrayList<AlgoPivotZone>
    private var mode: PivotZoneMode

    public init(mode: PivotZoneMode) {
        this.zones = ArrayList<AlgoPivotZone>()
        this.mode = mode
    }

    /// 基于笔序列处理
    public func process(strokes: ArrayList<AlgoStroke>): Unit {
        scanZones(strokes)
    }

    /// 获取所有中枢
    public func getZones(): ArrayList<AlgoPivotZone> {
        let copy = ArrayList<AlgoPivotZone>()
        for (z in zones) { copy.add(z) }
        copy
    }

    /// 重置
    public func reset(): Unit {
        zones.clear()
    }

    // ── 内部 ──

    private func scanZones(strokes: ArrayList<AlgoStroke>): Unit {
        let count = strokes.size
        var i = if (zones.size > 0) { zones[zones.size - 1].endIndex + 1 } else { 0 }

        while (i < count - 2) {
            let s1 = strokes[i]
            let s2 = strokes[i + 1]
            let s3 = strokes[i + 2]

            // 计算 ZG（高点中的最小者）和 ZD（低点中的最大者）
            let highs = [s1.high, s2.high, s3.high]
            let lows = [s1.low, s2.low, s3.low]
            let zg = minOf(highs)
            let zd = maxOf(lows)

            if (zg > zd) {
                // 存在有效重叠 → 形成中枢
                let zone = AlgoPivotZone(zg, zd, i, i + 2, s2.direction, false)
                zones.add(zone)

                // 延伸检查
                extendZone(zone, strokes, i + 3)
                i = zone.endIndex + 1
            } else {
                i++
            }
        }
    }

    private func extendZone(zone: AlgoPivotZone, strokes: ArrayList<AlgoStroke>, startFrom: Int64): Unit {
        var i = startFrom
        while (i < strokes.size) {
            let s = strokes[i]
            // 检查是否与中枢区间有交集
            let hasOverlap = s.high >= zone.zd && s.low <= zone.zg
            if (hasOverlap) {
                // 中枢延伸
                zone.endIndex = i
                i++
            } else {
                // 脱离中枢 — 检查第三类买卖点
                let isThirdTypeSell = s.high < zone.zd  // 向下脱离
                let isThirdTypeBuy = s.low > zone.zg    // 向上脱离

                if (isThirdTypeSell || isThirdTypeBuy) {
                    // 检查回抽段
                    if (i + 1 < strokes.size) {
                        let retrace = strokes[i + 1]
                        let retraceOverlap = retrace.high >= zone.zd && retrace.low <= zone.zg
                        if (!retraceOverlap) {
                            // 回抽未回到中枢 → 第三类买卖点确认完成
                            zone.completed = true
                        }
                    }
                }
                return
            }
        }
    }

    private func minOf(values: Array<Float64>): Float64 {
        var m = values[0]
        for (v in values) { if (v < m) { m = v } }
        m
    }

    private func maxOf(values: Array<Float64>): Float64 {
        var m = values[0]
        for (v in values) { if (v > m) { m = v } }
        m
    }
}
