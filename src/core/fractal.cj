package trade.core

import std.collection.*
import trade.types.*

// ──────────────────────────────────────────────
// 分型识别（流式）
// ──────────────────────────────────────────────

public class FractalProcessor {
    private let seen: HashSet<String>

    public init() { this.seen = HashSet<String>() }

    /// 扫描最后三个元素，返回新发现的分型（使用偏移修正绝对索引）
    public func scan(elements: ArrayList<ChanKline>, baseOffset: Int64): ArrayList<Fractal> {
        let result = ArrayList<Fractal>()
        if (elements.size < 3) { return result }
        let count = elements.size
        let b = elements[count - 2]
        let midIdx = (count - 2) + baseOffset  // 绝对索引

        if (b > elements[count - 3] && b > elements[count - 1]) {
            let key = "TOP:${midIdx}"
            if (!seen.contains(key)) { seen.add(key); result.add(Fractal(FractalType.Top, b, midIdx)) }
        }
        if (b < elements[count - 3] && b < elements[count - 1]) {
            let key = "BOTTOM:${midIdx}"
            if (!seen.contains(key)) { seen.add(key); result.add(Fractal(FractalType.Bottom, b, midIdx)) }
        }
        result
    }

    public func reset(): Unit { seen.clear() }
}
