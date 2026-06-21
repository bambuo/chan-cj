package trade

import stdx.encoding.json.*
import std.convert.*
import std.deriving.*

// ──────────────────────────────────────────────
// Raw K-line from Binance WebSocket
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
// Merged K-line after Chan Theory containment processing
// ──────────────────────────────────────────────

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

// ──────────────────────────────────────────────
// Trend direction for containment merge decisions
// ──────────────────────────────────────────────

public enum ChanTrend {
    | Up | Down
}

// ──────────────────────────────────────────────
// Fractal type (顶分型 / 底分型)
// ──────────────────────────────────────────────

public enum FractalType {
    | Top | Bottom
}

// ──────────────────────────────────────────────
// A recognized fractal
// ──────────────────────────────────────────────

public struct Fractal {
    public let ftype: FractalType
    public let kline: ChanKline   // the middle (peak/trough) k-line
    public let index: Int64        // position in the merged sequence

    public init(ftype: FractalType, kline: ChanKline, index: Int64) {
        this.ftype = ftype
        this.kline = kline
        this.index = index
    }
}

// ──────────────────────────────────────────────
// Event types — derives Hashable + Equatable so it
// can be used as a HashMap key in EventBus
// ──────────────────────────────────────────────

@Derive[Hashable, Equatable]
public enum EventType {
    | KlineReceived      // raw k-line from WS
    | KlineClosed        // k-line finalized (isClosed == true)
    | MergeProcessed     // Chan Theory merge completed → trigger fractal scan
    | FractalDetected    // new fractal found
    | ErrorEvent         // error occurred
}

// ──────────────────────────────────────────────
// Generic event payload
// ──────────────────────────────────────────────

public struct Event {
    public let eventType: EventType
    public let data: Any

    public init(eventType: EventType, data: Any) {
        this.eventType = eventType
        this.data = data
    }
}

// ──────────────────────────────────────────────
// Parse a single k-line from Binance WebSocket JSON
// ──────────────────────────────────────────────

public func parseKlineFromJson(kObj: JsonObject): Kline {
    let openTime = kObj["t"].asInt().getValue()
    let closeTime = kObj["T"].asInt().getValue()
    let symbol = kObj["s"].asString().getValue()
    let interval = kObj["i"].asString().getValue()
    let open = Float64.parse(kObj["o"].asString().getValue())
    let high = Float64.parse(kObj["h"].asString().getValue())
    let low = Float64.parse(kObj["l"].asString().getValue())
    let close = Float64.parse(kObj["c"].asString().getValue())
    let volume = Float64.parse(kObj["v"].asString().getValue())
    let isClosed = kObj["x"].asBool().getValue()

    return Kline(openTime, closeTime, symbol, interval,
                 open, high, low, close, volume, isClosed)
}
