package trade.types

import std.deriving.*

// ──────────────────────────────────────────────
// 事件系统
// ──────────────────────────────────────────────

/// 事件类型
@Derive[Hashable, Equatable]
public enum EventType {
    | KlineReceived      // 原始 K 线到达
    | KlineClosed        // K 线收盘
    | ErrorEvent         // 错误
}

/// 领域事件
public struct Event {
    public let eventType: EventType
    public let data: Any

    public init(eventType: EventType, data: Any) {
        this.eventType = eventType
        this.data = data
    }
}
