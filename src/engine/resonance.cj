package trade.engine

import std.collection.*
import trade.types.*
import trade.tree.*
import trade.bus.*

// ──────────────────────────────────────────────
// M6 共振引擎
//
// 评估信号的多级别共振：
//   G-2: 区间套嵌套（低级别背驰与高级别趋势一致）
//   G-1: 跨级别共振（多个级别同时出现同类信号）
//   A3:  方向对齐（各级别走势方向一致）
// ──────────────────────────────────────────────

public class ResonanceEngine {
    private let bus: GenericBus
    private let tree: Tree

    public init(bus: GenericBus, tree: Tree) {
        this.bus = bus
        this.tree = tree
    }

    /// 处理信号创建事件
    public func onSignalCreated(signal: Signal): Unit {
        // 简化的共振检查
        if (signal.strength < 0.5) { return }

        // 检查跨级别一致性
        checkCrossLevel(signal)
    }

    /// 停止引擎
    public func stop(): Unit {
        // 清理资源（如有）
    }

    // ── 内部 ──

    private func checkCrossLevel(signal: Signal): Unit {
        // 简化的跨级别检查：查看高低级别的结构方向
        let higherLevel = tree.getLatestStructure(signal.symbol, Level(2))
        match (higherLevel) {
            case Some(ls) =>
                if (ls.trendPatterns.size > 0) {
                    let lastTP = ls.trendPatterns[ls.trendPatterns.size - 1]
                    let directionMatch = match (signal.signalType) {
                        case SignalType.Buy1 | SignalType.Buy2 | SignalType.Buy3 =>
                            lastTP.direction == ChanDirection.Down  // 下跌趋势后的买点
                        case SignalType.Sell1 | SignalType.Sell2 | SignalType.Sell3 =>
                            lastTP.direction == ChanDirection.Up    // 上涨趋势后的卖点
                    }

                    if (directionMatch) {
                        let resonance = Resonance(signal.id, ResonanceKind.G1_CrossLevel, 0.15)
                        bus.publish(Event(EventType.ResonanceTriggered, resonance))
                    }
                }
            case None => ()
        }
    }
}
