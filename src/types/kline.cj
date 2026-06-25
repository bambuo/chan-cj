package trade.types

import std.deriving.*
// ──────────────────────────────────────────────
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

// ──────────────────────────────────────────────
// 合并 K 线（包含处理后）—— 运算符重载核心
// ──────────────────────────────────────────────
//
// 运算符语义：
//   a > b  ⇔  a 在 b 之上（高点更高且低点更高）→ 用于方向判定（向上）
//   a < b  ⇔  a 在 b 之下（高点更低且低点更低）→ 用于方向判定（向下）
//   a >= b ⇔  a 包含 b（高点≥b的高点且低点≤b的低点）
//   a <= b ⇔  a 被 b 包含
//   a + b  →  向上合并（取两边高点更高者、低点更高者）
//   a - b  →  向下合并（取两边高点更低者、低点更低者）
//
public struct ChanKline {
    public let time: Int64
    public let high: Float64
    public let low: Float64

    public init(time: Int64, high: Float64, low: Float64) {
        this.time = time
        this.high = high
        this.low = low
    }

    /// 方向判定：a > b 表示 a 在 b 之上（AND 条件）
    public operator func >(other: ChanKline): Bool {
        this.high > other.high && this.low > other.low
    }

    /// 方向判定：a < b 表示 a 在 b 之下（AND 条件）
    public operator func <(other: ChanKline): Bool {
        this.high < other.high && this.low < other.low
    }

    /// 包含关系：a >= b 表示 a 包含 b
    public operator func >=(other: ChanKline): Bool {
        this.high >= other.high && this.low <= other.low
    }

    /// 包含关系：a <= b 表示 a 被 b 包含
    public operator func <=(other: ChanKline): Bool {
        this.high <= other.high && this.low >= other.low
    }

    /// 向上合并：取两者高点的更高者、低点的更高者
    public operator func +(other: ChanKline): ChanKline {
        ChanKline(this.time,
            if (this.high > other.high) { this.high } else { other.high },
            if (this.low  > other.low)  { this.low  } else { other.low })
    }

    /// 向下合并：取两者高点的更低者、低点的更低者
    public operator func -(other: ChanKline): ChanKline {
        ChanKline(this.time,
            if (this.high < other.high) { this.high } else { other.high },
            if (this.low  < other.low)  { this.low  } else { other.low })
    }
}

// ──────────────────────────────────────────────
// 缠论基础枚举
// ──────────────────────────────────────────────

/// 趋势方向
public enum ChanTrend {
    | Up
    | Down
}

/// 分型类型
@Derive[Equatable]
public enum FractalType {
    | Top
    | Bottom
}

/// 分型
public struct Fractal {
    public let ftype: FractalType
    public let kline: ChanKline
    public let index: Int64    // 在合并序列中的索引

    public init(ftype: FractalType, kline: ChanKline, index: Int64) {
        this.ftype = ftype
        this.kline = kline
        this.index = index
    }
}
