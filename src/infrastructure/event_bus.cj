package trade.infrastructure

import std.collection.*
import std.sync.*
import trade.domain.*

// ──────────────────────────────────────────────
// Infrastructure — InMemoryEventBus 内存事件总线
// ──────────────────────────────────────────────

public class InMemoryEventBus {
    private let handlers: HashMap<EventType, ArrayList<(Event) -> Unit>>
    private let mutex: Mutex

    public init() {
        this.handlers = HashMap<EventType, ArrayList<(Event) -> Unit>>()
        this.mutex = Mutex()
    }

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
