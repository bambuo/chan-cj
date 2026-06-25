package trade.core

import std.collection.*

// ──────────────────────────────────────────────
// 环形缓冲区（固定容量，自动淘汰最旧）
//
// 用于各处理器"本地窗口"，只保留增量所需数据。
// 当 add 超出容量时，自动覆盖最旧元素。
// ──────────────────────────────────────────────

/// 环形缓冲区
public class RingBuffer<T> {
    private let buffer: ArrayList<T>
    private let cap: Int64
    private var head: Int64    // 最旧元素的索引
    private var cnt: Int64     // 当前元素数

    public init(capacity: Int64) {
        this.cap = capacity
        this.buffer = ArrayList<T>(capacity)
        this.head = 0
        this.cnt = 0
    }

    /// 添加元素。满则覆盖最旧。
    public func add(value: T): Unit {
        if (cnt < cap) {
            buffer.add(value)
            cnt++
        } else {
            buffer[head] = value
            head = (head + 1) % cap
        }
    }

    /// 获取第 index 个元素（0 = 最旧）
    public func get(index: Int64): T {
        buffer[(head + index) % cap]
    }

    /// 获取最后一个元素
    public func last(): ?T {
        if (cnt == 0) { return None }
        Some(get(cnt - 1))
    }

    /// 获取最旧元素
    public func first(): ?T {
        if (cnt == 0) { return None }
        Some(get(0))
    }

    /// 将全部元素导出为 ArrayList
    public func toArrayList(): ArrayList<T> {
        let result = ArrayList<T>()
        for (i in 0 .. cnt) {
            result.add(get(i))
        }
        result
    }

    /// 获取最后 n 个元素
    public func lastN(n: Int64): ArrayList<T> {
        let result = ArrayList<T>()
        let startIdx = if (cnt > n) { cnt - n } else { 0 }
        for (i in startIdx .. cnt) {
            result.add(get(i))
        }
        result
    }

    /// 当前元素数
    public func size(): Int64 { cnt }

    /// 是否为空
    public func isEmpty(): Bool { cnt == 0 }

    /// 是否已满
    public func isFull(): Bool { cnt == cap }

    /// 清空
    public func clear(): Unit {
        buffer.clear()
        head = 0
        cnt = 0
    }

    /// 遍历
    public func forEach(f: (T) -> Unit): Unit {
        for (i in 0 .. cnt) {
            f(get(i))
        }
    }
}
