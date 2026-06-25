package trade

import std.sync.*
import trade.types.*
import trade.bus.*
import trade.conf.*
import trade.core.*
import trade.levelz.*
import trade.store.*
import trade.io.*
import trade.log.*
import redis.client.*

let appLog = logger("应用")

// ──────────────────────────────────────────────
// App 主控器
//
// 生命周期管理 + 事件编排
// K线 → DataSource → L1 输入队列 → Pipeline → Redis
// 级别升级由 LevelRunner 链自动完成
// ──────────────────────────────────────────────

public class App {
    private let config: Config
    private let bus: GenericBus

    // M4 级别运行器 L1（L2+ 按需创建）
    private let l1: LevelRunner

    // M1 数据源
    private let dataSource: DataSource

    // 结果持久化
    private let resultStore: ResultStore

    public init(config: Config) {
        this.config = config

        // 事件总线
        this.bus = GenericBus()

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

        // L1 级别运行器
        let primarySymbol = if (config.symbols.size > 0) {
            config.symbols[0]
        } else {
            "BTCUSDT"
        }
        this.l1 = LevelRunner(1, primarySymbol, resultStore)

        // M1 数据源
        this.dataSource = DataSource(bus, config.redisAddr, UInt16(config.redisPort),
                                     config.symbols, config.streamPrefix, config.consumerGroup)

        // ── 事件订阅 ──
        setupEventSubscriptions()

        // ── 启动 L1 协程 ──
        spawn { l1.run() }
    }

    /// 启动系统
    public func run(): Unit {
        println("缠论实时分析系统 · Chan Theory Live Analyzer")
        println()

        dataSource.start()

        appLog.info("System initialized. Press Ctrl+C to stop.")
        appLog.info("Monitoring: ${config.symbols}")

        while (true) {
            sleep(Duration.second * 60)
        }
    }

    /// 停止系统
    public func shutdown(): Unit {
        appLog.info("Shutting down...")
        dataSource.stop()
        l1.stop()
        appLog.info("System stopped.")
    }

    // ── 事件订阅 ──

    private func setupEventSubscriptions(): Unit {
        bus.subscribe(EventType.KlineReceived, { e =>
            let klineOpt = e.data as Kline
            match (klineOpt) {
                case Some(kline) =>
                    l1.enqueue(kline)
                case None => ()
            }
        })

        bus.subscribe(EventType.ErrorEvent, { e =>
            let msgOpt = e.data as String
            match (msgOpt) {
                case Some(msg) => appLog.error("${msg}")
                case None => ()
            }
        })
    }
}
