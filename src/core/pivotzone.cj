package trade.core

import std.collection.*
import trade.types.*

// 中枢识别（流式）

public class PivotZoneProcessor {
    private let zones: ArrayList<AlgoPivotZone>

    public init(mode: PivotZoneMode) { this.zones = ArrayList<AlgoPivotZone>() }

    public func process(newStrokes: ArrayList<AlgoStroke>): ArrayList<AlgoPivotZone> {
        let result = ArrayList<AlgoPivotZone>()
        if (newStrokes.size < 3) { return result }
        for (i in 0 .. newStrokes.size - 2) {
            let (s1, s2, s3) = (newStrokes[i], newStrokes[i + 1], newStrokes[i + 2])
            let zg = if (s1.high < s2.high) { if (s1.high < s3.high) { s1.high } else { s3.high } } else { if (s2.high < s3.high) { s2.high } else { s3.high } }
            let zd = if (s1.low > s2.low) { if (s1.low > s3.low) { s1.low } else { s3.low } } else { if (s2.low > s3.low) { s2.low } else { s3.low } }
            if (zg > zd) {
                let z = AlgoPivotZone(zg, zd, i, i + 2, s2.direction, false)
                var ei = i + 3
                while (ei < newStrokes.size && newStrokes[ei].high >= zd && newStrokes[ei].low <= zg) { z.endIndex = ei; ei++ }
                if (ei + 1 < newStrokes.size) { let r = newStrokes[ei + 1]; if (!(r.high >= zd && r.low <= zg)) { z.completed = true } }
                zones.add(z); result.add(z); break
            }
        }
        result
    }

    public func getZones(): ArrayList<AlgoPivotZone> { let c = ArrayList<AlgoPivotZone>(); for (z in zones) { c.add(z) }; c }
    public func reset(): Unit { zones.clear() }
}
