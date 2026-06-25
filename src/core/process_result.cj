package trade.core

import trade.types.*

// ──────────────────────────────────────────────
// Pipeline 处理结果（替代 PipelineOutput）
//
// process() 不再返回大量数据，只返回升级所需信息。
// 各节点的产出已通过 OutputPipe 即时流入 Redis。
// ──────────────────────────────────────────────

/// 管线处理结果
public struct ProcessResult {
    public let symbol: String
    public let hasCompletedTrend: Bool
    public let trendDirection: ChanDirection
    public let trendHigh: Float64
    public let trendLow: Float64
    public let hasChange: Bool

    public init(symbol: String,
                hasCompletedTrend: Bool,
                trendDirection: ChanDirection,
                trendHigh: Float64,
                trendLow: Float64,
                hasChange: Bool) {
        this.symbol = symbol
        this.hasCompletedTrend = hasCompletedTrend
        this.trendDirection = trendDirection
        this.trendHigh = trendHigh
        this.trendLow = trendLow
        this.hasChange = hasChange
    }
}
