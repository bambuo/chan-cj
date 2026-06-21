package trade

import std.collection.*

// ──────────────────────────────────────────────
// FractalRecognizer — 缠论分型识别
//
// After containment merging, scans the merged
// k-line sequence for Chan Theory fractals:
//
//   Top fractal (顶分型):
//     Middle k-line (B) has the highest high AND
//     the highest low among the three.
//
//   Bottom fractal (底分型):
//     Middle k-line (B) has the lowest low AND
//     the lowest high among the three.
// ──────────────────────────────────────────────

public class FractalRecognizer {
    private let merger: KlineMerger
    private let eventBus: EventBus
    private let seen: HashSet<String>

    public init(merger: KlineMerger, eventBus: EventBus) {
        this.merger = merger
        this.eventBus = eventBus
        this.seen = HashSet<String>()
        this.eventBus.subscribe(EventType.MergeProcessed, { e => this.onMergeProcessed(e) })
    }

    // ── Event handler ──

    private func onMergeProcessed(event: Event): Unit {
        let merged = merger.getMergedKlines()
        let count = merged.size
        if (count < 3) { return }

        for (i in 0 .. (count - 2)) {
            let a = merged[i]
            let b = merged[i + 1]
            let c = merged[i + 2]
            let midIdx = i + 1

            // Check top fractal (顶分型)
            if (b.high > a.high && b.high > c.high &&
                b.low  > a.low  && b.low  > c.low) {
                let key = "TOP:${b.time}"
                if (!seen.contains(key)) {
                    seen.add(key)
                    let fractal = Fractal(FractalType.Top, b, midIdx)
                    eventBus.publish(Event(EventType.FractalDetected, fractal))
                }
            }

            // Check bottom fractal (底分型)
            if (b.low  < a.low  && b.low  < c.low &&
                b.high < a.high && b.high < c.high) {
                let key = "BOTTOM:${b.time}"
                if (!seen.contains(key)) {
                    seen.add(key)
                    let fractal = Fractal(FractalType.Bottom, b, midIdx)
                    eventBus.publish(Event(EventType.FractalDetected, fractal))
                }
            }
        }
    }
}
