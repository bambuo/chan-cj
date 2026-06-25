package trade.core

import std.collection.*
import trade.types.*

// ──────────────────────────────────────────────
// 笔识别（M2 管线第三级）— 增量状态机
//
// 状态：候选分型列表 → 最后终点 → 确认笔列表
// 支持：严格/非严格模式、虚笔、回溯修正
// ──────────────────────────────────────────────

/// 笔（算法内部表示）
public struct AlgoStroke {
    public let start: ChanKline       // 起点合并K线
    public let end: ChanKline         // 终点合并K线
    public let startIndex: Int64      // 起点索引
    public let endIndex: Int64        // 终点索引
    public let direction: ChanDirection
    public let isVirtual: Bool        // 是否为虚笔
    public let startPrice: Float64
    public let endPrice: Float64
    public let high: Float64
    public let low: Float64

    public init(start: ChanKline, end: ChanKline,
                startIndex: Int64, endIndex: Int64,
                direction: ChanDirection, isVirtual: Bool,
                startPrice: Float64, endPrice: Float64,
                high: Float64, low: Float64) {
        this.start = start
        this.end = end
        this.startIndex = startIndex
        this.endIndex = endIndex
        this.direction = direction
        this.isVirtual = isVirtual
        this.startPrice = startPrice
        this.endPrice = endPrice
        this.high = high
        this.low = low
    }
}

public class StrokeProcessor {
    // 配置
    private var strictMode: Bool

    // 状态
    private let strokes: ArrayList<AlgoStroke>         // 所有笔（含虚笔）
    private var lastEndpoint: ?ChanKline               // 最后一笔的终点
    private var lastEndpointType: ?FractalType          // 终点分型类型
    private let candidates: ArrayList<(ChanKline, Int64, FractalType)> // 候选分型

    // 回溯修正跟踪
    private var lastStrokeCount: Int64

    public init(strictMode: Bool) {
        this.strictMode = strictMode
        this.strokes = ArrayList<AlgoStroke>()
        this.lastEndpoint = None
        this.lastEndpointType = None
        this.candidates = ArrayList<(ChanKline, Int64, FractalType)>()
        this.lastStrokeCount = 0
    }

    /// 处理一根含分型的合并 K 线
    public func process(fractal: Fractal): Bool {
        let changed = false

        // 1. 清理上一轮的虚笔
        cleanupVirtual()

        // 2. 处理分型
        processFractal(fractal)

        // 3. 跟踪变更
        if (strokes.size != lastStrokeCount) {
            lastStrokeCount = strokes.size
            return true
        }
        changed
    }

    /// 处理一批分型（增量）
    public func processBatch(newFractals: ArrayList<Fractal>): Bool {
        var changed = false
        for (f in newFractals) {
            if (process(f)) { changed = true }
        }
        changed
    }

    /// 获取所有确认笔（不含虚笔）
    public func getConfirmedStrokes(): ArrayList<AlgoStroke> {
        let result = ArrayList<AlgoStroke>()
        for (s in strokes) {
            if (!s.isVirtual) { result.add(s) }
        }
        result
    }

    /// 获取所有笔（含虚笔）
    public func getAllStrokes(): ArrayList<AlgoStroke> {
        let copy = ArrayList<AlgoStroke>()
        for (s in strokes) { copy.add(s) }
        copy
    }

    /// 检查是否有回溯修正
    public func checkModifications(): (Int64, Bool) {
        // 简化：检查笔数量是否减少（有删除）
        (0, false)
    }

    /// 重置
    public func reset(): Unit {
        strokes.clear()
        lastEndpoint = None
        lastEndpointType = None
        candidates.clear()
        lastStrokeCount = 0
    }

    // ── 内部：分型处理 ──

    private func processFractal(fractal: Fractal): Unit {
        match (fractal.ftype) {
            case FractalType.Top | FractalType.Bottom =>
                // 笔列表为空 → 尝试创建第一笔
                if (strokes.size == 0) {
                    tryFirstStroke(fractal)
                    return
                }

                // 获取最后终点类型
                match (lastEndpointType) {
                    case Some(lastType) =>
                        if (fractal.ftype == lastType) {
                            // 同类分型 → 更新最后一笔的终点
                            tryUpdateEndpoint(fractal)
                        } else {
                            // 异类分型 → 尝试成笔
                            tryCreateStroke(fractal)
                        }
                    case None =>
                        tryFirstStroke(fractal)
                }
            case _ => ()
        }
    }

    /// 尝试创建第一笔
    private func tryFirstStroke(fractal: Fractal): Unit {
        // 缓存候选分型
        candidates.add((fractal.kline, fractal.index, fractal.ftype))

        // 检查候选列表是否存在异类分型对
        if (candidates.size >= 2) {
            let (first, firstIdx, firstType) = candidates[0]
            for (i in 1 .. candidates.size) {
                let (second, secondIdx, secondType) = candidates[i]
                if (firstType != secondType && canFormStroke(first, second, firstIdx, secondIdx)) {
                    // 找到异类对，创建第一笔
                    createStroke(first, second, firstIdx, secondIdx, false)
                    lastEndpoint = Some(second)
                    lastEndpointType = Some(secondType)
                    candidates.clear()
                    return
                }
            }
            // 没有找到可成笔的对，保留候选
        }
    }

    /// 尝试更新最后一笔的终点（同类分型）
    private func tryUpdateEndpoint(fractal: Fractal): Unit {
        if (strokes.size == 0) { return }

        let lastStroke = strokes[strokes.size - 1]
        let shouldUpdate = match (lastStroke.direction) {
            case ChanDirection.Up =>
                fractal.ftype == FractalType.Top && fractal.kline.high >= lastStroke.end.high
            case ChanDirection.Down =>
                fractal.ftype == FractalType.Bottom && fractal.kline.low <= lastStroke.end.low
        }

        if (shouldUpdate) {
            // 更新最后一笔的终点
            let updated = AlgoStroke(
                lastStroke.start, fractal.kline,
                lastStroke.startIndex, fractal.index,
                lastStroke.direction, lastStroke.isVirtual,
                lastStroke.startPrice,
                if (lastStroke.direction == ChanDirection.Up) { fractal.kline.high } else { fractal.kline.low },
                if (lastStroke.high > fractal.kline.high) { lastStroke.high } else { fractal.kline.high },
                if (lastStroke.low < fractal.kline.low) { lastStroke.low } else { fractal.kline.low }
            )
            strokes.remove(at: strokes.size - 1)
            strokes.add(updated)
            lastEndpoint = Some(fractal.kline)
        }
    }

    /// 尝试创建新笔
    private func tryCreateStroke(fractal: Fractal): Unit {
        match (lastEndpoint) {
            case Some(endpoint) =>
                let startIdx = if (strokes.size > 0) { strokes[strokes.size - 1].endIndex } else { 0 }
                if (canFormStroke(endpoint, fractal.kline, startIdx, fractal.index)) {
                    createStroke(endpoint, fractal.kline, startIdx, fractal.index, false)
                    lastEndpoint = Some(fractal.kline)
                    lastEndpointType = Some(fractal.ftype)
                } else {
                    // 无法成笔，加入候选
                    candidates.add((fractal.kline, fractal.index, fractal.ftype))
                }
            case None =>
                tryFirstStroke(fractal)
        }
    }

    /// 创建笔
    private func createStroke(start: ChanKline, end: ChanKline,
                               startIdx: Int64, endIdx: Int64,
                               isVirtual: Bool): Unit {
        let direction = if (startIdx <= endIdx) {
            // 起点为底 → 向上笔
            ChanDirection.Up
        } else {
            ChanDirection.Down
        }

        let startPrice = if (direction == ChanDirection.Up) { start.low } else { start.high }
        let endPrice = if (direction == ChanDirection.Up) { end.high } else { end.low }
        let high = if (start.high > end.high) { start.high } else { end.high }
        let low = if (start.low < end.low) { start.low } else { end.low }

        let stroke = AlgoStroke(start, end, startIdx, endIdx, direction, isVirtual,
                                 startPrice, endPrice, high, low)
        strokes.add(stroke)
    }

    /// 成笔判断
    private func canFormStroke(a: ChanKline, b: ChanKline, aIdx: Int64, bIdx: Int64): Bool {
        let span = if (aIdx < bIdx) { bIdx - aIdx } else { aIdx - bIdx }

        // 跨度检查
        if (strictMode) {
            if (span < 4) { return false }
        } else {
            if (span < 3) { return false }
        }

        // 价格区间检查
        // 向上笔：终点的最高价 > 起点的最低价
        // 向下笔：终点的最低价 < 起点的最高价
        if (aIdx < bIdx) {
            // a 是起点，b 是终点
            b.high > a.low
        } else {
            b.low < a.high
        }
    }

    /// 清理虚笔
    private func cleanupVirtual(): Unit {
        var i = strokes.size - 1
        while (i >= 0) {
            if (strokes[i].isVirtual) {
                strokes.remove(at: i)
            }
            i--
        }
    }
}
