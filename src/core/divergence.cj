package trade.core

import std.collection.*
import trade.types.*

// 背驰判定（流式版）
// RingBuffer 保留最近 1 个背驰信号
// MACD 缓冲区已上限 200 条

public class DivergenceProcessor {
    private let divergences: RingBuffer<AlgoDivergence>
    private let macdValues: HashMap<String, ArrayList<Float64>>
    private let MAX_MACD: Int64 = 200

    public init() {
        this.divergences = RingBuffer<AlgoDivergence>(1)
        this.macdValues = HashMap<String, ArrayList<Float64>>()
    }

    public func feedClose(symbol: String, close: Float64): Unit {
        let list = match (macdValues.get(symbol)) {
            case Some(l) => l
            case None => let nl = ArrayList<Float64>(); macdValues.add(symbol, nl); nl
        }
        list.add(close)
        if (list.size > MAX_MACD) { list.remove(at: 0) }
    }

    /// 只接收最新必要数据，不接收全量列表
    public func process(symbol: String, entryPrice: Float64,
                         lastPatternDir: ChanDirection,
                         lastPatternCompleted: Bool): ArrayList<AlgoDivergence> {
        let result = ArrayList<AlgoDivergence>()
        if (lastPatternCompleted) { return result }
        let vals = match (macdValues.get(symbol)) {
            case Some(v) => v
            case None => return result
        }
        if (vals.size < 10) { return result }
        let macd = calcMACDArea(vals)
        let entryArea = macd * 0.6; let exitArea = macd * 0.4
        if (entryArea == 0.0) { return result }
        let ratio = exitArea / entryArea
        if (ratio >= 0.95) { return result }
        let dType = match (lastPatternDir) {
            case ChanDirection.Up => "topDivergence"
            case ChanDirection.Down => "bottomDivergence"
        }
        let d = AlgoDivergence(symbol, dType, true, entryArea, exitArea, ratio, entryPrice)
        divergences.add(d)
        result.add(d)
        result
    }

    public func getDivergences(): ArrayList<AlgoDivergence> { divergences.toArrayList() }
    public func reset(): Unit { divergences.clear(); macdValues.clear() }

    private func calcMACDArea(values: ArrayList<Float64>): Float64 {
        if (values.size < 3) { return 0.0 }
        let e12 = calcEMA(values, 12); let e26 = calcEMA(values, 26)
        var area = 0.0
        let n = if (e12.size < e26.size) { e12.size } else { e26.size }
        for (i in 0 .. n) { let d = e12[i] - e26[i]; if (d > 0.0) { area += d } }
        area
    }

    private func calcEMA(values: ArrayList<Float64>, period: Int64): ArrayList<Float64> {
        let result = ArrayList<Float64>()
        if (values.size == 0) { return result }
        let m = 2.0 / Float64(period); var ema = values[0]; result.add(ema)
        for (i in 1 .. values.size) { ema = (values[i] - ema) * m + ema; result.add(ema) }
        result
    }
}
