package trade.levelz

import std.collection.*
import std.sync.*
import trade.types.*
import trade.core.*
import trade.bus.*

// ──────────────────────────────────────────────
// M4 LevelRunner
//
// 每级别独立 Pipeline 实例，channel 驱动处理循环
// L1 由 App 喂入，L2+ 由上一级完成的走势类型驱动
// ──────────────────────────────────────────────

/// 级别运行器
public class LevelRunner {
    private let level: Level
    private let pipeline: Pipeline
    private let bus: GenericBus
    private var nextLevelRunner: ?LevelRunner
    private var running: Bool

    public init(level: Level, bus: GenericBus) {
        this.level = level
        this.pipeline = Pipeline(PivotZoneMode.Stroke)
        this.bus = bus
        this.nextLevelRunner = None
        this.running = false
    }

    /// 设置下一级运行器
    public func setNextRunner(runner: LevelRunner): Unit {
        this.nextLevelRunner = Some(runner)
    }

    /// 获取当前管线
    public func getPipeline(): Pipeline { pipeline }

    /// 处理一根 K 线（由 App 调用）
    public func processKline(kline: Kline): Unit {
        let output = pipeline.process(kline)

        // 检查是否有新完成的走势类型 → 递到下一级
        if (output.trendPatterns.size > 0) {
            let lastTP = output.trendPatterns[output.trendPatterns.size - 1]
            if (lastTP.completed) {
                // 简化的级别提升
                match (nextLevelRunner) {
                    case Some(next) =>
                        // L(N) 的已完成走势类型 → L(N+1) 的合成 K 线
                        let syntheticKline = Kline(
                            output.lastOpenTime, output.lastOpenTime,
                            output.symbol, "synthetic",
                            lastTP.zones[0].zg, Float64(output.lastOpenTime),
                            lastTP.zones[0].zd, Float64(output.lastOpenTime),
                            0.0, true
                        )
                        next.processKline(syntheticKline)
                    case None => ()
                }
            }
        }
    }
}
