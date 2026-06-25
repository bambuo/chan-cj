package trade.types

import std.collection.*
import std.deriving.*

// ──────────────────────────────────────────────
// 缠论结构类型（M3 结构树中的版本化元素）
// ──────────────────────────────────────────────

/// 元素类型
public enum ElementType {
    | MergedKLine
    | Fractal
    | Stroke
    | PivotZone
    | TrendPattern
}

/// 结构元素（版本化元素的元数据）
public struct StructureElement {
    public let id: String
    public let elementType: ElementType
    public let lineageId: String
    public let validFromTS: Int64

    public init(id: String, elementType: ElementType, lineageId: String, validFromTS: Int64) {
        this.id = id
        this.elementType = elementType
        this.lineageId = lineageId
        this.validFromTS = validFromTS
    }
}

/// 中枢构建模式
public enum PivotZoneMode {
    | Stroke    // 基于笔构建中枢
    | Segment   // 基于线段构建中枢
}

/// 方向枚举
@Derive[Equatable]
public enum ChanDirection {
    | Up
    | Down
}

/// 笔（M3 结构类型）
public struct Stroke {
    public let id: String
    public let elementType: ElementType
    public let lineageId: String
    public let validFromTS: Int64
    public let startFractalId: String
    public let direction: ChanDirection
    public let startPrice: Float64
    public let endPrice: Float64
    public let high: Float64
    public let low: Float64

    public init(id: String, elementType: ElementType, lineageId: String, validFromTS: Int64,
                startFractalId: String, direction: ChanDirection,
                startPrice: Float64, endPrice: Float64, high: Float64, low: Float64) {
        this.id = id
        this.elementType = elementType
        this.lineageId = lineageId
        this.validFromTS = validFromTS
        this.startFractalId = startFractalId
        this.direction = direction
        this.startPrice = startPrice
        this.endPrice = endPrice
        this.high = high
        this.low = low
    }
}

/// 中枢
public struct PivotZone {
    public let zg: Float64
    public let zd: Float64
    public let startIndex: Int64
    public let endIndex: Int64
    public let direction: ChanDirection
    public let completed: Bool

    public init(zg: Float64, zd: Float64, startIndex: Int64, endIndex: Int64,
                direction: ChanDirection, completed: Bool) {
        this.zg = zg
        this.zd = zd
        this.startIndex = startIndex
        this.endIndex = endIndex
        this.direction = direction
        this.completed = completed
    }
}

/// 走势类型
public struct TrendPattern {
    public let direction: ChanDirection
    public let isTrend: Bool
    public let pivotZones: ArrayList<PivotZone>
    public let completed: Bool

    public init(direction: ChanDirection, isTrend: Bool,
                pivotZones: ArrayList<PivotZone>, completed: Bool) {
        this.direction = direction
        this.isTrend = isTrend
        this.pivotZones = pivotZones
        this.completed = completed
    }
}

/// 版本差异
public struct VersionDiff {
    public let removedElementIds: ArrayList<String>
    public let addedElementIds: ArrayList<String>
    public let affectedWindowTS: ArrayList<Int64>

    public init(removedElementIds: ArrayList<String>,
                addedElementIds: ArrayList<String>,
                affectedWindowTS: ArrayList<Int64>) {
        this.removedElementIds = removedElementIds
        this.addedElementIds = addedElementIds
        this.affectedWindowTS = affectedWindowTS
    }
}

/// 级别结构
public struct LevelStructure {
    public let level: Level
    public let strokes: ArrayList<Stroke>
    public let pivotZones: ArrayList<PivotZone>
    public let trendPatterns: ArrayList<TrendPattern>

    public init(level: Level, strokes: ArrayList<Stroke>,
                pivotZones: ArrayList<PivotZone>,
                trendPatterns: ArrayList<TrendPattern>) {
        this.level = level
        this.strokes = strokes
        this.pivotZones = pivotZones
        this.trendPatterns = trendPatterns
    }
}

/// 双轨状态
public struct DualTrackState {
    public let provisional: LevelStructure
    public let confirmed: LevelStructure
    public let inSync: Bool
    public let driftSince: Int64

    public init(provisional: LevelStructure, confirmed: LevelStructure,
                inSync: Bool, driftSince: Int64) {
        this.provisional = provisional
        this.confirmed = confirmed
        this.inSync = inSync
        this.driftSince = driftSince
    }
}

/// 线段（算法内部表示）
public struct AlgoSegment {
    public let direction: ChanDirection
    public let strokes: ArrayList<AlgoStroke>
    public let startIndex: Int64
    public let endIndex: Int64
    public let high: Float64
    public let low: Float64

    public init(direction: ChanDirection, strokes: ArrayList<AlgoStroke>,
                startIndex: Int64, endIndex: Int64, high: Float64, low: Float64) {
        this.direction = direction
        this.strokes = strokes
        this.startIndex = startIndex
        this.endIndex = endIndex
        this.high = high
        this.low = low
    }
}

/// 笔（算法内部表示）
public struct AlgoStroke {
    public let start: ChanKline
    public let end: ChanKline
    public let startIndex: Int64
    public let endIndex: Int64
    public let direction: ChanDirection
    public let isVirtual: Bool
    public let startPrice: Float64
    public let endPrice: Float64
    public let high: Float64
    public let low: Float64

    public init(start: ChanKline, end: ChanKline,
                startIndex: Int64, endIndex: Int64,
                direction: ChanDirection, isVirtual: Bool,
                startPrice: Float64, endPrice: Float64,
                high: Float64, low: Float64) {
        this.start = start
        this.end = end
        this.startIndex = startIndex
        this.endIndex = endIndex
        this.direction = direction
        this.isVirtual = isVirtual
        this.startPrice = startPrice
        this.endPrice = endPrice
        this.high = high
        this.low = low
    }
}

/// 中枢（算法内部表示）
public class AlgoPivotZone {
    public let zg: Float64
    public let zd: Float64
    public let startIndex: Int64
    public var endIndex: Int64
    public let direction: ChanDirection
    public var completed: Bool

    public init(zg: Float64, zd: Float64, startIndex: Int64, endIndex: Int64,
                direction: ChanDirection, completed: Bool) {
        this.zg = zg
        this.zd = zd
        this.startIndex = startIndex
        this.endIndex = endIndex
        this.direction = direction
        this.completed = completed
    }
}

/// 走势类型（算法内部表示）
public class AlgoTrendPattern {
    public let direction: ChanDirection
    public var isTrend: Bool
    public let zones: ArrayList<AlgoPivotZone>
    public var completed: Bool
    public var completionReason: String

    public init(direction: ChanDirection, isTrend: Bool,
                zones: ArrayList<AlgoPivotZone>, completed: Bool,
                completionReason: String) {
        this.direction = direction
        this.isTrend = isTrend
        this.zones = zones
        this.completed = completed
        this.completionReason = completionReason
    }
}

/// 背驰信号（算法内部表示）
public class AlgoDivergence {
    public let symbol: String
    public let divergenceType: String
    public let confirmed: Bool
    public let entryMACD: Float64
    public let exitMACD: Float64
    public let ratio: Float64
    public let priceHigh: Float64

    public init(symbol: String, divergenceType: String, confirmed: Bool,
                entryMACD: Float64, exitMACD: Float64, ratio: Float64, priceHigh: Float64) {
        this.symbol = symbol
        this.divergenceType = divergenceType
        this.confirmed = confirmed
        this.entryMACD = entryMACD
        this.exitMACD = exitMACD
        this.ratio = ratio
        this.priceHigh = priceHigh
    }
}
