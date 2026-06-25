package trade.conf

import std.collection.*

// ──────────────────────────────────────────────
// 系统配置
// ──────────────────────────────────────────────

/// 系统运行时配置
public struct Config {
    // Redis 连接
    public let redisAddr: String
    public let redisPort: Int64
    public let redisPassword: String
    public let redisDB: Int64

    // Redis Stream 配置
    public let streamPrefix: String
    public let consumerGroup: String

    // 监控的交易对
    public let symbols: ArrayList<String>

    // HTTP API
    public let httpAddr: String
    public let httpPort: Int64

    // 快照
    public let snapshotDir: String
    public let snapshotRetain: Int64
    public let snapshotPeriod: Int64  // 秒

    // 日志
    public let logLevel: String
    public let logJSON: Bool

    public init(redisAddr: String, redisPort: Int64, redisPassword: String, redisDB: Int64,
                streamPrefix: String, consumerGroup: String,
                symbols: ArrayList<String>,
                httpAddr: String, httpPort: Int64,
                snapshotDir: String, snapshotRetain: Int64, snapshotPeriod: Int64,
                logLevel: String, logJSON: Bool) {
        this.redisAddr = redisAddr
        this.redisPort = redisPort
        this.redisPassword = redisPassword
        this.redisDB = redisDB
        this.streamPrefix = streamPrefix
        this.consumerGroup = consumerGroup
        this.symbols = symbols
        this.httpAddr = httpAddr
        this.httpPort = httpPort
        this.snapshotDir = snapshotDir
        this.snapshotRetain = snapshotRetain
        this.snapshotPeriod = snapshotPeriod
        this.logLevel = logLevel
        this.logJSON = logJSON
    }
}

/// 默认开发配置
public func defaultConfig(): Config {
    let syms = ArrayList<String>()
    syms.add("BTCUSDT")
    syms.add("ETHUSDT")

    Config(
        "127.0.0.1", 6379, "", 0,
        "trade:kline", "chan-cj-group",
        syms,
        "0.0.0.0", 8080,
        "./data/snapshots", 10, 300,
        "info", false
    )
}
