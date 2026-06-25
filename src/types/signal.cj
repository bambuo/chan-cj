package trade.types

import std.collection.*
import std.deriving.*

// ──────────────────────────────────────────────
// 信号类型（三类买卖点 + 共振信息）
// ──────────────────────────────────────────────

/// 信号引擎接收器接口
public interface SignalSink {
    func onSignalInput(input: SignalInput): Unit
}

/// 信号类型 — 缠论的三类买卖点
@Derive[Equatable]
public enum SignalType {
    | Buy1     // 第一类买点（趋势背驰）
    | Buy2     // 第二类买点（回调不创新低）
    | Buy3     // 第三类买点（回抽不跌回中枢）
    | Sell1    // 第一类卖点（趋势背驰）
    | Sell2    // 第二类卖点（回抽不创新高）
    | Sell3    // 第三类卖点（回升不涨回中枢）
}

/// 信号状态 — 状态机
public enum SignalState {
    | Candidate     // 候选：刚识别，待确认
    | Confirmed     // 已确认：条件完全满足
    | Invalidated   // 已失效：后续走势否定了该信号
    | Superseded    // 已被取代：更优信号出现
}

/// 信号 — 完整的买卖点定义
public struct Signal {
    public let id: String
    public let symbol: String
    public let signalType: SignalType
    public let state: SignalState
    public let price: Float64
    public let time: Int64
    public let level: Level
    public let strength: Float64        // 信号力度 (0.0 ~ 1.0)
    public let description: String

    public init(id: String, symbol: String, signalType: SignalType, state: SignalState,
                price: Float64, time: Int64, level: Level, strength: Float64,
                description: String) {
        this.id = id
        this.symbol = symbol
        this.signalType = signalType
        this.state = state
        this.price = price
        this.time = time
        this.level = level
        this.strength = strength
        this.description = description
    }
}

/// 共振类型
public enum ResonanceKind {
    | G2_Nesting       // G-2 区间套嵌套
    | G1_CrossLevel    // G-1 跨级别共振
    | A3_Alignment     // A3 方向对齐
}

/// 共振信息
public struct Resonance {
    public let signalId: String
    public let kind: ResonanceKind
    public let confidenceBoost: Float64  // 置信度提升量

    public init(signalId: String, kind: ResonanceKind, confidenceBoost: Float64) {
        this.signalId = signalId
        this.kind = kind
        this.confidenceBoost = confidenceBoost
    }
}

/// 信号引擎输入
public struct SignalInput {
    public let symbol: String
    public let level: Level
    public let price: Float64         // 当前价格（用于买卖点定价）
    public let hasDivergence: Bool
    public let divergenceType: String  // "topDivergence" / "bottomDivergence"
    public let trendDirection: String  // "Up" / "Down"
    public let hasCompletedPivot: Bool

    public init(symbol: String, level: Level, price: Float64,
                hasDivergence: Bool, divergenceType: String,
                trendDirection: String, hasCompletedPivot: Bool) {
        this.symbol = symbol
        this.level = level
        this.price = price
        this.hasDivergence = hasDivergence
        this.divergenceType = divergenceType
        this.trendDirection = trendDirection
        this.hasCompletedPivot = hasCompletedPivot
    }
}
