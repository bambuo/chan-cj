package trade

import std.collection.*

// ──────────────────────────────────────────────
// KlineMerger — 缠论 K 线包含处理
// ──────────────────────────────────────────────

public class KlineMerger {
    private let merged: ArrayList<ChanKline>
    private let eventBus: EventBus

    public init(eventBus: EventBus) {
        this.merged = ArrayList<ChanKline>()
        this.eventBus = eventBus
        this.eventBus.subscribe(EventType.KlineClosed, { e => this.onKlineClosed(e) })
    }

    public func getMergedKlines(): ArrayList<ChanKline> {
        let copy = ArrayList<ChanKline>()
        for (ck in merged) { copy.add(ck) }
        return copy
    }

    private func onKlineClosed(event: Event): Unit {
        let klineOpt = event.data as Kline
        match (klineOpt) {
            case Some(kline) =>
                if (kline.isClosed) {
                    processKline(kline)
                }
            case None =>
                eventBus.publish(Event(EventType.ErrorEvent,
                    "KlineMerger: failed to cast event data to Kline"))
        }
    }

    private func processKline(kline: Kline): Unit {
        let ck = ChanKline(kline.openTime, kline.high, kline.low)

        merged.add(ck)

        var done = false
        while (!done && merged.size >= 2) {
            let lastIdx = merged.size - 1
            let a = merged[lastIdx - 1]
            let b = merged[lastIdx]

            if (!isContained(a, b)) {
                done = true
            } else {
                let trend = determineTrend(lastIdx - 1)
                merged.remove(at: lastIdx)
                merged.remove(at: lastIdx - 1)
                let mergedCk = mergePair(a, b, trend)
                merged.add(mergedCk)
            }
        }

        eventBus.publish(Event(EventType.MergeProcessed, true))
    }

    private func isContained(a: ChanKline, b: ChanKline): Bool {
        return (a.high >= b.high && a.low <= b.low) ||
               (b.high >= a.high && b.low <= a.low)
    }

    private func determineTrend(idx: Int64): ChanTrend {
        if (idx > 0) {
            let prev = merged[idx - 1]
            let curr = merged[idx]
            if (curr.high > prev.high && curr.low > prev.low) {
                return ChanTrend.Up
            }
            if (curr.high < prev.high && curr.low < prev.low) {
                return ChanTrend.Down
            }
        }
        return ChanTrend.Up
    }

    private func mergePair(a: ChanKline, b: ChanKline, trend: ChanTrend): ChanKline {
        match (trend) {
            case ChanTrend.Up =>
                let upHigh = if (a.high > b.high) { a.high } else { b.high }
                let upLow  = if (a.low  > b.low)  { a.low  } else { b.low }
                ChanKline(a.time, upHigh, upLow)
            case ChanTrend.Down =>
                let dnHigh = if (a.high < b.high) { a.high } else { b.high }
                let dnLow  = if (a.low  < b.low)  { a.low  } else { b.low }
                ChanKline(a.time, dnHigh, dnLow)
        }
    }
}
