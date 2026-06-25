package trade.core

import std.collection.concurrent.*
import trade.types.*
import trade.store.*

// ──────────────────────────────────────────────
// FIFO→Redis 输出管道
//
// Pipeline 每步产出即时 push（非阻塞），
// 后台写协程持续 drain 队列，写入 Redis。
// ──────────────────────────────────────────────

/// 输出管道
public class OutputPipe {
    private let queue: ConcurrentLinkedQueue<RedisEntry>
    private let resultStore: ResultStore
    private let symbol: String
    private let depth: Int64
    private var running: Bool

    public init(symbol: String, depth: Int64, resultStore: ResultStore) {
        this.queue = ConcurrentLinkedQueue<RedisEntry>()
        this.symbol = symbol
        this.depth = depth
        this.resultStore = resultStore
        this.running = true
        spawn { writeLoop() }
    }

    /// Pipeline 每步调用——非阻塞入队
    public func push(entry: RedisEntry): Unit {
        queue.add(entry)
    }

    /// 停止后台写协程
    public func stop(): Unit {
        running = false
    }

    /// 后台写协程——持续 drain 队列写入 Redis
    private func writeLoop(): Unit {
        while (running) {
            match (queue.remove()) {
                case Some(entry) =>
                    resultStore.saveOne(symbol, depth, entry)
                case None =>
                    // 队列空时短暂休眠
                    sleep(Duration.millisecond * 10)
            }
        }
    }
}
