package trade.core

import std.collection.*
import trade.types.*

// ──────────────────────────────────────────────
// 分型识别（M2 管线第二级）
//
// 使用运算符重载后的 ChanKline：
//   顶分型判定 → b > a && b > c  (b 比 a 和 c 都更高)
//   底分型判定 → b < a && b < c  (b 比 a 和 c 都更低)
// ──────────────────────────────────────────────

public class FractalProcessor {
    private let fractals: ArrayList<Fractal>
    private let seen: HashSet<String>

    public init() {
        this.fractals = ArrayList<Fractal>()
        this.seen = HashSet<String>()
    }

    /// 增量输入一根合并 K 线，扫描新分型
    public func process(elements: ArrayList<ChanKline>): Unit {
        if (elements.size < 3) { return }

        // 只检查最后三根
        let count = elements.size
        let b = elements[count - 2]
        let midIdx = count - 2

        // 顶分型：中间元素比两侧都更高
        if (b > elements[count - 3] && b > elements[count - 1]) {
            let key = "TOP:${b.time}"
            if (!seen.contains(key)) {
                seen.add(key)
                fractals.add(Fractal(FractalType.Top, b, midIdx))
            }
        }

        // 底分型：中间元素比两侧都更低
        if (b < elements[count - 3] && b < elements[count - 1]) {
            let key = "BOTTOM:${b.time}"
            if (!seen.contains(key)) {
                seen.add(key)
                fractals.add(Fractal(FractalType.Bottom, b, midIdx))
            }
        }
    }

    /// 获取所有已确认分型
    public func getFractals(): ArrayList<Fractal> {
        let copy = ArrayList<Fractal>()
        for (f in fractals) { copy.add(f) }
        copy
    }

    /// 重置
    public func reset(): Unit {
        fractals.clear()
        seen.clear()
    }
}
