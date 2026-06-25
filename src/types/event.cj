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
    | MergeProcessed     // 包含处理完成
    | FractalDetected    // 新分型发现
    | StructureCommitted // M3 结构树新版本提交
    | LevelRecast        // 级别漂移重算
    | SignalCreated      // 信号创建
    | SignalStateChanged // 信号状态变更
    | ResonanceTriggered // 共振触发
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
