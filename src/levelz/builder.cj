package trade.levelz

import std.collection.*
import trade.types.*
import trade.core.*
import trade.tree.*
import trade.bus.*

// ──────────────────────────────────────────────
// M4 级别构建器
//
// 将当前级别已完成的走势类型 → 合成 K 线 → 输入下一级别管线
// L(N) 的已完成走势类型 → L(N+1) 的合成 K 线
// ──────────────────────────────────────────────

/// 级别构建器
public class LevelBuilder {
    private let bus: GenericBus
    private let tree: Tree

    public init(bus: GenericBus, tree: Tree) {
        this.bus = bus
        this.tree = tree
    }

    /// 处理结构版本变更，尝试构建下一级别
    public func processLevelRecursive(symbol: String): Unit {
        // 从 L1 开始逐级向上构建
        for (level in [Level.L1, Level.L2, Level.L3]) {
            let nextLevel = nextLevel(level)
            match (nextLevel) {
                case Some(nl) => buildHigherLevel(symbol, level, nl)
                case None => ()
            }
        }
    }

    // ── 内部 ──

    private func buildHigherLevel(symbol: String, fromLevel: Level, toLevel: Level): Unit {
        let currentStruct = tree.getLatestStructure(symbol, fromLevel)
        match (currentStruct) {
            case Some(ls) =>
                // 获取已完成的走势类型
                let completedPatterns = ArrayList<TrendPattern>()
                for (tp in ls.trendPatterns) {
                    if (tp.completed) {
                        completedPatterns.add(tp)
                    }
                }

                if (completedPatterns.size >= 2) {
                    // 简化的级别提升：走势类型 → 合成 K 线
                    // 这里触发级别变更事件
                    bus.publish(Event(EventType.LevelRecast,
                        "symbol:${symbol}, level recast"))
                }
            case None => ()
        }
    }

    private func nextLevel(current: Level): ?Level {
        match (current) {
            case Level.L1 => Some(Level.L2)
            case Level.L2 => Some(Level.L3)
            case Level.L3 => Some(Level.L4)
            case _ => None
        }
    }
}
