package trade.core

import std.collection.*
import trade.types.*

// ──────────────────────────────────────────────
// 分型识别（流式）
// 使用 RingBuffer 存储最近分型用于去重，自动淘汰旧记录
// ──────────────────────────────────────────────

private struct FractalKey {
    let ftype: FractalType
    let index: Int64

    public init(ftype: FractalType, index: Int64) {
        this.ftype = ftype
        this.index = index
    }

    public func equals(other: FractalKey): Bool {
        ftype == other.ftype && index == other.index
    }
}

public class FractalProcessor {
    private let seen: RingBuffer<FractalKey>

    public init() {
        // RingBuffer 容量 = 存储最近 1000 个分型用于去重
        // 超出自动淘汰最旧，无需手动 trim
        this.seen = RingBuffer<FractalKey>(1000)
    }

    /// 扫描最后三个元素，返回新发现的分型（使用偏移修正绝对索引）
    public func scan(elements: ArrayList<ChanKline>, baseOffset: Int64): ArrayList<Fractal> {
        let result = ArrayList<Fractal>()
        if (elements.size < 3) { return result }
        let count = elements.size
        let b = elements[count - 2]
        let midIdx = (count - 2) + baseOffset  // 绝对索引

        if (b > elements[count - 3] && b > elements[count - 1]) {
            if (!hasSeen(FractalType.Top, midIdx)) {
                recordSeen(FractalType.Top, midIdx)
                result.add(Fractal(FractalType.Top, b, midIdx))
            }
        }
        if (b < elements[count - 3] && b < elements[count - 1]) {
            if (!hasSeen(FractalType.Bottom, midIdx)) {
                recordSeen(FractalType.Bottom, midIdx)
                result.add(Fractal(FractalType.Bottom, b, midIdx))
            }
        }
        result
    }

    public func reset(): Unit { seen.clear() }

    // ── 内部 ──

    private func hasSeen(ftype: FractalType, index: Int64): Bool {
        let all = seen.toArrayList()
        for (k in all) {
            if (k.ftype == ftype && k.index == index) { return true }
        }
        false
    }

    private func recordSeen(ftype: FractalType, index: Int64): Unit {
        seen.add(FractalKey(ftype, index))
    }
}
