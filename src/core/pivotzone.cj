package trade.core

import std.collection.*
import trade.types.*

// 中枢识别（流式）
// 支持笔中枢和线段中枢两种模式

public class PivotZoneProcessor {
    private let zones: RingBuffer<AlgoPivotZone>
    private let strokeBuffer: RingBuffer<AlgoStroke>    // 笔模式：积累笔做滑动检测
    private let segmentBuffer: RingBuffer<AlgoSegment>  // 线段模式：积累线段做滑动检测

    public init(mode: PivotZoneMode) {
        this.zones = RingBuffer<AlgoPivotZone>(50)
        this.strokeBuffer = RingBuffer<AlgoStroke>(100)
        this.segmentBuffer = RingBuffer<AlgoSegment>(50)
    }

    /// 笔中枢检测
    public func process(newStrokes: ArrayList<AlgoStroke>): ArrayList<AlgoPivotZone> {
        for (s in newStrokes) { strokeBuffer.add(s) }
        detectFromBuffer(strokeBuffer.toArrayList())
    }

    /// 线段中枢检测
    public func process(newSegments: ArrayList<AlgoSegment>): ArrayList<AlgoPivotZone> {
        for (s in newSegments) { segmentBuffer.add(s) }
        detectFromSegmentBuffer(segmentBuffer.toArrayList())
    }

    public func getZones(): ArrayList<AlgoPivotZone> { zones.toArrayList() }
    public func reset(): Unit { zones.clear(); strokeBuffer.clear(); segmentBuffer.clear() }

    // ── 内部：笔中枢检测 ──

    private func detectFromBuffer(all: ArrayList<AlgoStroke>): ArrayList<AlgoPivotZone> {
        let result = ArrayList<AlgoPivotZone>()
        if (all.size < 3) { return result }
        let start = if (all.size > 5) { all.size - 5 } else { 0 }
        for (i in start .. all.size - 2) {
            let (s1, s2, s3) = (all[i], all[i + 1], all[i + 2])
            let zg = if (s1.high < s2.high) { if (s1.high < s3.high) { s1.high } else { s3.high } } else { if (s2.high < s3.high) { s2.high } else { s3.high } }
            let zd = if (s1.low > s2.low) { if (s1.low > s3.low) { s1.low } else { s3.low } } else { if (s2.low > s3.low) { s2.low } else { s3.low } }
            if (zg > zd) {
                let z = AlgoPivotZone(zg, zd, i, i + 2, s2.direction, false)
	                z.startTime = s1.start.time
	                z.endTime = s3.end.time
                z.startPrice = s1.startPrice
                z.endPrice = s3.endPrice
                var ei = i + 3
                while (ei < all.size && all[ei].high >= zd && all[ei].low <= zg) { z.endIndex = ei; ei++ }
                if (ei < all.size) { let r = all[ei]; if (!(r.high >= zd && r.low <= zg)) { z.completed = true } }
                if (!isDuplicate(z)) { zones.add(z); result.add(z) }
                break
            }
        }
        result
    }

    private func isDuplicate(z: AlgoPivotZone): Bool {
        var dup = false
        let existing = zones.toArrayList()
        for (ez in existing) {
            if (ez.zg == z.zg && ez.zd == z.zd && ez.startIndex == z.startIndex) {
                dup = true; break
            }
        }
        dup
    }

    // ── 内部：线段中枢检测 ──

    private func detectFromSegmentBuffer(all: ArrayList<AlgoSegment>): ArrayList<AlgoPivotZone> {
        let result = ArrayList<AlgoPivotZone>()
        if (all.size < 3) { return result }
        let start = if (all.size > 20) { all.size - 20 } else { 0 }
        for (i in start .. all.size - 2) {
            let (s1, s2, s3) = (all[i], all[i + 1], all[i + 2])
            let zg = if (s1.high < s2.high) { if (s1.high < s3.high) { s1.high } else { s3.high } } else { if (s2.high < s3.high) { s2.high } else { s3.high } }
            let zd = if (s1.low > s2.low) { if (s1.low > s3.low) { s1.low } else { s3.low } } else { if (s2.low > s3.low) { s2.low } else { s3.low } }
            if (zg > zd) {
                let z = AlgoPivotZone(zg, zd, i, i + 2, s2.direction, false)
                z.startTime = s1.startTime
                z.endTime = s3.endTime
                z.startPrice = s1.startPrice
                z.endPrice = s3.endPrice
                var ei = i + 3
                while (ei < all.size && all[ei].high >= zd && all[ei].low <= zg) { z.endIndex = ei; ei++ }
                if (ei < all.size) { let r = all[ei]; if (!(r.high >= zd && r.low <= zg)) { z.completed = true } }
                if (!isDuplicate(z)) { zones.add(z); result.add(z) }
                break
            }
        }
        result
    }
}
