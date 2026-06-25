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
import trade.log.*
import redis.client.*

let appLog = logger("App")

// ──────────────────────────────────────────────
// App 主控器
//
// 组装所有 M0-M10 模块，管理生命周期
// 事件订阅编排：Kline → LevelRunner L1 → (自动链式升级)
// ──────────────────────────────────────────────

public class App {
    private let config: Config
    private let bus: GenericBus

    // M4 级别运行器（只持有 L1，L2+ 按需创建）
    private let l1: LevelRunner

    // 其他模块
    private let tree: Tree
    private let signalEngine: SignalEngine
    private let resonanceEngine: ResonanceEngine
    private let stateStore: StateStore
    private let snapshotManager: SnapshotManager
    private let resultStore: ResultStore
    private let dataSource: DataSource
    private let apiGateway: ApiGateway

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

        // 结果持久化
        var rsClient: ?RedisClient = None
        try {
            rsClient = Some(RedisClient(config.redisAddr, UInt16(config.redisPort), autoHello: false))
        } catch (e: Exception) {
            appLog.warn("ResultStore: Redis 不可用，结果不持久化: ${e}")
        }
        this.resultStore = match (rsClient) {
            case Some(c) => ResultStore(c)
            case None => ResultStore.newDisabled()
        }

        // M4 级别运行器 L1（L2+ 按需创建）
        // 每个 symbol 一个 LevelRunner，这里简化：取第一个 symbol
        let primarySymbol = if (config.symbols.size > 0) {
            config.symbols[0]
        } else {
            "BTCUSDT"
        }
        this.l1 = LevelRunner(1, primarySymbol, resultStore)

        // M6 共振引擎
        this.resonanceEngine = ResonanceEngine(bus, tree)

        // M1 数据源
        this.dataSource = DataSource(bus, config.redisAddr, UInt16(config.redisPort),
                                     config.symbols, config.streamPrefix, config.consumerGroup)

        // M8 API 服务
        this.apiGateway = ApiGateway(config.httpAddr, config.httpPort)

        // ── 事件订阅 ──
        setupEventSubscriptions()

        // ── 启动 L1 协程（所有成员已初始化） ──
        spawn { l1.run() }
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

        appLog.info("System initialized. Press Ctrl+C to stop.")
        appLog.info("Monitoring: ${config.symbols}")

        // 主循环 — 保持进程存活
        while (true) {
            sleep(Duration.second * 60)
        }
    }

    /// 停止系统
    public func shutdown(): Unit {
        appLog.info("Shutting down...")
        dataSource.stop()
        apiGateway.stop()
        l1.stop()
        resonanceEngine.stop()
        appLog.info("System stopped.")
    }

    // ── 事件订阅 ──

    private func setupEventSubscriptions(): Unit {
        // K 线到达 → 投递到 L1 输入队列（非阻塞）
        bus.subscribe(EventType.KlineReceived, { e =>
            let klineOpt = e.data as Kline
            match (klineOpt) {
                case Some(kline) =>
                    l1.enqueue(kline)
                    appLog.info("Enqueued ${kline.symbol} kline: open=${kline.open} high=${kline.high} low=${kline.low} close=${kline.close}")
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
                    appLog.info("${typeStr} idx=${f.index} t=${f.kline.time} H:${f.kline.high} L:${f.kline.low}")
                case None => ()
            }
        })

        // 信号创建 → 打印 + 存储
        bus.subscribe(EventType.SignalCreated, { e =>
            let signalOpt = e.data as Signal
            match (signalOpt) {
                case Some(signal) =>
                    appLog.info("${signal.description} @ ${signal.price} strength=${signal.strength}")
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
                    appLog.info("Signal ${r.signalId} boosted ${r.confidenceBoost}")
                case None => ()
            }
        })

        // 结构变更 → 触发快照
        bus.subscribe(EventType.StructureCommitted, { e =>
            appLog.info("Structure version updated")
            let snapshot = Snapshot("", "", ArrayList<Signal>(), None)
            snapshotManager.save("all", snapshot)
        })

        // 级别漂移 → 打印
        bus.subscribe(EventType.LevelRecast, { e =>
            let msgOpt = e.data as String
            match (msgOpt) {
                case Some(msg) => appLog.info("Recast: ${msg}")
                case None => ()
            }
        })

        // 错误 → 打印
        bus.subscribe(EventType.ErrorEvent, { e =>
            let msgOpt = e.data as String
            match (msgOpt) {
                case Some(msg) => appLog.error("${msg}")
                case None => ()
            }
        })
    }
}
