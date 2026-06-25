package trade

import std.collection.*
import std.sync.*
import trade.types.*
import trade.bus.*
import trade.conf.*
import trade.core.*
import trade.tree.*
import trade.levelz.*
import trade.engine.*
import trade.store.*
import trade.io.*

// ──────────────────────────────────────────────
// App 主控器
//
// 组装所有 M0-M10 模块，管理生命周期
// 事件订阅编排：Kline → Pipeline → Structure → Signal → Resonance → Snapshot
// ──────────────────────────────────────────────

public class App {
    private let config: Config
    private let bus: GenericBus

    // M3 结构树
    private let tree: Tree
    // M4 级别运行器
    private let l1Runner: LevelRunner
    // M5 信号引擎
    private let signalEngine: SignalEngine
    // M6 共振引擎
    private let resonanceEngine: ResonanceEngine
    // M7 状态存储
    private let stateStore: StateStore
    // M0 快照管理器
    private let snapshotManager: SnapshotManager
    // M1 数据源
    private let dataSource: DataSource
    // M8 API 服务
    private let apiGateway: ApiGateway
    // M2→M3 桥接
    private let bridge: M3Bridge

    // 级别构建器
    private let levelBuilder: LevelBuilder

    public init(config: Config) {
        this.config = config

        // 事件总线
        this.bus = GenericBus()

        // M7 状态存储
        this.stateStore = StateStore()

        // M0 快照管理器
        let snapConfig = SnapshotConfig(config.snapshotDir, config.snapshotRetain)
        this.snapshotManager = SnapshotManager(snapConfig)

        // M3 结构树
        this.tree = Tree(bus)

        // M5 信号引擎
        this.signalEngine = SignalEngine(bus)

        // M2 管线 + 桥接
        let pipeline = Pipeline(PivotZoneMode.Stroke)
        this.bridge = M3Bridge(pipeline, bus)
        this.bridge.withSignalSink(signalEngine)

        // M4 级别运行器
        this.l1Runner = LevelRunner(Level.L1, bus)

        // M6 共振引擎
        this.resonanceEngine = ResonanceEngine(bus, tree)

        // M4 级别构建器
        this.levelBuilder = LevelBuilder(bus, tree)

        // M1 数据源
        this.dataSource = DataSource(bus, config.redisAddr, UInt16(config.redisPort),
                                     config.symbols, config.streamPrefix, config.consumerGroup)

        // M8 API 服务
        this.apiGateway = ApiGateway(config.httpAddr, config.httpPort)

        // ── 事件订阅 ──
        setupEventSubscriptions()
    }

    /// 启动系统
    public func run(): Unit {
        println("╔══════════════════════════════════════════════╗")
        println("║    缠论实时分析系统  Chan Theory Live Analyzer   ║")
        println("╚══════════════════════════════════════════════╝")
        println()

        // 启动 M1 数据源
        dataSource.start()

        // 启动 M8 HTTP API
        let apiData = HashMap<String, Any>()
        apiGateway.start(apiData)

        println("[App] System initialized. Press Ctrl+C to stop.")
        println("[App] Monitoring: ${config.symbols}")

        // 主循环 — 定期输出心跳
        var tick: Int64 = 0
        while (true) {
            sleep(Duration.second * 10)
            tick++
            println("[App] Heartbeat #${tick} — system running")
        }
    }

    /// 停止系统
    public func shutdown(): Unit {
        println("[App] Shutting down...")
        dataSource.stop()
        apiGateway.stop()
        resonanceEngine.stop()
        println("[App] System stopped.")
    }

    // ── 事件订阅 ──

    private func setupEventSubscriptions(): Unit {
        // K 线到达 → L1 级别运行器 → M2→M3 桥接
        bus.subscribe(EventType.KlineReceived, { e =>
            let klineOpt = e.data as Kline
            match (klineOpt) {
                case Some(kline) =>
                    // 通过桥接器处理
                    let (changed, symbol) = bridge.onKline(kline)

                    // 喂入 L1 运行器
                    l1Runner.processKline(kline)

                    // 处理级别递归
                    if (changed) {
                        levelBuilder.processLevelRecursive(symbol)
                    }

                    // 打印当前状态
                    println("[App] Processed ${symbol} kline: open=${kline.open} high=${kline.high} low=${kline.low} close=${kline.close}")
                case None => ()
            }
        })

        // 分型发现 → 打印
        bus.subscribe(EventType.FractalDetected, { e =>
            let fractalOpt = e.data as Fractal
            match (fractalOpt) {
                case Some(f) =>
                    let typeStr = match (f.ftype) {
                        case FractalType.Top => "顶分型"
                        case FractalType.Bottom => "底分型"
                    }
                    println("[Fractal] ${typeStr} idx=${f.index} t=${f.kline.time} H:${f.kline.high} L:${f.kline.low}")
                case None => ()
            }
        })

        // 信号创建 → 打印 + 存储
        bus.subscribe(EventType.SignalCreated, { e =>
            let signalOpt = e.data as Signal
            match (signalOpt) {
                case Some(signal) =>
                    println("[Signal] ${signal.description} @ ${signal.price} strength=${signal.strength}")
                    stateStore.addSignal(signal)
                    // 触发共振检查
                    resonanceEngine.onSignalCreated(signal)
                case None => ()
            }
        })

        // 共振触发 → 打印
        bus.subscribe(EventType.ResonanceTriggered, { e =>
            let resonanceOpt = e.data as Resonance
            match (resonanceOpt) {
                case Some(r) =>
                    println("[Resonance] Signal ${r.signalId} boosted ${r.confidenceBoost}")
                case None => ()
            }
        })

        // 结构变更 → 触发快照
        bus.subscribe(EventType.StructureCommitted, { e =>
            println("[Tree] Structure version updated")
            // 简化的快照触发
            let snapshot = Snapshot("", "", ArrayList<Signal>(), None)
            snapshotManager.save("all", snapshot)
        })

        // 级别漂移 → 打印
        bus.subscribe(EventType.LevelRecast, { e =>
            let msgOpt = e.data as String
            match (msgOpt) {
                case Some(msg) => println("[Level] Recast: ${msg}")
                case None => ()
            }
        })

        // 错误 → 打印
        bus.subscribe(EventType.ErrorEvent, { e =>
            let msgOpt = e.data as String
            match (msgOpt) {
                case Some(msg) => println("[Error] ${msg}")
                case None => ()
            }
        })
    }
}
