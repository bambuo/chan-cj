package trade.core

import std.collection.concurrent.*
import trade.types.*
import trade.store.*

// ──────────────────────────────────────────────
// FIFO→Redis 输出管道
//
// Pipeline 每步产出即时 push（满则阻塞——自然背压），
// 后台写协程持续 drain 队列，写入 Redis。
// 每类实体独立 Redis key。
// ──────────────────────────────────────────────

/// 带类型标记的 Redis 条目
private struct EntryWithType {
    let entityType: String
    let entry: RedisEntry

    public init(entityType: String, entry: RedisEntry) {
        this.entityType = entityType
        this.entry = entry
    }
}

/// 输出管道
public class OutputPipe {
    private let queue: ArrayBlockingQueue<EntryWithType>
    private let resultStore: ResultStore
    private let symbol: String
    private let depth: Int64
    private var running: Bool

    public init(symbol: String, depth: Int64, resultStore: ResultStore) {
        // 固定容量 1024，满时 push 阻塞（背压到 Pipeline）
        this.queue = ArrayBlockingQueue<EntryWithType>(1024)
        this.symbol = symbol
        this.depth = depth
        this.resultStore = resultStore
        this.running = true
        spawn { writeLoop() }
    }

    /// Pipeline 每步调用——队列满时阻塞（产生背压）
    /// entityType: 如 "merged_kline", "fractal", "stroke" 等
    public func push(entityType: String, entry: RedisEntry): Unit {
        queue.add(EntryWithType(entityType, entry))
    }

    /// 非阻塞入队（队列满返回 false）
    public func tryPush(entityType: String, entry: RedisEntry): Bool {
        queue.tryAdd(EntryWithType(entityType, entry))
    }

    /// 停止后台写协程
    public func stop(): Unit {
        running = false
    }

    /// 后台写协程——持续 drain 队列写入 Redis
    private func writeLoop(): Unit {
        while (running) {
            match (queue.remove(Duration.millisecond * 100)) {
                case Some(wt) =>
                    resultStore.saveOne(symbol, depth, wt.entityType, wt.entry)
                case None => ()
            }
        }
    }
}
