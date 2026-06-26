package trade.core

import std.collection.*
import trade.types.*
import trade.log.*

let segLog = logger("线段")

private struct FeatureK {
    let high: Float64; let low: Float64; let strokeIdx: Int64; let isUp: Bool
    public init(high: Float64, low: Float64, strokeIdx: Int64, isUp: Bool) {
        this.high = high; this.low = low; this.strokeIdx = strokeIdx; this.isUp = isUp
    }
}

public class SegmentProcessor {
    private let segments: RingBuffer<AlgoSegment>   // 最多 1 段：最后一段
    private var currentDir: ChanDirection
    private var segmentStart: Int64
    private var segmentStartTime: Int64                // 当前线段的开始时间
    private var segmentEndTime: Int64                  // 当前线段的最新结束时间
    private var segmentStartPrice: Float64             // 当前线段的起始价格
    private var segmentEndPrice: Float64               // 当前线段的最新结束价格
    // 特征序列，线段结束时清空；使用 ArrayList 因 mergeTail 需 remove(at: size-1)
    // 容量推导：极端行情连续反向笔不形成特征分型时持续增长
    // 线段通常 3-7 笔，特征序列至多其一半，设 30 为安全硬上限
    private let procSeq: ArrayList<FeatureK>
    private let MAX_PROC_SEQ: Int64 = 30
    private var pendingIdx: Int64
    private let allStrokes: RingBuffer<AlgoStroke>    // 最近 200 笔用于 pendig 检测
    private var hasInitialized: Bool                  // 首笔方向是否已设定

    public init() {
        this.segments = RingBuffer<AlgoSegment>(1)
        this.currentDir = ChanDirection.Up
        this.segmentStart = 0
        this.segmentStartTime = 0
        this.segmentEndTime = 0
        this.segmentStartPrice = 0.0
        this.segmentEndPrice = 0.0
        this.procSeq = ArrayList<FeatureK>()
        this.pendingIdx = -1
        this.allStrokes = RingBuffer<AlgoStroke>(200)
        this.hasInitialized = false
    }

    public func process(newStrokes: ArrayList<AlgoStroke>): ArrayList<AlgoSegment> {
        let result = ArrayList<AlgoSegment>()
        for (s in newStrokes) {
            allStrokes.add(s)
            processStroke(s, result)
        }
        result
    }

    private func processStroke(s: AlgoStroke, result: ArrayList<AlgoSegment>): Unit {
        // 跟踪线段起止时间和价格
        if (segmentStartTime == 0) {
            segmentStartTime = s.start.time
            segmentStartPrice = s.startPrice
        }
        segmentEndTime = s.end.time
        segmentEndPrice = s.endPrice

        // 首笔决定方向
        if (!hasInitialized) {
            match (s.direction) {
                case ChanDirection.Up => currentDir = ChanDirection.Up
                case ChanDirection.Down => currentDir = ChanDirection.Down
            }
            hasInitialized = true
            segLog.info("segment direction set")
        }

        if (s.direction != currentDir) {
            procSeq.add(FeatureK(s.high, s.low, s.endIndex, s.direction == ChanDirection.Up))
            if (procSeq.size > MAX_PROC_SEQ) {
                segLog.warn("procSeq 超限(${MAX_PROC_SEQ})，丢弃最旧特征元素")
                procSeq.remove(at: 0)
            }
            mergeTail()
            segLog.info("procSeq -> ${procSeq.size} elements (added opposite stroke)")
        }

        if (pendingIdx >= 0) {
            match (checkPending()) { case Some(sg) => result.add(sg); segLog.info("segment formed via pending") case None => () }
        } else {
            match (checkFractal()) { case Some(sg) => result.add(sg); segLog.info("segment formed via fractal! procSeq was ${procSeq.size}") case None => () }
        }
    }

    public func getSegments(): ArrayList<AlgoSegment> {
        segments.toArrayList()
    }
    public func reset(): Unit {
        segments.clear(); currentDir = ChanDirection.Up; segmentStart = 0
        segmentStartTime = 0; segmentEndTime = 0
        segmentStartPrice = 0.0; segmentEndPrice = 0.0
        procSeq.clear(); pendingIdx = -1; allStrokes.clear(); hasInitialized = false
    }

    private func mergeTail(): Unit {
        if (procSeq.size < 2) { return }
        var done = false
        while (!done && procSeq.size >= 2) {
            let a = procSeq[procSeq.size - 2]; let b = procSeq[procSeq.size - 1]
            segLog.info("procSeq -> ${procSeq.size} elements")
            if (!(a.high >= b.high && a.low <= b.low) && !(b.high >= a.high && b.low <= a.low)) { done = true; continue }
            let m = mergeFk(a, b, false)
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
        // 收集 pendig 后的同向笔（从 RingBuffer 中遍历）
        let allStrokesList = allStrokes.toArrayList()
        for (i in 0 .. allStrokesList.size) {
            let s = allStrokesList[i]
            if (s.endIndex <= pendingIdx) { continue }
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
        let seg = AlgoSegment(currentDir, ArrayList<AlgoStroke>(),
            segmentStart, endIdx, segmentStartTime, segmentEndTime,
            segmentStartPrice, segmentEndPrice, 0.0, 0.0)
        segments.add(seg)
        segmentStart = endIdx + 1
        segmentStartTime = 0
        segmentStartPrice = 0.0  // 重置，由下一段首笔重新设定
        currentDir = match (currentDir) { case ChanDirection.Up => ChanDirection.Down case ChanDirection.Down => ChanDirection.Up }
        procSeq.clear()
        Some(seg)
    }
}
