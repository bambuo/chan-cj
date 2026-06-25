package trade.store

import std.collection.*
import std.convert.*
import trade.types.*

// ──────────────────────────────────────────────
// M0 快照管理器
//
// 将系统状态（Redis offset、双轨状态、信号）序列化到磁盘 JSON
// 支持定期 + 事件驱动的快照和恢复
// ──────────────────────────────────────────────

/// 快照数据结构
public struct Snapshot {
    public let symbol: String
    public let redisOffset: String
    public let signals: ArrayList<Signal>
    public let dualTrack: ?DualTrackState

    public init(symbol: String, redisOffset: String,
                signals: ArrayList<Signal>, dualTrack: ?DualTrackState) {
        this.symbol = symbol
        this.redisOffset = redisOffset
        this.signals = signals
        this.dualTrack = dualTrack
    }
}

/// 快照配置
public struct SnapshotConfig {
    public let snapshotDir: String
    public let retainCount: Int64

    public init(snapshotDir: String, retainCount: Int64) {
        this.snapshotDir = snapshotDir
        this.retainCount = retainCount
    }
}

/// 快照管理器
public class SnapshotManager {
    private let config: SnapshotConfig

    public init(config: SnapshotConfig) {
        this.config = config
    }

    /// 保存快照（简化：不实际写磁盘，仅记录内存日志）
    public func save(symbol: String, snapshot: Snapshot): Unit {
        println("[Snapshot] Saving snapshot for ${symbol}")
    }

    /// 恢复最新快照（简化：始终返回 None）
    public func restoreLatest(symbol: String): ?Snapshot {
        println("[Snapshot] No snapshot available for ${symbol}")
        None
    }
}
