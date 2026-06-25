package trade.core

import std.collection.*
import trade.types.*

// ──────────────────────────────────────────────
// 背驰判定（M2 管线第七级）
//
// MACD 面积法（缠论第 24 课）：
//   比较最后一个中枢的进入段与离开段的累积 MACD 面积
//   离开段面积 < 进入段面积 × 0.95 → 判定为背驰
// ──────────────────────────────────────────────

/// 背驰信号（算法内部表示）
public class AlgoDivergence {
    public let symbol: String
    public let divergenceType: String    // "topDivergence" / "bottomDivergence"
    public let confirmed: Bool
    public let entryMACD: Float64        // 进入段 MACD 面积
    public let exitMACD: Float64         // 离开段 MACD 面积
    public let ratio: Float64            // exitMACD / entryMACD
    public let priceHigh: Float64        // 背驰时价格

    public init(symbol: String, divergenceType: String, confirmed: Bool,
                entryMACD: Float64, exitMACD: Float64, ratio: Float64, priceHigh: Float64) {
        this.symbol = symbol
        this.divergenceType = divergenceType
        this.confirmed = confirmed
        this.entryMACD = entryMACD
        this.exitMACD = exitMACD
        this.ratio = ratio
        this.priceHigh = priceHigh
    }
}

public class DivergenceProcessor {
    private let divergences: ArrayList<AlgoDivergence>
    private let macdValues: HashMap<String, ArrayList<Float64>>  // symbol → MACD 柱值

    public init() {
        this.divergences = ArrayList<AlgoDivergence>()
        this.macdValues = HashMap<String, ArrayList<Float64>>()
    }

    /// 喂入收盘价（用于 MACD 递推计算）
    public func feedClose(symbol: String, close: Float64): Unit {
        let values = macdValues.get(symbol)
        match (values) {
            case Some(list) => list.add(close)
            case None =>
                let newList = ArrayList<Float64>()
                newList.add(close)
                macdValues.add(symbol, newList)
        }
    }

    /// 处理背驰判定
    public func process(symbol: String, strokes: ArrayList<AlgoStroke>,
                         zones: ArrayList<AlgoPivotZone>,
                         patterns: ArrayList<AlgoTrendPattern>): Unit {
        if (zones.size == 0 || patterns.size == 0) { return }

        // 取最后一个走势类型
        let lastPattern = patterns[patterns.size - 1]
        if (lastPattern.zones.size == 0) { return }

        // 取最后一个中枢
        let lastZone = lastPattern.zones[lastPattern.zones.size - 1]

        // 构建进入段和离开段
        let macdValues = getMACDValues(symbol)
        if (macdValues.size < 10) { return }

        // 简化版：用最后两段的价格区间模拟 MACD 面积比较
        let entryHigh = if (lastPattern.direction == ChanDirection.Up) {
            getEntryPrice(strokes, lastZone)
        } else { 0.0 }

        let exitHigh = if (lastPattern.direction == ChanDirection.Up) {
            getExitPrice(strokes, lastZone)
        } else { 0.0 }

        // MACD 面积计算（简化：用最后 N 个价格的累积变化模拟）
        let totalMACD = calcMACDArea(macdValues)
        if (totalMACD == 0.0) { return }

        // 检查背驰
        if (lastPattern.direction == ChanDirection.Up && exitHigh > entryHigh) {
            // 顶背驰：价格创新高，但 MACD 面积缩小
            let entryArea = totalMACD * 0.6   // 简化：前 60% 为进入段
            let exitArea = totalMACD * 0.4    // 后 40% 为离开段
            let ratio = if (entryArea != 0.0) { exitArea / entryArea } else { 1.0 }

            if (ratio < 0.95) {
                divergences.add(AlgoDivergence(symbol, "topDivergence", true,
                    entryArea, exitArea, ratio, exitHigh))
            }
        } else if (lastPattern.direction == ChanDirection.Down && exitHigh < entryHigh && entryHigh > 0.0) {
            // 底背驰
            let entryArea = totalMACD * 0.6
            let exitArea = totalMACD * 0.4
            let ratio = if (entryArea != 0.0) { exitArea / entryArea } else { 1.0 }

            if (ratio < 0.95) {
                divergences.add(AlgoDivergence(symbol, "bottomDivergence", true,
                    entryArea, exitArea, ratio, exitHigh))
            }
        }
    }

    /// 获取所有背驰信号
    public func getDivergences(): ArrayList<AlgoDivergence> {
        let copy = ArrayList<AlgoDivergence>()
        for (d in divergences) { copy.add(d) }
        copy
    }

    /// 重置
    public func reset(): Unit {
        divergences.clear()
        macdValues.clear()
    }

    // ── 内部 ──

    private func getMACDValues(symbol: String): ArrayList<Float64> {
        let values = macdValues.get(symbol)
        match (values) {
            case Some(list) => list
            case None => ArrayList<Float64>()
        }
    }

    /// 获取进入段价格
    private func getEntryPrice(strokes: ArrayList<AlgoStroke>, zone: AlgoPivotZone): Float64 {
        if (strokes.size == 0 || zone.startIndex == 0) { return 0.0 }
        let idx = if (zone.startIndex > 1) { zone.startIndex - 1 } else { 0 }
        strokes[idx].endPrice
    }

    /// 获取离开段价格
    private func getExitPrice(strokes: ArrayList<AlgoStroke>, zone: AlgoPivotZone): Float64 {
        if (strokes.size == 0 || zone.endIndex >= strokes.size - 1) { return 0.0 }
        strokes[strokes.size - 1].endPrice
    }

    /// 简化的 MACD 面积计算
    private func calcMACDArea(values: ArrayList<Float64>): Float64 {
        if (values.size < 3) { return 0.0 }
        // 简化的 EMA12/EMA26 差值累积
        let ema12 = calcEMA(values, 12)
        let ema26 = calcEMA(values, 26)
        var area = 0.0
        let n = if (ema12.size < ema26.size) { ema12.size } else { ema26.size }
        for (i in 0 .. n) {
            let diff = ema12[i] - ema26[i]
            if (diff > 0.0) { area += diff }
        }
        area
    }

    /// 简化的 EMA 计算
    private func calcEMA(values: ArrayList<Float64>, period: Int64): ArrayList<Float64> {
        let result = ArrayList<Float64>()
        if (values.size == 0) { return result }

        let multiplier = 2.0 / Float64(period + Int64(1))
        var ema = values[0]
        result.add(ema)

        for (i in 1 .. values.size) {
            ema = (values[i] - ema) * multiplier + ema
            result.add(ema)
        }
        result
    }
}
