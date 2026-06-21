package trade

import std.collection.*
import trade.application.*
import trade.domain.*
import trade.infrastructure.*

// ──────────────────────────────────────────────
// Entry Point — 依赖注入 + 系统启动
// ──────────────────────────────────────────────

main(): Int64 {
    println("╔══════════════════════════════════════════════╗")
    println("║    缠论实时分析系统  Chan Theory Live Analyzer   ║")
    println("╚══════════════════════════════════════════════╝")
    println()

    // ── 1. Bootstrap infrastructure ──
    let eventBus = InMemoryEventBus()

    // ── 2. Bootstrap domain services ──
    let merger = MergerService()
    let fractalService = FractalService()

    // ── 3. Bootstrap application layer ──
    let presenter = ConsolePresenter()
    let wsClient = BinanceClient(eventBus)

    let analysisService = LiveAnalysisService(
        eventBus, merger, fractalService, presenter, wsClient
    )

    // ── 4. Wire up event pipeline ──
    analysisService.setup()

    // ── 5. Start ──
    let symbols = ArrayList<String>()
    symbols.add("btcusdt")
    symbols.add("ethusdt")

    analysisService.start(symbols, "1m")

    // ── 6. Keep alive ──
    while (true) {
        sleep(Duration.second * 60)
    }

    return 0
}
