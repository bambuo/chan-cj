package trade.core

import std.collection.*
import trade.types.*

// ──────────────────────────────────────────────
// 笔识别（流式）
// process() 返回新形成的确认笔
// ──────────────────────────────────────────────

public class StrokeProcessor {
    private var strictMode: Bool
    private let strokes: ArrayList<AlgoStroke>
    private var lastEndpoint: ?ChanKline
    private var lastEndpointType: ?FractalType
    private let candidates: ArrayList<(ChanKline, Int64, FractalType)>
    private let replacedEndpoints: ArrayList<(ChanKline, Int64, FractalType)>
    // 待输出的新笔（每次 process() 后清空）
    private let pendingOutput: ArrayList<AlgoStroke>
    // 上次已返回给调用者的笔数
    private var returnedCount: Int64

    public init(strictMode: Bool) {
        this.strictMode = strictMode
        this.strokes = ArrayList<AlgoStroke>()
        this.lastEndpoint = None
        this.lastEndpointType = None
        this.candidates = ArrayList<(ChanKline, Int64, FractalType)>()
        this.replacedEndpoints = ArrayList<(ChanKline, Int64, FractalType)>()
        this.pendingOutput = ArrayList<AlgoStroke>()
        this.returnedCount = 0
    }

    /// 处理分型，返回新形成的确认笔
    public func process(fractal: Fractal, latestKline: ChanKline, withVirtual: Bool): ArrayList<AlgoStroke> {
        pendingOutput.clear()
        cleanupVirtual()
        processFractal(fractal)
        if (withVirtual) { updateVirtual(latestKline) }

        // 收集自上次返回后的新笔
        let result = ArrayList<AlgoStroke>()
        for (i in returnedCount .. strokes.size) {
            if (!strokes[i].isVirtual) {
                result.add(strokes[i])
            }
        }
        returnedCount = strokes.size
        result
    }

    public func getLastStroke(): ?AlgoStroke {
        if (strokes.size > 0) { Some(strokes[strokes.size - 1]) } else { None }
    }

    public func reset(): Unit {
        strokes.clear()
        lastEndpoint = None
        lastEndpointType = None
        candidates.clear()
        replacedEndpoints.clear()
        pendingOutput.clear()
        returnedCount = 0
    }

    // ── §3.2 确认笔更新 ──

    private func processFractal(fractal: Fractal): Unit {
        match (fractal.ftype) {
            case FractalType.Top | FractalType.Bottom => ()
            case _ => return
        }
        if (strokes.size == 0) { tryFirstStroke(fractal); return }
        match (lastEndpointType) {
            case Some(lastType) =>
                if (fractal.ftype == lastType) { tryUpdateEndpoint(fractal) }
                else { tryCreateStroke(fractal) }
            case None => tryFirstStroke(fractal)
        }
    }

    private func tryFirstStroke(fractal: Fractal): Unit {
        for (c in candidates) {
            let (ck, idx, ftype) = c
            if (ftype != fractal.ftype && canFormStroke(ck, fractal.kline, idx, fractal.index)) {
                createStroke(ck, fractal.kline, idx, fractal.index, ftype, false)
                lastEndpoint = Some(fractal.kline)
                lastEndpointType = Some(fractal.ftype)
                candidates.clear()
                return
            }
        }
        candidates.add((fractal.kline, fractal.index, fractal.ftype))
    }

    private func tryCreateStroke(fractal: Fractal): Unit {
        if (strokes.size == 0) { tryFirstStroke(fractal); return }
        let last = strokes[strokes.size - 1]
        // 用上一笔的终点索引算跨度（不是 lastEndpoint），确保 ≥4
        if (canFormStroke(last.end, fractal.kline, last.endIndex, fractal.index)) {
            match (lastEndpointType) {
                case Some(epType) =>
                    createStroke(last.end, fractal.kline, last.endIndex, fractal.index, epType, false)
                    lastEndpoint = Some(fractal.kline)
                    lastEndpointType = Some(fractal.ftype)
                case None => tryFirstStroke(fractal)
            }
        }
    }

    private func canFormStroke(start: ChanKline, end: ChanKline, startIdx: Int64, endIdx: Int64): Bool {
        let span = if (startIdx < endIdx) { endIdx - startIdx } else { startIdx - endIdx }
        if (strictMode && span < 4) { return false }
        if (!strictMode && span < 3) { return false }
        if (startIdx < endIdx) { end.high > start.low || end.low < start.high }
        else { start.high > end.low || start.low < end.high }
    }

    private func tryUpdateEndpoint(fractal: Fractal): Unit {
        if (strokes.size == 0) { return }
        let last = strokes[strokes.size - 1]
        let ok = match (last.direction) {
            case ChanDirection.Up => fractal.ftype == FractalType.Top && fractal.kline.high >= last.end.high
            case ChanDirection.Down => fractal.ftype == FractalType.Bottom && fractal.kline.low <= last.end.low
        }
        if (!ok) { return }
        let endPrice = match (last.direction) {
            case ChanDirection.Up => fractal.kline.high
            case ChanDirection.Down => fractal.kline.low
        }
        strokes.remove(at: strokes.size - 1)
        strokes.add(AlgoStroke(last.start, fractal.kline, last.startIndex, fractal.index,
            last.direction, last.isVirtual, last.startPrice, endPrice,
            if (last.high > fractal.kline.high) { last.high } else { fractal.kline.high },
            if (last.low  < fractal.kline.low)  { last.low  } else { fractal.kline.low }))
        lastEndpoint = Some(fractal.kline)
    }

    private func createStroke(start: ChanKline, end: ChanKline, startIdx: Int64, endIdx: Int64,
                               startType: FractalType, isVirtual: Bool): Unit {
        let dir = match (startType) { case FractalType.Bottom => ChanDirection.Up case FractalType.Top => ChanDirection.Down }
        let (sp, ep) = match (dir) { case ChanDirection.Up => (start.low, end.high) case ChanDirection.Down => (start.high, end.low) }
        strokes.add(AlgoStroke(start, end, startIdx, endIdx, dir, isVirtual, sp, ep,
            if (start.high > end.high) { start.high } else { end.high },
            if (start.low  < end.low)  { start.low  } else { end.low }))
    }

    // ── 虚笔 ──

    private func cleanupVirtual(): Unit {
        if (strokes.size == 0) { return }
        let last = strokes[strokes.size - 1]
        if (!last.isVirtual) { return }
        if (replacedEndpoints.size > 0) {
            let (ep, ei, et) = replacedEndpoints[replacedEndpoints.size - 1]
            replacedEndpoints.remove(at: replacedEndpoints.size - 1)
            strokes.remove(at: strokes.size - 1)
            lastEndpoint = Some(ep)
            lastEndpointType = Some(et)
            while (replacedEndpoints.size > 0) {
                let (re, ri, rt) = replacedEndpoints[replacedEndpoints.size - 1]
                replacedEndpoints.remove(at: replacedEndpoints.size - 1)
                match (lastEndpointType) {
                    case Some(lt) =>
                        if (lt != rt) {
                            match (lastEndpoint) {
                                case Some(le) =>
                                    if (canFormStroke(le, re, 0, ri)) {
                                        createStroke(le, re, 0, ri, lt, false)
                                        lastEndpoint = Some(re)
                                        lastEndpointType = Some(rt)
                                    }
                                case None => ()
                            }
                        }
                    case None => ()
                }
            }
        } else {
            strokes.remove(at: strokes.size - 1)
        }
    }

    private func updateVirtual(latestKline: ChanKline): Unit {
        if (strokes.size == 0) { return }
        let last = strokes[strokes.size - 1]
        let ext = match (last.direction) {
            case ChanDirection.Up => latestKline.high > last.end.high
            case ChanDirection.Down => latestKline.low < last.end.low
        }
        if (ext) {
            let ep = match (last.direction) { case ChanDirection.Up => latestKline.high case ChanDirection.Down => latestKline.low }
            strokes.remove(at: strokes.size - 1)
            strokes.add(AlgoStroke(last.start, latestKline, last.startIndex, last.endIndex + 1,
                last.direction, true, last.startPrice, ep,
                if (last.high > latestKline.high) { last.high } else { latestKline.high },
                if (last.low  < latestKline.low)  { last.low  } else { latestKline.low }))
            return
        }
        match (lastEndpoint) {
            case Some(ep) =>
                match (lastEndpointType) {
                    case Some(et) =>
                        if (canFormStroke(ep, latestKline, 0, last.endIndex + 1)) {
                            replacedEndpoints.add((last.end, last.endIndex, et))
                            createStroke(ep, latestKline, 0, last.endIndex + 1, et, true)
                        }
                    case None => ()
                }
            case None => ()
        }
    }
}
