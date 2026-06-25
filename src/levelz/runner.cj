package trade.levelz

import std.collection.concurrent.*
import trade.types.*
import trade.core.*
import trade.store.*
import trade.log.*

let log = logger("LvRunner")

// ──────────────────────────────────────────────
// M4 级别运行器
//
// 每个级别一个独立协程，通过 ArrayBlockingQueue 连接。
// L1 由 App 注入原始 K 线，
// L2+ 由 L(N-1) 完成趋势时按需创建并注入趋势 K 线。
//
// 每个级别内部：
//   输入队列 → Pipeline 流式处理 → OutputPipe → Redis
// ──────────────────────────────────────────────

/// 级别运行器
public class LevelRunner {
    private let depth: Int64
    private let symbol: String
    private let resultStore: ResultStore
    private let pipeline: Pipeline
    private let outputPipe: OutputPipe
    private let inputQueue: ArrayBlockingQueue<Kline>
    private var nextLevel: ?LevelRunner
    private var running: Bool

    public init(depth: Int64, symbol: String, resultStore: ResultStore) {
        this.depth = depth
        this.symbol = symbol
        this.resultStore = resultStore
        this.pipeline = Pipeline()
        this.outputPipe = OutputPipe(symbol, depth, resultStore)
        this.inputQueue = ArrayBlockingQueue<Kline>(128)
        this.nextLevel = None
        this.running = false
    }

    /// 获取当前深度
    public func getDepth(): Int64 { depth }

    /// 获取下一级运行器
    public func getNextLevel(): ?LevelRunner { nextLevel }

    /// 投递 K 线到输入队列（线程安全）
    public func enqueue(kline: Kline): Unit {
        inputQueue.add(kline)
    }

    /// 主循环——在独立协程中运行
    /// 从输入队列阻塞取值，处理后推入 OutputPipe，
    /// 检查完成趋势并向上一级投递趋势 K 线。
    public func run(): Unit {
        running = true
        log.info("Level L${depth} started for ${symbol}")

        while (running) {
            var kline: Kline
            try {
                kline = inputQueue.remove()     // 阻塞直到有数据
            } catch (e: Exception) {
                if (running) {
                    log.warn("L${depth} input error: ${e}")
                    sleep(Duration.millisecond * 100)
                }
                continue
            }

            // 流式处理（内部已推入 OutputPipe）
            let result = pipeline.process(kline, outputPipe)

            // 检查完成趋势 → 级别升级
            if (result.hasCompletedTrend) {
                let trendKline = buildTrendKline(result)
                let next = getOrCreateNextLevel()
                next.enqueue(trendKline)
                log.info("L${depth} trend completed → L${depth + 1} created for ${result.symbol}")
            }
        }

        outputPipe.stop()
        log.info("Level L${depth} stopped for ${symbol}")
    }

    /// 停止运行器
    public func stop(): Unit {
        running = false
        match (nextLevel) {
            case Some(nl) => nl.stop()
            case None => ()
        }
    }

    // ── 内部 ──

    /// 按需创建下一级运行器
    private func getOrCreateNextLevel(): LevelRunner {
        match (nextLevel) {
            case Some(r) => r
            case None =>
                let nr = LevelRunner(depth + 1, symbol, resultStore)
                spawn { nr.run() }
                this.nextLevel = Some(nr)
                nr
        }
    }

    /// 从完成走势构造趋势 K 线
    private func buildTrendKline(result: ProcessResult): Kline {
        Kline(
            0, 0,
            result.symbol, "trend",
            result.trendHigh, 0.0,
            result.trendLow, 0.0,
            0.0, true
        )
    }
}
