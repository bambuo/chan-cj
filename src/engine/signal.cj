package trade.engine

import std.collection.*
import trade.types.*
import trade.bus.*

// ──────────────────────────────────────────────
// M5 信号引擎 — 三类买卖点识别
//
// 状态机：Candidate → Confirmed / Invalidated / Superseded
// 识别：Buy1/Sell1(背驰), Buy2/Sell2(回调), Buy3/Sell3(中枢)
// ──────────────────────────────────────────────

public class SignalEngine <: SignalSink {
    private let bus: GenericBus
    private let signals: ArrayList<Signal>
    private var signalCounter: Int64

    public init(bus: GenericBus) {
        this.bus = bus
        this.signals = ArrayList<Signal>()
        this.signalCounter = 0
    }

    /// 从桥接层接收信号输入（实现 SignalSink 接口）
    public func onSignalInput(input: SignalInput): Unit {
        recognize(input)
    }

    /// 获取所有信号
    public func getSignals(): ArrayList<Signal> {
        let copy = ArrayList<Signal>()
        for (s in signals) { copy.add(s) }
        copy
    }

    /// 获取指定 symbol 的信号
    public func getSignalsBySymbol(symbol: String): ArrayList<Signal> {
        let result = ArrayList<Signal>()
        for (s in signals) {
            if (s.symbol == symbol) { result.add(s) }
        }
        result
    }

    // ── 识别逻辑 ──

    private func recognize(input: SignalInput): Unit {
        // 第一类买卖点（背驰）
        if (input.hasDivergence) {
            recognizeFirstClass(input)
        }

        // 第三类买卖点（中枢突破后回抽）
        if (input.hasCompletedPivot) {
            recognizeThirdClass(input)
        }

        // 第二类买卖点（第一类之后的回调）
        if (hasFirstClassSignal(input.symbol)) {
            recognizeSecondClass(input)
        }
    }

    /// 第一类买卖点（趋势背驰）
    private func recognizeFirstClass(input: SignalInput): Unit {
        if (!input.hasDivergence) { return }

        let signalType = match (input.divergenceType) {
            case "bottomDivergence" => SignalType.Buy1
            case "topDivergence" => SignalType.Sell1
            case _ => return
        }

        signalCounter++
        let signal = createSignal(input.symbol, signalType, 0.0, input.level, 0.8)
        signals.add(signal)
        bus.publish(Event(EventType.SignalCreated, signal))
    }

    /// 第二类买卖点
    private func recognizeSecondClass(input: SignalInput): Unit {
        // 在已有第一类信号后，用趋势方向判断
        signalCounter++
        let signalType = match (input.trendDirection) {
            case "Up" => SignalType.Buy2
            case "Down" => SignalType.Sell2
            case _ => return
        }
        let signal = createSignal(input.symbol, signalType, 0.0, input.level, 0.6)
        signals.add(signal)
        bus.publish(Event(EventType.SignalCreated, signal))
    }

    /// 第三类买卖点
    private func recognizeThirdClass(input: SignalInput): Unit {
        if (!input.hasCompletedPivot) { return }

        // 简化：只要完成的中枢就触发信号
        signalCounter++
        let signalType = match (input.trendDirection) {
            case "Up" => SignalType.Buy3
            case "Down" => SignalType.Sell3
            case _ => return
        }
        let signal = createSignal(input.symbol, signalType, 0.0, input.level, 0.7)
        signals.add(signal)
        bus.publish(Event(EventType.SignalCreated, signal))
    }

    // ── 辅助 ──

    private func hasFirstClassSignal(symbol: String): Bool {
        for (s in signals) {
            if (s.symbol == symbol &&
                (s.signalType == SignalType.Buy1 || s.signalType == SignalType.Sell1)) {
                return true
            }
        }
        false
    }

    private func createSignal(symbol: String, signalType: SignalType,
                               price: Float64, level: Level, strength: Float64): Signal {
        let typeName = match (signalType) {
            case SignalType.Buy1 => "Buy1"
            case SignalType.Buy2 => "Buy2"
            case SignalType.Buy3 => "Buy3"
            case SignalType.Sell1 => "Sell1"
            case SignalType.Sell2 => "Sell2"
            case SignalType.Sell3 => "Sell3"
        }
        Signal("sig_${signalCounter}", symbol, signalType, SignalState.Confirmed,
               price, 0, level, strength, typeName)
    }
}
