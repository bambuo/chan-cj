package trade.core

import std.collection.*
import trade.types.*

// ──────────────────────────────────────────────
// 管线编排（M2 Facade）
//
// 整合 7 个处理器为按 symbol 管理的管线：
//   contain → fractal → stroke → segment → pivotzone → trendpattern → divergence
// 维护提交水位，支持增量输出
// ──────────────────────────────────────────────

/// 管线输出
public struct PipelineOutput {
    public let symbol: String
    public let newElements: ArrayList<ChanKline>
    public let newFractals: ArrayList<Fractal>
    public let allElements: ArrayList<ChanKline>
    public let allFractals: ArrayList<Fractal>
    public let strokes: ArrayList<AlgoStroke>
    public let newStrokes: ArrayList<AlgoStroke>
    public let segments: ArrayList<AlgoSegment>
    public let newSegments: ArrayList<AlgoSegment>
    public let pivotZones: ArrayList<AlgoPivotZone>
    public let newPivotZones: ArrayList<AlgoPivotZone>
    public let trendPatterns: ArrayList<AlgoTrendPattern>
    public let newTrendPatterns: ArrayList<AlgoTrendPattern>
    public let divergences: ArrayList<AlgoDivergence>
    public let newDivergences: ArrayList<AlgoDivergence>
    public let totalKlines: Int64
    public let lastOpenTime: Int64
    public let hasChange: Bool

    public init(symbol: String,
                newElements: ArrayList<ChanKline>,
                newFractals: ArrayList<Fractal>,
                allElements: ArrayList<ChanKline>,
                allFractals: ArrayList<Fractal>,
                strokes: ArrayList<AlgoStroke>,
                newStrokes: ArrayList<AlgoStroke>,
                segments: ArrayList<AlgoSegment>,
                newSegments: ArrayList<AlgoSegment>,
                pivotZones: ArrayList<AlgoPivotZone>,
                newPivotZones: ArrayList<AlgoPivotZone>,
                trendPatterns: ArrayList<AlgoTrendPattern>,
                newTrendPatterns: ArrayList<AlgoTrendPattern>,
                divergences: ArrayList<AlgoDivergence>,
                newDivergences: ArrayList<AlgoDivergence>,
                totalKlines: Int64,
                lastOpenTime: Int64,
                hasChange: Bool) {
        this.symbol = symbol
        this.newElements = newElements
        this.newFractals = newFractals
        this.allElements = allElements
        this.allFractals = allFractals
        this.strokes = strokes
        this.newStrokes = newStrokes
        this.segments = segments
        this.newSegments = newSegments
        this.pivotZones = pivotZones
        this.newPivotZones = newPivotZones
        this.trendPatterns = trendPatterns
        this.newTrendPatterns = newTrendPatterns
        this.divergences = divergences
        this.newDivergences = newDivergences
        this.totalKlines = totalKlines
        this.lastOpenTime = lastOpenTime
        this.hasChange = hasChange
    }
}

/// Symbol 管线状态
public class SymbolState {
    public let symbol: String
    public let contain: ContainProcessor
    public let fractal: FractalProcessor
    public let stroke: StrokeProcessor
    public let segment: SegmentProcessor
    public let pivotZone: PivotZoneProcessor
    public let trendPattern: TrendPatternProcessor
    public let divergence: DivergenceProcessor

    public var totalKlines: Int64
    public var lastOpenTime: Int64
    public var lastCommittedElementN: Int64
    public var lastCommittedFractalN: Int64
    public var lastCommittedStrokeN: Int64
    public var lastCommittedSegN: Int64
    public var lastCommittedPivotZoneN: Int64
    public var lastCommittedTrendPatternN: Int64
    public var lastCommittedDivergenceN: Int64

    public init(symbol: String, mode: PivotZoneMode) {
        this.symbol = symbol
        this.contain = ContainProcessor()
        this.fractal = FractalProcessor()
        this.stroke = StrokeProcessor(true)
        this.segment = SegmentProcessor()
        this.pivotZone = PivotZoneProcessor(mode)
        this.trendPattern = TrendPatternProcessor()
        this.divergence = DivergenceProcessor()
        this.totalKlines = 0
        this.lastOpenTime = 0
        this.lastCommittedElementN = 0
        this.lastCommittedFractalN = 0
        this.lastCommittedStrokeN = 0
        this.lastCommittedSegN = 0
        this.lastCommittedPivotZoneN = 0
        this.lastCommittedTrendPatternN = 0
        this.lastCommittedDivergenceN = 0
    }

    /// 重置
    public func reset(): Unit {
        contain.reset()
        fractal.reset()
        stroke.reset()
        segment.reset()
        pivotZone.reset()
        trendPattern.reset()
        divergence.reset()
        totalKlines = 0
        lastOpenTime = 0
        lastCommittedElementN = 0
        lastCommittedFractalN = 0
        lastCommittedStrokeN = 0
        lastCommittedSegN = 0
        lastCommittedPivotZoneN = 0
        lastCommittedTrendPatternN = 0
        lastCommittedDivergenceN = 0
    }
}

/// 管线编排器
public class Pipeline {
    private let symbols: HashMap<String, SymbolState>
    private let mode: PivotZoneMode

    public init(mode: PivotZoneMode) {
        this.symbols = HashMap<String, SymbolState>()
        this.mode = mode
    }

    /// 获取或创建 symbol 状态
    public func getOrCreate(symbol: String): SymbolState {
        let state = symbols.get(symbol)
        match (state) {
            case Some(s) => s
            case None =>
                let newState = SymbolState(symbol, mode)
                symbols.add(symbol, newState)
                newState
        }
    }

    /// 重置指定 symbol
    public func reset(symbol: String): Unit {
        let state = symbols.get(symbol)
        match (state) {
            case Some(s) => s.reset()
            case None => ()
        }
    }

    /// 处理一根原始 K 线，返回管线输出
    public func process(kline: Kline): PipelineOutput {
        let state = getOrCreate(kline.symbol.toAsciiLower())
        processWithState(state, kline)
    }

    private func processWithState(state: SymbolState, raw: Kline): PipelineOutput {
        // 1. 包含处理
        state.contain.process(raw)
        state.totalKlines++
        state.lastOpenTime = raw.openTime

        // 2. 喂入收盘价（MACD 计算）
        state.divergence.feedClose(state.symbol, raw.close)

        // 3. 获取当前非包含元素
        let elements = state.contain.getElements()

        // 4. 新增元素
        let oldElemN = state.lastCommittedElementN
        let newElements = ArrayList<ChanKline>()
        for (i in oldElemN .. elements.size) {
            newElements.add(elements[i])
        }

        // 5. 增量分型识别
        state.fractal.process(elements)

        // 6. 获取所有分型
        let allFractals = state.fractal.getFractals()
        let oldFractalN = state.lastCommittedFractalN
        let newFractals = ArrayList<Fractal>()
        for (i in oldFractalN .. allFractals.size) {
            newFractals.add(allFractals[i])
        }

        // 7. 增量笔识别
        if (newFractals.size > 0) {
            state.stroke.processBatch(newFractals)
        }

        // 8. 获取所有笔
        let allStrokes = state.stroke.getConfirmedStrokes()
        let oldStrokeN = state.lastCommittedStrokeN
        let newStrokes = ArrayList<AlgoStroke>()
        for (i in oldStrokeN .. allStrokes.size) {
            newStrokes.add(allStrokes[i])
        }

        // 9. 增量线段识别
        if (newStrokes.size > 0) {
            state.segment.process(allStrokes)
        }

        let allSegments = state.segment.getSegments()
        let oldSegN = state.lastCommittedSegN
        let newSegments = ArrayList<AlgoSegment>()
        for (i in oldSegN .. allSegments.size) {
            newSegments.add(allSegments[i])
        }

        // 10. 增量中枢识别
        if (newStrokes.size > 0) {
            state.pivotZone.process(allStrokes)
        }

        let allPivotZones = state.pivotZone.getZones()
        let oldPivotZoneN = state.lastCommittedPivotZoneN
        let newPivotZones = ArrayList<AlgoPivotZone>()
        for (i in oldPivotZoneN .. allPivotZones.size) {
            newPivotZones.add(allPivotZones[i])
        }

        // 11. 走势类型
        if (newPivotZones.size > 0) {
            state.trendPattern.process(allPivotZones)
        }

        let allTrendPatterns = state.trendPattern.getPatterns()
        let oldTrendPatternN = state.lastCommittedTrendPatternN
        let newTrendPatterns = ArrayList<AlgoTrendPattern>()
        for (i in oldTrendPatternN .. allTrendPatterns.size) {
            newTrendPatterns.add(allTrendPatterns[i])
        }

        // 12. 背驰判定
        if (newStrokes.size > 0 || newPivotZones.size > 0) {
            state.divergence.process(state.symbol, allStrokes, allPivotZones, allTrendPatterns)
        }

        let allDivergences = state.divergence.getDivergences()
        let oldDivergenceN = state.lastCommittedDivergenceN
        let newDivergences = ArrayList<AlgoDivergence>()
        for (i in oldDivergenceN .. allDivergences.size) {
            newDivergences.add(allDivergences[i])
        }

        // 13. 走势结束判定：背驰出现 → 标记当前走势为已完成
        if (newDivergences.size > 0 && allTrendPatterns.size > 0) {
            let lastTP = allTrendPatterns[allTrendPatterns.size - 1]
            if (!lastTP.completed) {
                for (d in newDivergences) {
                    if (d.confirmed) {
                        let isMatch = (d.divergenceType == "bottomDivergence" && lastTP.direction == ChanDirection.Down) ||
                                      (d.divergenceType == "topDivergence" && lastTP.direction == ChanDirection.Up)
                        if (isMatch) {
                            state.trendPattern.markLastCompleted("divergence")
                            // 重新获取
                            // allTrendPatterns = state.trendPattern.getPatterns()
                            break
                        }
                    }
                }
            }
        }

        // 14. 更新提交水位
        state.lastCommittedElementN = elements.size
        state.lastCommittedFractalN = allFractals.size
        state.lastCommittedStrokeN = allStrokes.size
        state.lastCommittedSegN = allSegments.size
        state.lastCommittedPivotZoneN = allPivotZones.size
        state.lastCommittedTrendPatternN = allTrendPatterns.size
        state.lastCommittedDivergenceN = allDivergences.size

        let hasChange = newElements.size > 0 || newFractals.size > 0 ||
                        newStrokes.size > 0 || newSegments.size > 0 ||
                        newPivotZones.size > 0 || newTrendPatterns.size > 0 ||
                        newDivergences.size > 0

        PipelineOutput(state.symbol,
            newElements, newFractals,
            elements, allFractals,
            allStrokes, newStrokes,
            allSegments, newSegments,
            allPivotZones, newPivotZones,
            allTrendPatterns, newTrendPatterns,
            allDivergences, newDivergences,
            state.totalKlines, state.lastOpenTime, hasChange)
    }
}
