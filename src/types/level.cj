package trade.types

import std.deriving.*

// ──────────────────────────────────────────────
// 缠论级别 — 由整数深度表示，不预设上限
// 深度 1 = L1, 深度 2 = L2, ...
// 由数据驱动自然生长，非人工设定
// ──────────────────────────────────────────────

/// 缠论级别
@Derive[ToString]
public struct Level {
    public let depth: Int64

    public init(depth: Int64) {
        this.depth = depth
    }

    /// 标签，用于 Redis key 构造："L1", "L2", ...
    public func label(): String {
        "L${depth}"
    }

    /// 下一级
    public func next(): Level {
        Level(depth + 1)
    }

    /// 上一级
    public func prev(): Level {
        if (depth > 1) { Level(depth - 1) } else { this }
    }

    /// 是否是初始级别
    public func isBase(): Bool {
        depth == 1
    }
}
