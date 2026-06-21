package trade.infrastructure

import stdx.encoding.json.*
import std.convert.*
import trade.domain.*

// ──────────────────────────────────────────────
// Infrastructure — Binance K 线 JSON 解析器
// ──────────────────────────────────────────────

/// 从 Binance WebSocket JSON Object 中解析 Kline
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
