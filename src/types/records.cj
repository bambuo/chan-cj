package trade.types

// ──────────────────────────────────────────────
// Redis 输出记录结构体
// 所有记录自带时间戳，不依赖 ZSET score
// ──────────────────────────────────────────────

/// 合并 K 线记录
public struct ChanKlineRecord {
    public let time: Int64
    public let high: Float64
    public let low: Float64

    public init(time: Int64, high: Float64, low: Float64) {
        this.time = time
        this.high = high
        this.low = low
    }

    public func toJson(): String {
        """
        {
            "time": ${time},
            "high": ${high},
            "low": ${low}
        }"""
    }
}

/// 分型记录
public struct FractalRecord {
    public let time: Int64
    public let ftype: String
    public let high: Float64
    public let low: Float64
    public let index: Int64

    public init(time: Int64, ftype: String, high: Float64, low: Float64, index: Int64) {
        this.time = time
        this.ftype = ftype
        this.high = high
        this.low = low
        this.index = index
    }

    public func toJson(): String {
        """
        {
            "time": ${time},
            "type": "${ftype}",
            "high": ${high},
            "low": ${low},
            "index": ${index}
        }"""
    }
}

/// 笔记录
public struct StrokeRecord {
    public let time: Int64
    public let startTime: Int64
    public let endTime: Int64
    public let direction: String
    public let startIndex: Int64
    public let endIndex: Int64
    public let startPrice: Float64
    public let endPrice: Float64
    public let high: Float64
    public let low: Float64

    public init(time: Int64, startTime: Int64, endTime: Int64,
                direction: String, startIndex: Int64, endIndex: Int64,
                startPrice: Float64, endPrice: Float64, high: Float64, low: Float64) {
        this.time = time
        this.startTime = startTime
        this.endTime = endTime
        this.direction = direction
        this.startIndex = startIndex
        this.endIndex = endIndex
        this.startPrice = startPrice
        this.endPrice = endPrice
        this.high = high
        this.low = low
    }

    public func toJson(): String {
        """
        {
            "time": ${time},
            "startTime": ${startTime},
            "endTime": ${endTime},
            "direction": "${direction}",
            "startIndex": ${startIndex},
            "endIndex": ${endIndex},
            "startPrice": ${startPrice},
            "endPrice": ${endPrice},
            "high": ${high},
            "low": ${low}
        }"""
    }
}

/// 线段记录
public struct SegmentRecord {
    public let time: Int64
    public let startTime: Int64
    public let endTime: Int64
    public let startPrice: Float64
    public let endPrice: Float64
    public let direction: String
    public let startIndex: Int64
    public let endIndex: Int64

    public init(time: Int64, startTime: Int64, endTime: Int64,
                startPrice: Float64, endPrice: Float64,
                direction: String, startIndex: Int64, endIndex: Int64) {
        this.time = time
        this.startTime = startTime
        this.endTime = endTime
        this.startPrice = startPrice
        this.endPrice = endPrice
        this.direction = direction
        this.startIndex = startIndex
        this.endIndex = endIndex
    }

    public func toJson(): String {
        """
        {
            "time": ${time},
            "startTime": ${startTime},
            "endTime": ${endTime},
            "startPrice": ${startPrice},
            "endPrice": ${endPrice},
            "direction": "${direction}",
            "startIndex": ${startIndex},
            "endIndex": ${endIndex}
        }"""
    }
}

/// 中枢记录
public struct PivotZoneRecord {
    public let time: Int64
    public let startTime: Int64
    public let endTime: Int64
    public let startPrice: Float64
    public let endPrice: Float64
    public let zg: Float64
    public let zd: Float64
    public let startIndex: Int64
    public let endIndex: Int64
    public let direction: String
    public let completed: Bool

    public init(time: Int64, startTime: Int64, endTime: Int64,
                startPrice: Float64, endPrice: Float64,
                zg: Float64, zd: Float64,
                startIndex: Int64, endIndex: Int64,
                direction: String, completed: Bool) {
        this.time = time
        this.startTime = startTime
        this.endTime = endTime
        this.startPrice = startPrice
        this.endPrice = endPrice
        this.zg = zg
        this.zd = zd
        this.startIndex = startIndex
        this.endIndex = endIndex
        this.direction = direction
        this.completed = completed
    }

    public func toJson(): String {
        """
        {
            "time": ${time},
            "startTime": ${startTime},
            "endTime": ${endTime},
            "startPrice": ${startPrice},
            "endPrice": ${endPrice},
            "zg": ${zg},
            "zd": ${zd},
            "startIndex": ${startIndex},
            "endIndex": ${endIndex},
            "direction": "${direction}",
            "completed": ${completed}
        }"""
    }
}

/// 走势类型记录
public struct TrendPatternRecord {
    public let time: Int64
    public let startTime: Int64
    public let endTime: Int64
    public let startPrice: Float64
    public let endPrice: Float64
    public let direction: String
    public let completed: Bool
    public let zonesCount: Int64

    public init(time: Int64, startTime: Int64, endTime: Int64,
                startPrice: Float64, endPrice: Float64,
                direction: String, completed: Bool, zonesCount: Int64) {
        this.time = time
        this.startTime = startTime
        this.endTime = endTime
        this.startPrice = startPrice
        this.endPrice = endPrice
        this.direction = direction
        this.completed = completed
        this.zonesCount = zonesCount
    }

    public func toJson(): String {
        """
        {
            "time": ${time},
            "startTime": ${startTime},
            "endTime": ${endTime},
            "startPrice": ${startPrice},
            "endPrice": ${endPrice},
            "direction": "${direction}",
            "completed": ${completed},
            "zonesCount": ${zonesCount}
        }"""
    }
}

/// 背驰记录
public struct DivergenceRecord {
    public let time: Int64
    public let price: Float64
    public let dtype: String
    public let ratio: Float64
    public let confirmed: Bool

    public init(time: Int64, price: Float64, dtype: String, ratio: Float64, confirmed: Bool) {
        this.time = time
        this.price = price
        this.dtype = dtype
        this.ratio = ratio
        this.confirmed = confirmed
    }

    public func toJson(): String {
        """
        {
            "time": ${time},
            "price": ${price},
            "type": "${dtype}",
            "ratio": ${ratio},
            "confirmed": ${confirmed}
        }"""
    }
}

/// 信号记录
public struct SignalRecord {
    public let time: Int64
    public let stype: String
    public let price: Float64
    public let strength: Float64

    public init(time: Int64, stype: String, price: Float64, strength: Float64) {
        this.time = time
        this.stype = stype
        this.price = price
        this.strength = strength
    }

    public func toJson(): String {
        """
        {
            "time": ${time},
            "type": "${stype}",
            "price": ${price},
            "strength": ${strength}
        }"""
    }
}
