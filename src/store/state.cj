package trade.store

import std.collection.*
import trade.types.*

// ──────────────────────────────────────────────
// M7 内存状态存储
//
// 保存 Redis offset、信号列表、双轨状态
// ──────────────────────────────────────────────

public class StateStore {
    // symbol → Redis offset
    private let redisOffsets: HashMap<String, String>
    // symbol → 双轨状态
    private let dualTracks: HashMap<String, DualTrackState>
    // symbol → 信号列表
    private let signalStore: HashMap<String, ArrayList<Signal>>

    public init() {
        this.redisOffsets = HashMap<String, String>()
        this.dualTracks = HashMap<String, DualTrackState>()
        this.signalStore = HashMap<String, ArrayList<Signal>>()
    }

    // ── Redis offset ──

    public func setRedisOffset(symbol: String, offset: String): Unit {
        redisOffsets.add(symbol, offset)
    }

    public func getRedisOffset(symbol: String): ?String {
        redisOffsets.get(symbol)
    }

    // ── 双轨状态 ──

    public func setDualTrack(symbol: String, dt: DualTrackState): Unit {
        dualTracks.add(symbol, dt)
    }

    public func getDualTrack(symbol: String): ?DualTrackState {
        dualTracks.get(symbol)
    }

    // ── 信号 ──

    public func addSignal(signal: Signal): Unit {
        let list = signalStore.get(signal.symbol)
        match (list) {
            case Some(lst) => lst.add(signal)
            case None =>
                let newList = ArrayList<Signal>()
                newList.add(signal)
                signalStore.add(signal.symbol, newList)
        }
    }

    public func getSignals(symbol: String): ArrayList<Signal> {
        let list = signalStore.get(symbol)
        match (list) {
            case Some(lst) =>
                let copy = ArrayList<Signal>()
                for (s in lst) { copy.add(s) }
                copy
            case None => ArrayList<Signal>()
        }
    }
}
