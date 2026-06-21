package trade.application

import std.collection.*
import trade.domain.*
import trade.infrastructure.*

// ──────────────────────────────────────────────
// Application — LiveAnalysisService 实时分析用例
// 编排 WS 数据源 → 包含处理 → 分型识别的完整流程
// ──────────────────────────────────────────────

public class LiveAnalysisService {
    private let eventBus: InMemoryEventBus
    private let merger: MergerService
    private let fractalService: FractalService
    private let presenter: ConsolePresenter
    private let wsClient: BinanceClient

    public init(eventBus: InMemoryEventBus,
                merger: MergerService,
                fractalService: FractalService,
                presenter: ConsolePresenter,
                wsClient: BinanceClient) {
        this.eventBus = eventBus
        this.merger = merger
        this.fractalService = fractalService
        this.presenter = presenter
        this.wsClient = wsClient
    }

    /// 订阅领域事件，建立处理管道
    public func setup(): Unit {
        // K 线到达 → 展示
        eventBus.subscribe(EventType.KlineReceived, { e =>
            let klineOpt = e.data as Kline
            match (klineOpt) {
                case Some(k) => presenter.onKlineReceived(k)
                case None => ()
            }
        })

        // K 线收盘 → 包含处理 → 分型扫描
        eventBus.subscribe(EventType.KlineClosed, { e =>
            let klineOpt = e.data as Kline
            match (klineOpt) {
                case Some(kline) =>
                    merger.processKline(kline)
                    let merged = merger.getMergedKlines()
                    let fractals = fractalService.scan(merged)
                    for (f in fractals) {
                        eventBus.publish(Event(EventType.FractalDetected, f))
                    }
                    eventBus.publish(Event(EventType.MergeProcessed, true))
                case None =>
                    eventBus.publish(Event(EventType.ErrorEvent,
                        "KlineMerger: failed to cast event data to Kline"))
            }
        })

        // 分型发现 → 展示
        eventBus.subscribe(EventType.FractalDetected, { e =>
            let fractalOpt = e.data as Fractal
            match (fractalOpt) {
                case Some(f) => presenter.onFractalDetected(f)
                case None => ()
            }
        })

        // 错误 → 展示
        eventBus.subscribe(EventType.ErrorEvent, { e =>
            let msgOpt = e.data as String
            match (msgOpt) {
                case Some(msg) => presenter.onError(msg)
                case None => ()
            }
        })
    }

    /// 启动实时分析
    public func start(symbols: ArrayList<String>, interval: String): Unit {
        println("[System] Starting live analysis...")
        println("[System] Subscribing: ${symbols} @ ${interval}")
        wsClient.connect(symbols, interval)
        println("[System] Running. Press Ctrl+C to stop.")
    }
}
