package trade.core

import std.collection.*
import trade.types.*
import trade.store.*
import trade.log.*

let log = logger("管线")

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
    public var hasFirstSignal: Bool          // 是否已产出第一类买卖点

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
        this.hasFirstSignal = false
    }

    public func reset(): Unit {
        contain.reset(); fractal.reset(); stroke.reset(); segment.reset()
        pivotZone.reset(); trendPattern.reset(); divergence.reset()
        totalKlines = 0; hasFirstSignal = false
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
                pipe.push("chan_kline", RedisEntry(Float64(ck.time), ChanKlineRecord(ck.time, ck.high, ck.low).toJson()))
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
                pipe.push("fractal", RedisEntry(Float64(f.kline.time), FractalRecord(f.kline.time, ftype, f.kline.high, f.kline.low, f.index).toJson()))
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
                pipe.push("stroke", RedisEntry(Float64(kline.openTime), StrokeRecord(kline.openTime, s.start.time, s.end.time, dir, s.startIndex, s.endIndex, s.startPrice, s.endPrice, s.high, s.low).toJson()))
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
                pipe.push("segment", RedisEntry(Float64(kline.openTime), SegmentRecord(kline.openTime, seg.startTime, seg.endTime, seg.startPrice, seg.endPrice, dir, seg.startIndex, seg.endIndex).toJson()))
                hasChange = true
            }

            // ── Step 5: 中枢 ──
            newPivotZones = state.pivotZone.process(newStrokes)
            for (z in newPivotZones) {
                let dir = match (z.direction) { case ChanDirection.Up => "up" case ChanDirection.Down => "down" }
                pipe.push("pivot_zone", RedisEntry(Float64(kline.openTime), PivotZoneRecord(kline.openTime, z.startTime, z.endTime, z.startPrice, z.endPrice, z.zg, z.zd, z.startIndex, z.endIndex, dir, z.completed).toJson()))
                hasChange = true
            }

            // ── Step 6: 走势类型 ──
            newTrendPatterns = state.trendPattern.process(newPivotZones)
            for (tp in newTrendPatterns) {
                let tpDir = match (tp.direction) { case ChanDirection.Up => "up" case ChanDirection.Down => "down" }
                let tStartTime = if (tp.zones.size > 0) { tp.zones[0].startTime } else { 0 }
                let tEndTime = if (tp.zones.size > 0) { tp.zones[tp.zones.size - 1].endTime } else { 0 }
                let tStartPrice = if (tp.zones.size > 0) { tp.zones[0].startPrice } else { 0.0 }
                let tEndPrice = if (tp.zones.size > 0) { tp.zones[tp.zones.size - 1].endPrice } else { 0.0 }
                pipe.push("trend_pattern", RedisEntry(Float64(kline.openTime), TrendPatternRecord(kline.openTime, tStartTime, tEndTime, tStartPrice, tEndPrice, tpDir, tp.completed, tp.zones.size).toJson()))
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
            pipe.push("divergence", RedisEntry(Float64(kline.openTime), DivergenceRecord(kline.openTime, kline.close, d.divergenceType, d.ratio, d.confirmed).toJson()))
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

        // ── Step 9: 买卖点识别 ──
        // 第一类买卖点（背驰）
        for (d in newDivergences) {
            let signalType = match (d.divergenceType) {
                case "bottomDivergence" => "Buy1"
                case "topDivergence" => "Sell1"
                case _ => ""
            }
            if (signalType != "") {
                pipe.push("signal", RedisEntry(Float64(kline.openTime), SignalRecord(kline.openTime, signalType, kline.close, 0.8).toJson()))
                hasChange = true
                state.hasFirstSignal = true
            }
        }

        // 第三类买卖点（中枢完成）
        if (newPivotZones.size > 0) {
            for (z in newPivotZones) {
                if (z.completed) {
                    let signalType = match (z.direction) {
                        case ChanDirection.Down => "Buy3"
                        case ChanDirection.Up => "Sell3"
                    }
                    pipe.push("signal", RedisEntry(Float64(kline.openTime), SignalRecord(kline.openTime, signalType, kline.close, 0.7).toJson()))
                    hasChange = true
                }
            }
        }

        // 第二类买卖点（已有第一类后的回调方向）
        if (state.hasFirstSignal) {
            let patterns = state.trendPattern.getPatterns()
            if (patterns.size > 0) {
                let lastTP = patterns[patterns.size - 1]
                let signalType = match (lastTP.direction) {
                    case ChanDirection.Up => "Buy2"
                    case ChanDirection.Down => "Sell2"
                }
                pipe.push("signal", RedisEntry(Float64(kline.openTime), SignalRecord(kline.openTime, signalType, kline.close, 0.6).toJson()))
                hasChange = true
            }
        }

        // 检查完成趋势——用于级别升级
        // 用 process() 返回值 newTrendPatterns，它包含刚被标记完成的旧走势
        for (tp in newTrendPatterns) {
            if (tp.completed) {
                hasCompletedTrend = true
                trendDir = tp.direction
                if (tp.zones.size > 0) {
                    trendHigh = tp.zones[0].zg
                    trendLow = tp.zones[0].zd
                }
                break
            }
        }

        ProcessResult(symbol, kline.openTime, hasCompletedTrend, trendDir, trendHigh, trendLow, hasChange)
    }
}
