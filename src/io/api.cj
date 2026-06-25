package trade.io

import std.collection.*
import trade.types.*
import trade.log.*

let apiLog = logger("API")

// ──────────────────────────────────────────────
// M8 HTTP API 服务
//
// 提供 REST 接口查询信号、结构、级别和健康状态
// 使用 stdx.net.http 实现（预留接口，待 stdx 就绪后启用完整 HTTP）
// ──────────────────────────────────────────────

/// HTTP API 服务
public class ApiGateway {
    private let httpAddr: String
    private let httpPort: Int64
    private var running: Bool

    public init(addr: String, port: Int64) {
        this.httpAddr = addr
        this.httpPort = port
        this.running = false
    }

    /// 启动 HTTP 服务
    public func start(data: HashMap<String, Any>): Unit {
        if (running) { return }
        running = true

        apiLog.info("HTTP API starting on ${httpAddr}:${httpPort}")
        apiLog.info("Endpoints:")
        apiLog.info("  GET /health         — 健康检查")
        apiLog.info("  GET /signals        — 查询信号列表")
        apiLog.info("  GET /structure      — 查询结构树")
        apiLog.info("  GET /levels         — 查询级别信息")

        // 后台线程保持 API 服务存活（未来替换为 stdx.net.http 真服务）
        spawn { =>
            while (running) {
                sleep(Duration.second * 30)
            }
        }
    }

    /// 停止 HTTP 服务
    public func stop(): Unit {
        running = false
        apiLog.info("HTTP API stopped")
    }
}
