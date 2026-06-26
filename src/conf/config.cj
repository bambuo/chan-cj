package trade.conf

import std.collection.*

// ──────────────────────────────────────────────
// 系统配置
// ──────────────────────────────────────────────

/// 系统运行时配置
public struct Config {
    // Redis 连接
    public var redisAddr: String = "127.0.0.1"
    public var redisPort: Int64 = 6379
    public var redisPassword: String = ""
    public var redisDB: Int64 = 0

    // Redis Stream 配置
    public var streamPrefix: String = "trade:kline"
    public var consumerGroup: String = "chan-cj-group"

    // 监控的交易对
    public var symbols: ArrayList<String> = ArrayList<String>()

    // HTTP API
    public var httpAddr: String = "0.0.0.0"
    public var httpPort: Int64 = 8080

    // 快照
    public var snapshotDir: String = "./data/snapshots"
    public var snapshotRetain: Int64 = 10
    public var snapshotPeriod: Int64 = 300  // 秒

    // 日志
    public var logLevel: String = "info"
    public var logJSON: Bool = false

    /// 创建 Config 构建器（链式调用入口）
    public static func builder(): ConfigBuilder { ConfigBuilder() }

    /// 默认开发配置（含 BTCUSDT / ETHUSDT）
    public static func defaultConfig(): Config {
        Config.builder()
            .addSymbol("BTCUSDT")
            .addSymbol("ETHUSDT")
            .build()
    }
}

/// Config 构建器
public class ConfigBuilder {
    private var _cfg = Config()

    public init() {}

    public func redisAddr(v: String): ConfigBuilder { _cfg.redisAddr = v; this }
    public func redisPort(v: Int64): ConfigBuilder { _cfg.redisPort = v; this }
    public func redisPassword(v: String): ConfigBuilder { _cfg.redisPassword = v; this }
    public func redisDB(v: Int64): ConfigBuilder { _cfg.redisDB = v; this }
    public func streamPrefix(v: String): ConfigBuilder { _cfg.streamPrefix = v; this }
    public func consumerGroup(v: String): ConfigBuilder { _cfg.consumerGroup = v; this }
    public func symbols(v: ArrayList<String>): ConfigBuilder { _cfg.symbols = v; this }
    public func httpAddr(v: String): ConfigBuilder { _cfg.httpAddr = v; this }
    public func httpPort(v: Int64): ConfigBuilder { _cfg.httpPort = v; this }
    public func snapshotDir(v: String): ConfigBuilder { _cfg.snapshotDir = v; this }
    public func snapshotRetain(v: Int64): ConfigBuilder { _cfg.snapshotRetain = v; this }
    public func snapshotPeriod(v: Int64): ConfigBuilder { _cfg.snapshotPeriod = v; this }
    public func logLevel(v: String): ConfigBuilder { _cfg.logLevel = v; this }
    public func logJSON(v: Bool): ConfigBuilder { _cfg.logJSON = v; this }

    /// 添加监控交易对
    public func addSymbol(s: String): ConfigBuilder { _cfg.symbols.add(s); this }

    /// 构建 Config 实例
    public func build(): Config { _cfg }
}
