package trade.tree

import std.collection.*
import trade.types.*
import trade.bus.*

// ──────────────────────────────────────────────
// M3 版本化结构树
//
// 存储每个 symbol 每级别的版本化结构快照。
// 每次提交创建新版本，通过事件总线通知订阅方。
// ──────────────────────────────────────────────

/// 版本信息
public struct VersionInfo {
    public let versionId: String
    public let timestamp: Int64
    public let diff: VersionDiff

    public init(versionId: String, timestamp: Int64, diff: VersionDiff) {
        this.versionId = versionId
        this.timestamp = timestamp
        this.diff = diff
    }
}

/// 结构树
public class Tree {
    private let bus: GenericBus
    // symbol → (levelStr → (versions))
    private let store: HashMap<String, HashMap<String, ArrayList<LevelStructure>>>
    // 元素 lineage 注册表
    private let lineageMap: HashMap<String, String>  // elementID → lineageID
    private let elementRegistry: HashMap<String, StructureElement>
    private var versionCounter: Int64

    public init(bus: GenericBus) {
        this.bus = bus
        this.store = HashMap<String, HashMap<String, ArrayList<LevelStructure>>>()
        this.lineageMap = HashMap<String, String>()
        this.elementRegistry = HashMap<String, StructureElement>()
        this.versionCounter = 0
    }

    /// 提交新版本
    public func commit(symbol: String, level: Level, state: LevelStructure, diff: VersionDiff): String {
        versionCounter++
        let levelStr = "${level}"
        let versionId = "${symbol}_${levelStr}_v${versionCounter}"

        // 获取该 symbol 该级别的版本列表
        let symbolStore = getOrCreateSymbolStore(symbol)
        let levelVersions = getOrCreateLevelVersions(symbolStore, levelStr)
        levelVersions.add(state)

        // 发布结构变更事件
        let payload = "version:${versionId},symbol:${symbol},level:${levelStr}"
        bus.publish(Event(EventType.StructureCommitted, payload))

        versionId
    }

    /// 获取指定 symbol 和级别的最新结构
    public func getLatestStructure(symbol: String, level: Level): ?LevelStructure {
        let symbolStore = store.get(symbol)
        match (symbolStore) {
            case Some(sMap) =>
                let levelStr = "${level}"
                let levelVersions = sMap.get(levelStr)
                match (levelVersions) {
                    case Some(versions) =>
                        if (versions.size > 0) {
                            Some(versions[versions.size - 1])
                        } else { None }
                    case None => None
                }
            case None => None
        }
    }

    /// 注册元素 lineage
    public func registerElement(elementId: String, lineageId: String, elementType: ElementType, validFromTS: Int64): Unit {
        lineageMap.add(elementId, lineageId)
        elementRegistry.add(elementId, StructureElement(elementId, elementType, lineageId, validFromTS))
    }

    /// 解析 lineage（获取元素所有历史版本 ID）
    public func resolveLineage(lineageId: String): ArrayList<String> {
        let result = ArrayList<String>()
        for (key in lineageMap.keys()) {
            let val = lineageMap.get(key)
            match (val) {
                case Some(v) =>
                    if (v == lineageId) { result.add(key) }
                case None => ()
            }
        }
        result
    }

    /// 获取当前最新结构（只读）
    public func getCurrentState(symbol: String, level: Level): ?LevelStructure {
        getLatestStructure(symbol, level)
    }

    // ── 内部 ──

    private func getOrCreateSymbolStore(symbol: String): HashMap<String, ArrayList<LevelStructure>> {
        let existing = store.get(symbol)
        match (existing) {
            case Some(sMap) => sMap
            case None =>
                let newMap = HashMap<String, ArrayList<LevelStructure>>()
                store.add(symbol, newMap)
                newMap
        }
    }

    private func getOrCreateLevelVersions(symbolStore: HashMap<String, ArrayList<LevelStructure>>, levelStr: String): ArrayList<LevelStructure> {
        let existing = symbolStore.get(levelStr)
        match (existing) {
            case Some(versions) => versions
            case None =>
                let newVersions = ArrayList<LevelStructure>()
                symbolStore.add(levelStr, newVersions)
                newVersions
        }
    }
}
