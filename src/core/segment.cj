package trade.core

import std.collection.*
import trade.types.*
import trade.log.*

let segLog = logger("SEG")

private struct FeatureK {
    let high: Float64; let low: Float64; let strokeIdx: Int64; let isUp: Bool
    public init(high: Float64, low: Float64, strokeIdx: Int64, isUp: Bool) {
        this.high = high; this.low = low; this.strokeIdx = strokeIdx; this.isUp = isUp
    }
}

public class SegmentProcessor {
    private let segments: ArrayList<AlgoSegment>
    private var currentDir: ChanDirection
    private var segmentStart: Int64
    private let procSeq: ArrayList<FeatureK>
    private var pendingIdx: Int64
    private let allStrokes: ArrayList<AlgoStroke>

    public init() {
        this.segments = ArrayList<AlgoSegment>()
        this.currentDir = ChanDirection.Up
        this.segmentStart = 0
        this.procSeq = ArrayList<FeatureK>()
        this.pendingIdx = -1
        this.allStrokes = ArrayList<AlgoStroke>()
    }

    public func process(newStrokes: ArrayList<AlgoStroke>): ArrayList<AlgoSegment> {
        let result = ArrayList<AlgoSegment>()
        for (s in newStrokes) { allStrokes.add(s) }

        for (i in 0 .. newStrokes.size) {
            let s = newStrokes[i]

            // 首笔决定方向
            if (allStrokes.size == 1 && segmentStart == 0) {
                match (s.direction) {
                    case ChanDirection.Up => currentDir = ChanDirection.Up
                    case ChanDirection.Down => currentDir = ChanDirection.Down
                }
                segLog.info("segment direction set")
            }

            if (s.direction != currentDir) {
                procSeq.add(FeatureK(s.high, s.low, s.endIndex, s.direction == ChanDirection.Up))
                mergeTail()
                segLog.info("procSeq -> ${procSeq.size} elements (added opposite stroke)")
            }

            if (pendingIdx >= 0) {
                match (checkPending()) { case Some(sg) => result.add(sg); segLog.info("segment formed via pending") case None => () }
            } else {
                match (checkFractal()) { case Some(sg) => result.add(sg); segLog.info("segment formed via fractal! procSeq was ${procSeq.size}") case None => () }
            }
        }
        result
    }

    public func getSegments(): ArrayList<AlgoSegment> {
        let copy = ArrayList<AlgoSegment>(); for (s in segments) { copy.add(s) }; copy
    }
    public func reset(): Unit { segments.clear(); currentDir = ChanDirection.Up; segmentStart = 0; procSeq.clear(); pendingIdx = -1; allStrokes.clear() }

    private func mergeTail(): Unit {
        if (procSeq.size < 2) { return }
        var done = false
        while (!done && procSeq.size >= 2) {
            let a = procSeq[procSeq.size - 2]; let b = procSeq[procSeq.size - 1]
            segLog.info("procSeq -> ${procSeq.size} elements")
            if (!(a.high >= b.high && a.low <= b.low) && !(b.high >= a.high && b.low <= a.low)) { done = true; continue }
            let m = mergeFk(a, b, false)  // 第一特征序列
            segLog.info("  mergeTail: merged a.high=${a.high} b.high=${b.high}")
            procSeq.remove(at: procSeq.size - 1); procSeq.remove(at: procSeq.size - 1); procSeq.add(m)
        }
    }

    private func mergeFk(a: FeatureK, b: FeatureK, isSecond: Bool): FeatureK {
        if (isSecond) {
            match (currentDir) {
                case ChanDirection.Up => FeatureK(if (a.high > b.high) { a.high } else { b.high }, if (a.low > b.low) { a.low } else { b.low }, b.strokeIdx, true)
                case ChanDirection.Down => FeatureK(if (a.high < b.high) { a.high } else { b.high }, if (a.low < b.low) { a.low } else { b.low }, b.strokeIdx, false)
            }
        } else {
            match (currentDir) {
                case ChanDirection.Up => FeatureK(if (a.high < b.high) { a.high } else { b.high }, if (a.low < b.low) { a.low } else { b.low }, b.strokeIdx, false)
                case ChanDirection.Down => FeatureK(if (a.high > b.high) { a.high } else { b.high }, if (a.low > b.low) { a.low } else { b.low }, b.strokeIdx, true)
            }
        }
    }

    private func checkFractal(): ?AlgoSegment {
        if (procSeq.size < 3) { return None }
        let a = procSeq[procSeq.size - 3]; let b = procSeq[procSeq.size - 2]; let c = procSeq[procSeq.size - 1]
        let has = match (currentDir) {
            case ChanDirection.Up => b.high > a.high && b.high > c.high && b.low > a.low && b.low > c.low
            case ChanDirection.Down => b.low < a.low && b.low < c.low && b.high < a.high && b.high < c.high
        }
        segLog.info("checkFractal: procSeq=${procSeq.size}, hasFractal=${has}")
        if (!has) { return None }
        if (!(a.high < b.low || a.low > b.high)) {
            return closeSegment(b.strokeIdx)
        }
        pendingIdx = b.strokeIdx; procSeq.clear(); None
    }

    private func checkPending(): ?AlgoSegment {
        let seq = ArrayList<FeatureK>()
        for (i in pendingIdx + 1 .. allStrokes.size) {
            let s = allStrokes[i]
            if (s.direction == currentDir) {
                seq.add(FeatureK(s.high, s.low, i, s.direction == ChanDirection.Up))
                if (seq.size >= 2) {
                    var done = false
                    while (!done && seq.size >= 2) {
                        let a = seq[seq.size - 2]; let b = seq[seq.size - 1]
                        if (!(a.high >= b.high && a.low <= b.low) && !(b.high >= a.high && b.low <= a.low)) { done = true; continue }
                        let m = mergeFk(a, b, true)
                        seq.remove(at: seq.size - 1); seq.remove(at: seq.size - 1); seq.add(m)
                    }
                }
            }
        }
        if (seq.size < 3) { return None }
        for (i in 0 .. seq.size - 2) {
            let a = seq[i]; let b = seq[i + 1]; let c = seq[i + 2]
            let has = match (currentDir) {
                case ChanDirection.Up => b.low < a.low && b.low < c.low && b.high < a.high && b.high < c.high
                case ChanDirection.Down => b.high > a.high && b.high > c.high && b.low > a.low && b.low > c.low
            }
            if (has) { let saved = pendingIdx; pendingIdx = -1; return closeSegment(saved) }
        }
        None
    }

    private func closeSegment(endIdx: Int64): ?AlgoSegment {
        if (segmentStart > endIdx) { return None }
        let seg = AlgoSegment(currentDir, ArrayList<AlgoStroke>(), segmentStart, endIdx, 0.0, 0.0)
        segments.add(seg)
        segmentStart = endIdx + 1
        currentDir = match (currentDir) { case ChanDirection.Up => ChanDirection.Down case ChanDirection.Down => ChanDirection.Up }
        procSeq.clear()
        Some(seg)
    }
}
