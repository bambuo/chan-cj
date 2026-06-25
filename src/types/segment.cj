package trade.types

// ──────────────────────────────────────────────
// 特征序列与线段类型
// ──────────────────────────────────────────────

/// 特征序列 K 线
public struct FeatureKLine {
    public let high: Float64
    public let low: Float64
    public let isTopFractal: Bool    // 是否为特征序列顶分型
    public let isBottomFractal: Bool // 是否为特征序列底分型

    public init(high: Float64, low: Float64,
                isTopFractal: Bool, isBottomFractal: Bool) {
        this.high = high
        this.low = low
        this.isTopFractal = isTopFractal
        this.isBottomFractal = isBottomFractal
    }
}

/// 特征序列类型
public enum FeatureSeqType {
    | First   // 第一特征序列
    | Second  // 第二特征序列
}

/// 线段
public struct Segment {
    public let direction: ChanDirection
    public let startStrokeIndex: Int64
    public let endStrokeIndex: Int64
    public let high: Float64
    public let low: Float64

    public init(direction: ChanDirection, startStrokeIndex: Int64,
                endStrokeIndex: Int64, high: Float64, low: Float64) {
        this.direction = direction
        this.startStrokeIndex = startStrokeIndex
        this.endStrokeIndex = endStrokeIndex
        this.high = high
        this.low = low
    }
}
