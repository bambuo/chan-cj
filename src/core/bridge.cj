package trade.core

import trade.types.*
import trade.bus.*

/// M2→M3 桥接器
public class M3Bridge {
    private let pipeline: Pipeline
    private let bus: GenericBus
    private var signalSink: ?SignalSink

    public init(pipeline: Pipeline, bus: GenericBus) {
        this.pipeline = pipeline
        this.bus = bus
        this.signalSink = None
    }

    /// 设置信号引擎接收器
    public func withSignalSink(sink: SignalSink): Unit {
        this.signalSink = Some(sink)
    }

    /// 处理一根 K 线：管线处理 → 发布结构化事件
    /// 注意：不再重复发布 KlineReceived/KlineClosed（已由 DataSource 发布）
    public func onKline(kline: Kline): (Bool, String) {
        // 1. 管线处理
        let output = pipeline.process(kline)

        // 2. 有分型时发布事件
        if (output.newFractals.size > 0) {
            for (f in output.newFractals) {
                bus.publish(Event(EventType.FractalDetected, f))
            }
        }

        // 3. 触发信号引擎
        match (signalSink) {
            case Some(sink) =>
                if (output.hasChange) {
                    let trendDir = if (output.trendPatterns.size > 0) {
                        match (output.trendPatterns[output.trendPatterns.size - 1].direction) {
                            case ChanDirection.Up => "Up"
                            case ChanDirection.Down => "Down"
                        }
                    } else { "Unknown" }
                    let hasDivergence = output.newDivergences.size > 0
                    let divType = if (hasDivergence) { output.newDivergences[0].divergenceType } else { "" }
                    let hasPivot = output.pivotZones.size > 0

                    let signalInput = SignalInput(
                        output.symbol, Level.L1,
                        hasDivergence, divType,
                        trendDir, hasPivot
                    )
                    sink.onSignalInput(signalInput)
                }
            case None => ()
        }

        (output.hasChange, output.symbol)
    }
}
