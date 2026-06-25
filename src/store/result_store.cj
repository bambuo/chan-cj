package trade.store

import std.collection.*
import redis.client.*
import trade.types.*
import trade.log.*

let rsLog = logger("ResultStore")

// ──────────────────────────────────────────────
// 管线结果持久化到 Redis
// 接收已序列化的字符串键值对
// ──────────────────────────────────────────────

/// 待写入的 Redis 条目
public struct RedisEntry {
    public let score: Float64
    public let value: String

    public init(score: Float64, value: String) {
        this.score = score
        this.value = value
    }
}

public class ResultStore {
    private var client: ?RedisClient

    public init(client: RedisClient) {
        this.client = Some(client)
    }

    public static func newDisabled(): ResultStore {
        ResultStore()
    }

    private init() {
        this.client = None
    }

    /// 写入单条结果到 Redis ZSET
    public func saveOne(symbol: String, depth: Int64, entry: RedisEntry): Unit {
        match (client) {
            case Some(c) =>
                let key = "trade:${symbol.toAsciiUpper()}:L${depth}:output"
                try {
                    c.zadd(key, [(entry.score, Blob.of(entry.value))])
                } catch (e: Exception) {
                    rsLog.warn("saveOne failed: ${e}")
                }
            case None => ()
        }
    }

    /// 批量写入各类实体到 Redis ZSET（兼容旧调用）
    public func saveAll(symbol: String, level: Level,
                        entries: HashMap<String, ArrayList<RedisEntry>>): Unit {
        match (client) {
            case Some(c) =>
                let prefix = keyPrefix(symbol, level)
                let keys = entries.keys()
                for (entityType in keys) {
                    let itemsOpt = entries.get(entityType)
                    match (itemsOpt) {
                        case Some(items) =>
                            if (items.size == 0) { continue }
                            let key = "${prefix}:${entityType}"
                            for (item in items) {
                                try { c.zadd(key, [(item.score, Blob.of(item.value))]) } catch (_) { }
                            }
                        case None => ()
                    }
                }
                var summary = ArrayList<String>()
                for (entityType in keys) {
                    let itemsOpt = entries.get(entityType)
                    match (itemsOpt) {
                        case Some(items) =>
                            if (items.size > 0) { summary.add("${items.size}${entityType}") }
                        case None => ()
                    }
                }
                if (summary.size > 0) {
                    var detail = summary[0]
                    for (i in 1 .. summary.size) {
                        detail = detail + " + " + summary[i]
                    }
                    rsLog.info("${symbol}: saved ${detail}")
                }
            case None => ()
        }
    }

    private func keyPrefix(symbol: String, level: Level): String {
        "trade:${symbol.toAsciiUpper()}:${level.label()}"
    }
}
