package trade

import std.collection.*

// ──────────────────────────────────────────────
// 缠论实时分析系统入口
// ──────────────────────────────────────────────

main(): Int64 {
    println("╔══════════════════════════════════════════════╗")
    println("║    缠论实时分析系统  Chan Theory Live Analyzer   ║")
    println("╚══════════════════════════════════════════════╝")
    println()

    // ── 1. Create the event bus ──
    let eventBus = EventBus()

    // ── 2. Subscribe console monitors ──
    eventBus.subscribe(EventType.KlineReceived, { e =>
        let klineOpt = e.data as Kline
        match (klineOpt) {
            case Some(k) =>
                println("[📊 Kline] ${k.symbol} ${k.interval} " +
                        "O:${k.open} H:${k.high} L:${k.low} C:${k.close} V:${k.volume}")
            case None => ()
        }
    })

    eventBus.subscribe(EventType.KlineClosed, { e =>
        let klineOpt = e.data as Kline
        match (klineOpt) {
            case Some(k) =>
                println("[✅ Closed] ${k.symbol} @${k.closeTime} C:${k.close}")
            case None => ()
        }
    })

    eventBus.subscribe(EventType.FractalDetected, { e =>
        let fractalOpt = e.data as Fractal
        match (fractalOpt) {
            case Some(f) =>
                let typeStr = match (f.ftype) {
                    case FractalType.Top => "顶分型 🔴"
                    case FractalType.Bottom => "底分型 🟢"
                }
                println("[🔍 Fractal] ${typeStr} idx=${f.index} " +
                        "t=${f.kline.time} H:${f.kline.high} L:${f.kline.low}")
            case None => ()
        }
    })

    eventBus.subscribe(EventType.ErrorEvent, { e =>
        let msgOpt = e.data as String
        match (msgOpt) {
            case Some(msg) => println("[❌ Error] ${msg}")
            case None => ()
        }
    })

    // ── 3. Create Chan Theory processors ──
    let merger = KlineMerger(eventBus)
    let _ = FractalRecognizer(merger, eventBus)

    // ── 4. Create Binance WebSocket client ──
    let wsClient = BinanceWSClient(eventBus)

    // ── 5. Connect to Binance ──
    let symbols = ArrayList<String>()
    symbols.add("btcusdt")
    symbols.add("ethusdt")

    println("[🚀] Connecting to Binance WebSocket...")
    println("[📡] Subscribing: ${symbols} @ 1m")
    println()

    wsClient.connect(symbols, "1m")

    // ── 6. Keep main thread alive ──
    println("[⏳] System running. Press Ctrl+C to stop.")
    println()

    while (true) {
        sleep(Duration.second * 60)
    }

    return 0
}
