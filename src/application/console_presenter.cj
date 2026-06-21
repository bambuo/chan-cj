package trade.application

import trade.domain.*

// ──────────────────────────────────────────────
// Application — ConsolePresenter 控制台展示器
// 将领域事件渲染为终端输出
// ──────────────────────────────────────────────

public class ConsolePresenter {
    public init() {}

    public func onKlineReceived(kline: Kline): Unit {
        println("[Kline] ${kline.symbol} ${kline.interval} " +
                "O:${kline.open} H:${kline.high} L:${kline.low} " +
                "C:${kline.close} V:${kline.volume}")
    }

    public func onFractalDetected(fractal: Fractal): Unit {
        let typeStr = match (fractal.ftype) {
            case FractalType.Top => "顶分型"
            case FractalType.Bottom => "底分型"
        }
        println("[Fractal] ${typeStr} idx=${fractal.index} " +
                "t=${fractal.kline.time} H:${fractal.kline.high} L:${fractal.kline.low}")
    }

    public func onError(msg: String): Unit {
        println("[Error] ${msg}")
    }
}
