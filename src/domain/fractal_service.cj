package trade.domain

import std.collection.*

// ──────────────────────────────────────────────
// Domain Service — 缠论分型识别
//
// 在包含处理后的合并 K 线序列中扫描分型：
//   顶分型：中间 K 线最高点最高且最低点最高
//   底分型：中间 K 线最低点最低且最高点最低
// ──────────────────────────────────────────────

public class FractalService {
    private let seen: HashSet<String>

    public init() {
        this.seen = HashSet<String>()
    }

    /// 扫描合并序列，返回新发现的分型列表
    public func scan(merged: ArrayList<ChanKline>): ArrayList<Fractal> {
        let result = ArrayList<Fractal>()
        let count = merged.size
        if (count < 3) { return result }

        for (i in 0 .. (count - 2)) {
            let a = merged[i]
            let b = merged[i + 1]
            let c = merged[i + 2]
            let midIdx = i + 1

            // 顶分型
            if (b.high > a.high && b.high > c.high &&
                b.low  > a.low  && b.low  > c.low) {
                let key = "TOP:${b.time}"
                if (!seen.contains(key)) {
                    seen.add(key)
                    result.add(Fractal(FractalType.Top, b, midIdx))
                }
            }

            // 底分型
            if (b.low  < a.low  && b.low  < c.low &&
                b.high < a.high && b.high < c.high) {
                let key = "BOTTOM:${b.time}"
                if (!seen.contains(key)) {
                    seen.add(key)
                    result.add(Fractal(FractalType.Bottom, b, midIdx))
                }
            }
        }

        return result
    }
}
