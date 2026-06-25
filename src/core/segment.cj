package trade.core

import std.collection.*
import trade.types.*

// ──────────────────────────────────────────────
// 线段划分（M2 管线第四级）
//
// 基于特征序列的线段划分算法：
//   情况一：特征序列分型第 1、2 元素间无缺口 → 直接确认
//   情况二：有缺口 → 等待第二特征序列分型确认
// ──────────────────────────────────────────────

/// 线段（算法内部表示）
public struct AlgoSegment {
    public let direction: ChanDirection
    public let strokes: ArrayList<AlgoStroke>
    public let startIndex: Int64
    public let endIndex: Int64
    public let high: Float64
    public let low: Float64

    public init(direction: ChanDirection, strokes: ArrayList<AlgoStroke>,
                startIndex: Int64, endIndex: Int64, high: Float64, low: Float64) {
        this.direction = direction
        this.strokes = strokes
        this.startIndex = startIndex
        this.endIndex = endIndex
        this.high = high
        this.low = low
    }
}

/// 线段待确认状态
private struct PendingSegment {
    let pivotFractal: (Float64, Float64)  // 分型极值 (high, low)
    let firstGap: Bool                     // 第1、2元素间是否有缺口
    let startStrokeIdx: Int64

    public init(pivotFractal: (Float64, Float64), firstGap: Bool, startStrokeIdx: Int64) {
        this.pivotFractal = pivotFractal
        this.firstGap = firstGap
        this.startStrokeIdx = startStrokeIdx
    }
}

public class SegmentProcessor {
    private let segments: ArrayList<AlgoSegment>
    private var pending: ?PendingSegment
    private var lastDirection: ChanDirection

    public init() {
        this.segments = ArrayList<AlgoSegment>()
        this.pending = None
        this.lastDirection = ChanDirection.Up
    }

    /// 增量处理笔序列
    public func process(strokes: ArrayList<AlgoStroke>): Unit {
        if (strokes.size < 3) { return }

        // 检查是否有待确认的线段
        match (pending) {
            case Some(p) => checkPendingConfirm(strokes, p)
            case None => scanSegments(strokes)
        }
    }

    /// 获取当前所有线段
    public func getSegments(): ArrayList<AlgoSegment> {
        let copy = ArrayList<AlgoSegment>()
        for (s in segments) { copy.add(s) }
        copy
    }

    /// 重置
    public func reset(): Unit {
        segments.clear()
        pending = None
        lastDirection = ChanDirection.Up
    }

    // ── 内部 ──

    /// 扫描线段（情况一）
    private func scanSegments(strokes: ArrayList<AlgoStroke>): Unit {
        let count = strokes.size
        var i = if (segments.size > 0) { segments[segments.size - 1].endIndex + 1 } else { 0 }

        while (i < count - 2) {
            let s1 = strokes[i]
            let s2 = strokes[i + 1]
            let s3 = strokes[i + 2]

            // 检查特征序列分型
            // 向上线段看顶分型：s2 是向下笔，检查 s2 是否形成顶分型
            // 向下线段看底分型
            if (lastDirection == ChanDirection.Up) {
                // 向上线段：特征序列是向下笔
                if (s2.direction == ChanDirection.Down) {
                    if (isTopFractalStroke(s1, s2, s3)) {
                        // 检查第 1、2 元素间是否有缺口
                        let gap = hasGap(s1, s2)
                        if (!gap) {
                            // 情况一：直接确认
                            createSegment(strokes, i, i + 2)
                            i += 3
                        } else {
                            // 情况二：待确认
                            pending = Some(PendingSegment(
                                (s2.high, s2.low), true, i))
                            i++
                        }
                    } else { i++ }
                } else { i++ }
            } else {
                // 向下线段：特征序列是向上笔
                if (s2.direction == ChanDirection.Up) {
                    if (isBottomFractalStroke(s1, s2, s3)) {
                        let gap = hasGap(s1, s2)
                        if (!gap) {
                            createSegment(strokes, i, i + 2)
                            i += 3
                        } else {
                            pending = Some(PendingSegment(
                                (s2.low, s2.high), true, i))
                            i++
                        }
                    } else { i++ }
                } else { i++ }
            }
        }
    }

    /// 检查待确认线段（情况二）
    private func checkPendingConfirm(strokes: ArrayList<AlgoStroke>, p: PendingSegment): Unit {
        // 在第二特征序列中寻找分型
        let count = strokes.size
        let startIdx = p.startStrokeIdx + 1
        if (startIdx >= count - 2) { return }

        for (i in startIdx .. count - 2) {
            let s1 = strokes[i]
            let s2 = strokes[i + 1]
            let s3 = strokes[i + 2]

            // 第二特征序列分型（不分缺口，有分型即可）
            if (lastDirection == ChanDirection.Up) {
                if (s2.direction == ChanDirection.Up &&
                    isBottomFractalStroke(s1, s2, s3)) {
                    // 确认线段在之前的分型极值处结束
                    createSegment(strokes, 0, p.startStrokeIdx + 1)
                    pending = None
                    return
                }
            } else {
                if (s2.direction == ChanDirection.Down &&
                    isTopFractalStroke(s1, s2, s3)) {
                    createSegment(strokes, 0, p.startStrokeIdx + 1)
                    pending = None
                    return
                }
            }
        }
    }

    private func createSegment(strokes: ArrayList<AlgoStroke>, from: Int64, to: Int64): Unit {
        let segStrokes = ArrayList<AlgoStroke>()
        var high = -1.0e308
        var low = 1.0e308
        for (i in from .. to) {
            segStrokes.add(strokes[i])
            if (strokes[i].high > high) { high = strokes[i].high }
            if (strokes[i].low < low) { low = strokes[i].low }
        }

        let seg = AlgoSegment(lastDirection, segStrokes, from, to - 1, high, low)
        segments.add(seg)
        lastDirection = if (lastDirection == ChanDirection.Up) { ChanDirection.Down } else { ChanDirection.Up }
    }

    private func isTopFractalStroke(a: AlgoStroke, b: AlgoStroke, c: AlgoStroke): Bool {
        b.high > a.high && b.high > c.high && b.low > a.low && b.low > c.low
    }

    private func isBottomFractalStroke(a: AlgoStroke, b: AlgoStroke, c: AlgoStroke): Bool {
        b.low < a.low && b.low < c.low && b.high < a.high && b.high < c.high
    }

    private func hasGap(a: AlgoStroke, b: AlgoStroke): Bool {
        // 缺口：两笔的价格区间完全不重叠
        a.high < b.low || a.low > b.high
    }
}
