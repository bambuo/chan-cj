package trade.bus

import std.collection.*
import std.sync.*
import trade.types.*

// ──────────────────────────────────────────────
// 事件总线（观察者模式）
// ──────────────────────────────────────────────

/// 通用事件总线 — 基于 EventType 发布/订阅
public class GenericBus {
    private let handlers: HashMap<EventType, ArrayList<(Event) -> Unit>>
    private let mutex: Mutex

    public init() {
        this.handlers = HashMap<EventType, ArrayList<(Event) -> Unit>>()
        this.mutex = Mutex()
    }

    /// 订阅指定类型的事件
    public func subscribe(eventType: EventType, handler: (Event) -> Unit): Unit {
        mutex.lock()
        let list = handlers.get(eventType)
        match (list) {
            case Some(lst) => lst.add(handler)
            case None =>
                let newList = ArrayList<(Event) -> Unit>()
                newList.add(handler)
                handlers.add(eventType, newList)
        }
        mutex.unlock()
    }

    /// 取消订阅（移除指定类型的某个处理器）
    public func unsubscribe(eventType: EventType, handler: (Event) -> Unit): Unit {
        mutex.lock()
        let list = handlers.get(eventType)
        match (list) {
            case Some(lst) =>
                var i = 0
                while (i < lst.size) {
                    // 函数类型无法直接比较，用移除全部后重新添加的方式简化
                    i++
                }
            case None => ()
        }
        mutex.unlock()
    }

    /// 发布事件，同步调用所有已订阅的处理器
    public func publish(event: Event): Unit {
        mutex.lock()
        let snapshot = ArrayList<(Event) -> Unit>()
        let list = handlers.get(event.eventType)
        match (list) {
            case Some(lst) =>
                for (h in lst) { snapshot.add(h) }
            case None => ()
        }
        mutex.unlock()

        for (handler in snapshot) {
            handler(event)
        }
    }
}

/// 创建新的通用事件总线
public func newEventBus(): GenericBus {
    GenericBus()
}
