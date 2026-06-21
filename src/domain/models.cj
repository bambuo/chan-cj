package trade.domain

import stdx.encoding.json.*
import std.convert.*
import std.deriving.*

// ──────────────────────────────────────────────
// Value Objects — 缠论领域模型
// ──────────────────────────────────────────────

/// 原始 K 线（来自交易所）
public struct Kline {
    public let openTime: Int64
    public let closeTime: Int64
    public let symbol: String
    public let interval: String
    public let open: Float64
    public let high: Float64
    public let low: Float64
    public let close: Float64
    public let volume: Float64
    public let isClosed: Bool

    public init(openTime: Int64, closeTime: Int64, symbol: String, interval: String,
                open: Float64, high: Float64, low: Float64, close: Float64,
                volume: Float64, isClosed: Bool) {
        this.openTime = openTime
        this.closeTime = closeTime
        this.symbol = symbol
        this.interval = interval
        this.open = open
        this.high = high
        this.low = low
        this.close = close
        this.volume = volume
        this.isClosed = isClosed
    }
}

/// 缠论合并后的 K 线（仅保留 high/low）
public struct ChanKline {
    public let time: Int64
    public let high: Float64
    public let low: Float64

    public init(time: Int64, high: Float64, low: Float64) {
        this.time = time
        this.high = high
        this.low = low
    }
}

/// 趋势方向（用于包含处理决策）
public enum ChanTrend {
    | Up | Down
}

/// 分型类型
public enum FractalType {
    | Top | Bottom
}

/// 识别到的分型
public struct Fractal {
    public let ftype: FractalType
    public let kline: ChanKline
    public let index: Int64

    public init(ftype: FractalType, kline: ChanKline, index: Int64) {
        this.ftype = ftype
        this.kline = kline
        this.index = index
    }
}

// ──────────────────────────────────────────────
// Domain Events — 领域事件
// ──────────────────────────────────────────────

@Derive[Hashable, Equatable]
public enum EventType {
    | KlineReceived      // 原始 K 线到达
    | KlineClosed        // K 线收盘
    | MergeProcessed     // 包含处理完成
    | FractalDetected    // 新分型发现
    | ErrorEvent         // 错误
}

public struct Event {
    public let eventType: EventType
    public let data: Any

    public init(eventType: EventType, data: Any) {
        this.eventType = eventType
        this.data = data
    }
}
