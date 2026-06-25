package trade.core

import std.collection.*
import trade.types.*
import trade.store.*
import trade.log.*

let log = logger("M2")

// ──────────────────────────────────────────────
// 流式管线
// 每个步骤产出增量，即时推入 OutputPipe → Redis
// 返回值仅含升级所需信息
// ──────────────────────────────────────────────

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

    public init(symbol: String) {
        this.symbol = symbol
        this.contain = ContainProcessor()
        this.fractal = FractalProcessor()
        this.stroke = StrokeProcessor(true)
        this.segment = SegmentProcessor()
        this.pivotZone = PivotZoneProcessor(PivotZoneMode.Stroke)
        this.trendPattern = TrendPatternProcessor()
        this.divergence = DivergenceProcessor()
        this.totalKlines = 0
    }

    public func reset(): Unit {
        contain.reset(); fractal.reset(); stroke.reset(); segment.reset()
        pivotZone.reset(); trendPattern.reset(); divergence.reset(); totalKlines = 0
    }
}

public class Pipeline {
    private let symbols: HashMap<String, SymbolState>

    public init() { this.symbols = HashMap<String, SymbolState>() }

    public func getOrCreate(symbol: String): SymbolState {
        match (symbols.get(symbol)) {
            case Some(s) => s
            case None => let ns = SymbolState(symbol); symbols.add(symbol, ns); ns
        }
    }

    public func reset(symbol: String): Unit {
        match (symbols.get(symbol)) { case Some(s) => s.reset() case None => () }
    }

    /// 流式处理：每步只产增量，即时推入 OutputPipe
    public func process(kline: Kline, pipe: OutputPipe): ProcessResult {
        let symbol = kline.symbol.toAsciiLower()
        let state = getOrCreate(symbol)
        state.totalKlines++

        var hasChange = false
        var hasCompletedTrend = false
        var trendDir = ChanDirection.Up
        var trendHigh = 0.0
        var trendLow = 0.0

        // ── Step 1: 包含处理 ──
        let merged = state.contain.process(kline)
        match (merged) {
            case Some(ck) =>
                pipe.push(RedisEntry(Float64(ck.time), "merged:${ck.high},${ck.low}"))
                hasChange = true
            case None => ()
        }

        // ── Step 2: 分型识别 ──
        let (lastElements, baseOffset) = state.contain.getLastWithOffset(3)
        let newFractals = state.fractal.scan(lastElements, baseOffset)
        for (f in newFractals) {
            let ftype = match (f.ftype) {
                case FractalType.Top => "top"
                case FractalType.Bottom => "bottom"
            }
            pipe.push(RedisEntry(Float64(f.kline.time), "fractal:${ftype},${f.kline.high},${f.kline.low},${f.index}"))
            hasChange = true
        }

        // ── Step 3: 笔识别 ──
        let latestCk = state.contain.getLatest()
        let newStrokes = ArrayList<AlgoStroke>()
        for (f in newFractals) {
            let lk = match (latestCk) { case Some(ck) => ck case None => ChanKline(0, 0.0, 0.0) }
            let ns = state.stroke.process(f, lk, false)
            for (s in ns) {
                let dir = match (s.direction) { case ChanDirection.Up => "up" case ChanDirection.Down => "down" }
                pipe.push(RedisEntry(Float64(s.endIndex), "stroke:${dir},${s.startIndex},${s.endIndex},${s.startPrice},${s.endPrice},${s.high},${s.low}"))
                newStrokes.add(s)
                hasChange = true
            }
        }

        // ── Step 4: 线段 ──
        var newSegments = ArrayList<AlgoSegment>()
        var newPivotZones = ArrayList<AlgoPivotZone>()
        var newTrendPatterns = ArrayList<AlgoTrendPattern>()
        if (newStrokes.size > 0) {
            newSegments = state.segment.process(newStrokes)
            for (seg in newSegments) {
                let dir = match (seg.direction) { case ChanDirection.Up => "up" case ChanDirection.Down => "down" }
                pipe.push(RedisEntry(Float64(seg.endIndex), "segment:${dir},${seg.startIndex},${seg.endIndex}"))
                hasChange = true
            }

            // ── Step 5: 中枢 ──
            newPivotZones = state.pivotZone.process(newStrokes)
            for (z in newPivotZones) {
                let dir = match (z.direction) { case ChanDirection.Up => "up" case ChanDirection.Down => "down" }
                pipe.push(RedisEntry(Float64(z.endIndex), "pivot:${z.zg},${z.zd},${z.startIndex},${z.endIndex},${dir},${z.completed}"))
                hasChange = true
            }

            // ── Step 6: 走势类型 ──
            newTrendPatterns = state.trendPattern.process(newPivotZones)
            for (tp in newTrendPatterns) {
                let tpDir = match (tp.direction) { case ChanDirection.Up => "up" case ChanDirection.Down => "down" }
                pipe.push(RedisEntry(Float64(0), "trend:${tpDir},${tp.completed},${tp.zones.size}"))
                hasChange = true
            }
        }

        // ── Step 7: 背驰 ──
        state.divergence.feedClose(symbol, kline.close)

        var lastDir = ChanDirection.Up
        var lastCompleted = false
        var entryPrice = 0.0
        if (newTrendPatterns.size > 0) {
            let last = newTrendPatterns[newTrendPatterns.size - 1]
            lastDir = last.direction
            lastCompleted = last.completed
            if (newStrokes.size > 0) { entryPrice = newStrokes[newStrokes.size - 1].endPrice }
        }
        let newDivergences = state.divergence.process(symbol, entryPrice, lastDir, lastCompleted)
        for (d in newDivergences) {
            pipe.push(RedisEntry(Float64(0), "divergence:${d.divergenceType},${d.ratio},${d.confirmed}"))
            hasChange = true
        }

        // ── Step 8: 走势结束判定（背驰→标记完成） ──
        if (newDivergences.size > 0 && newTrendPatterns.size > 0) {
            let lastTP = newTrendPatterns[newTrendPatterns.size - 1]
            if (!lastTP.completed) {
                for (d in newDivergences) {
                    let m = (d.divergenceType == "bottomDivergence" && lastTP.direction == ChanDirection.Down) ||
                            (d.divergenceType == "topDivergence" && lastTP.direction == ChanDirection.Up)
                    if (m) { state.trendPattern.markLastCompleted("divergence"); break }
                }
            }
        }

        // 清理 contain 尾部
        state.contain.trim()

        // 检查完成趋势——用于级别升级
        // 注意：走势类型处理器可能在本轮标记完成了之前的未完成走势
        // 需要从 state.trendPattern 中检查最新走势是否已完成
        let allPatterns = state.trendPattern.getPatterns()
        if (allPatterns.size > 0) {
            let last = allPatterns[allPatterns.size - 1]
            if (last.completed) {
                hasCompletedTrend = true
                trendDir = last.direction
                if (last.zones.size > 0) {
                    trendHigh = last.zones[0].zg
                    trendLow = last.zones[0].zd
                }
            }
        }

        ProcessResult(symbol, hasCompletedTrend, trendDir, trendHigh, trendLow, hasChange)
    }

    public func trimMemory(symbol: String): Unit {
        match (symbols.get(symbol)) { case Some(s) => s.contain.trim() case None => () }
    }
}
