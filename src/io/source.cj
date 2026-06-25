package trade.io

import std.collection.*
import std.sync.*
import std.convert.*
import redis.client.*
import trade.types.*
import trade.bus.*
import trade.log.*

let srcLog = logger("Source")

// ──────────────────────────────────────────────
// M1 数据源 — Redis Stream 消费
//
// 从 Redis Stream 读取 K 线数据。
// Stream 每条 entry 包含字段:
//   symbol, openTime, closeTime, open, high, low, close, volume, isClosed
//
// Stream key 格式: {prefix}:{symbol}  (如 trade:kline:btcusdt)
// ──────────────────────────────────────────────

public class DataSource {
    private let bus: GenericBus
    private let host: String
    private let port: UInt16
    private let symbols: ArrayList<String>
    private let streamPrefix: String
    private let consumerGroup: String
    private var running: Bool
    private var thread: ?Future<Unit>

    public init(bus: GenericBus, host: String, port: UInt16,
                symbols: ArrayList<String>, streamPrefix: String, consumerGroup: String) {
        this.bus = bus
        this.host = host
        this.port = port
        this.symbols = symbols
        this.streamPrefix = streamPrefix
        this.consumerGroup = consumerGroup
        this.running = false
        this.thread = None
    }

    public func start(): Unit {
        if (running) { return }
        running = true
        srcLog.info("Data source starting for ${symbols}...")

        let h = host
        let p = port
        let prefix = streamPrefix
        let group = consumerGroup
        let syms = ArrayList<String>()
        for (s in symbols) { syms.add(s) }
        let busRef = bus
        let selfRef = this

        this.thread = Some(spawn { =>
            selfRef.consumeLoop(h, p, prefix, group, syms, busRef)
        })
    }

    public func stop(): Unit {
        running = false
        match (thread) {
            case Some(f) => sleep(Duration.second * 2)
            case None => ()
        }
        srcLog.info("Data source stopped")
    }

    // ── 内部 ──

    private func consumeLoop(host: String, port: UInt16,
                              prefix: String, group: String,
                              syms: ArrayList<String>, busRef: GenericBus): Unit {
        // 连接 Redis
        var client: RedisClient
        try {
            client = RedisClient(host, port, autoHello: false)
        } catch (e: Exception) {
            srcLog.warn("Redis connect failed: ${e}, retry in 5s...")
            sleep(Duration.second * 5)
            consumeLoop(host, port, prefix, group, syms, busRef)
            return
        }
        srcLog.info("Connected to Redis ${host}:${port}")

        // 为每个 symbol 创建 Consumer Group
        for (sym in syms) {
            let streamKey = "${prefix}:${sym}"
            try {
                client.xgroupCreate(streamKey, group, id: "0", mkstream: true)
                srcLog.info("Created group '${group}' on ${streamKey}")
            } catch (_) {
                srcLog.info("Using existing group '${group}' on ${streamKey}")
            }
        }

        // ── 主循环（只等新消息 ">"）──
        while (running) {
            try {
                // 构建 streams 参数: [(key, id), ...]
                let streamArgs = Array<(String, String)>(syms.size, { i =>
                    ("${prefix}:${syms[i]}", ">")
                })

                let results = client.xreadgroup(group, "chan-cj-1", streamArgs,
                    count: Some(10), block: Some(2000))

                for (streamResult in results) {
                    let streamKey = streamResult[0]
                    let entries = streamResult[1]
                    for (entry in entries) {
                        let entryId = entry[0]
                        let fields = entry[1]
                        processFields(fields, streamKey, entryId, client, group, busRef)
                    }
                }
            } catch (e: RedisError) {
                // XREADGROUP 返回空（nil array）时 redis-cj 会抛 ProtocolError
                // 这不是真正的错误，只是没有新数据
                if (running) { sleep(Duration.millisecond * 100) }
            } catch (e: Exception) {
                if (running) {
                    srcLog.warn("Read error: ${e}")
                    sleep(Duration.second * 1)
                }
            }
        }

        try { client.close() } catch (_) { }
        srcLog.info("Consumer loop ended")
    }

    private func processFields(fields: Array<(String, Blob)>, streamKey: String,
                                entryId: String, client: RedisClient, group: String,
                                busRef: GenericBus): Unit {
        var symbol = ""
        var openTime: Int64 = 0
        var closeTime: Int64 = 0
        var open = 0.0
        var high = 0.0
        var low = 0.0
        var close = 0.0
        var volume = 0.0
        var isClosed = false

        for (i in 0 .. fields.size) {
            let fieldTuple = fields[i]
            let fieldName = fieldTuple[0]
            let blobValue = fieldTuple[1]
            var val = ""
            try {
                val = blobValue.toUtf8()
            } catch (_) {
                val = ""
            }
            if (val == "") { continue }
            match (fieldName) {
                case "symbol" => symbol = val
                case "openTime" => openTime = Int64.parse(val)
                case "closeTime" => closeTime = Int64.parse(val)
                case "open" => open = Float64.parse(val)
                case "high" => high = Float64.parse(val)
                case "low" => low = Float64.parse(val)
                case "close" => close = Float64.parse(val)
                case "volume" => volume = Float64.parse(val)
                case "isClosed" => isClosed = (val == "true")
                case _ => ()
            }
        }

        if (symbol != "" && openTime > 0 && high > 0.0) {
            let kline = Kline(openTime, closeTime, symbol, "1m",
                              open, high, low, close, volume, isClosed)
            busRef.publish(Event(EventType.KlineReceived, kline))
            if (kline.isClosed) {
                busRef.publish(Event(EventType.KlineClosed, kline))
            }
            // XACK
            try {
                client.xack(streamKey, group, [entryId])
            } catch (_) { }
            srcLog.info("Processed ${symbol} kline: O=${open} H=${high} L=${low} C=${close}")
        } else {
            srcLog.warn("Invalid kline data for ${streamKey}")
        }
    }
}
