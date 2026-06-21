package trade.infrastructure

import std.collection.*
import std.sync.*
import stdx.net.http.*
import stdx.encoding.url.*
import stdx.encoding.json.*
import stdx.crypto.kit.*
import stdx.net.tls.common.*
import stdx.net.tls.TlsClientConfig
import trade.domain.*

// ──────────────────────────────────────────────
// Infrastructure — Binance WebSocket 客户端
// ──────────────────────────────────────────────

public class BinanceClient {
    private let wsUrl: String = "wss://stream.binance.com:9443/ws"
    private let eventBus: InMemoryEventBus
    private let symbols: ArrayList<String>
    private var interval: String
    private var httpClient: Client
    private var ws: ?WebSocket
    private var readerThread: ?Future<Unit>
    private var running: AtomicBool

    public init(eventBus: InMemoryEventBus) {
        this.eventBus = eventBus
        this.symbols = ArrayList<String>()
        this.interval = "1m"

        var tlsConfig = TlsClientConfig()
        tlsConfig.verifyMode = Default
        this.httpClient = ClientBuilder().tlsConfig(tlsConfig).build()

        this.ws = None
        this.readerThread = None
        this.running = AtomicBool(false)
    }

    public func connect(symbols: ArrayList<String>, interval: String): Unit {
        this.symbols.clear()
        for (s in symbols) { this.symbols.add(s) }
        this.interval = interval
        this.running.store(true)
        connectWithRetry()
        this.readerThread = Some(spawn { => this.readLoop() })
    }

    public func disconnect(): Unit {
        running.store(false)
        match (this.ws) {
            case Some(wsConn) =>
                try {
                    wsConn.writeCloseFrame(status: 1000, reason: "client shutdown")
                    let _ = wsConn.read()
                } catch (_) { }
                wsConn.closeConn()
            case None => ()
        }
        httpClient.close()
    }

    // ── Internal: connection management ──

    private func connectOnce(): Bool {
        try {
            let url = URL.parse(wsUrl)
            let (wsConn, _) = WebSocket.upgradeFromClient(httpClient, url)
            this.ws = Some(wsConn)

            let subscribeObj = JsonObject()
            subscribeObj.put("method", JsonString("SUBSCRIBE"))
            let params = JsonArray()
            for (sym in symbols) {
                let stream = sym.toAsciiLower() + "@kline_" + interval
                params.add(JsonString(stream))
            }
            subscribeObj.put("params", params)
            subscribeObj.put("id", JsonInt(1))

            let subscribeStr = subscribeObj.toString()
            wsConn.write(WebSocketFrameType.TextWebFrame, subscribeStr.toArray())

            println("[WS] Connected & subscribed: ${symbols} @ ${interval}")
            return true
        } catch (e: Exception) {
            println("[WS] Connection failed: ${e}")
            this.ws = None
            return false
        }
    }

    private func connectWithRetry(): Unit {
        while (running.load() && !connectOnce()) {
            println("[WS] Retrying in 3 seconds...")
            sleep(Duration.second * 3)
        }
    }

    // ── Internal: reader loop ──

    private func readLoop(): Unit {
        while (running.load()) {
            match (this.ws) {
                case Some(wsConn) =>
                    try {
                        let payload = receiveMessage(wsConn)
                        let payloadBytes = payload.toArray()
                        let payloadStr = String.fromUtf8(payloadBytes)
                        processMessage(payloadStr)
                    } catch (e: Exception) {
                        println("[WS] Connection lost: ${e}")
                        this.ws = None
                        connectWithRetry()
                    }
                case None =>
                    sleep(Duration.second * 1)
                    connectWithRetry()
            }
        }
    }

    // ── Internal: message assembly ──

    private func receiveMessage(ws: WebSocket): ArrayList<UInt8> {
        let data = ArrayList<UInt8>()
        var frame = ws.read()
        while (true) {
            match (frame.frameType) {
                case WebSocketFrameType.TextWebFrame
                   | WebSocketFrameType.BinaryWebFrame =>
                    data.add(all: frame.payload)
                    if (frame.fin) { break }
                case WebSocketFrameType.ContinuationWebFrame =>
                    data.add(all: frame.payload)
                    if (frame.fin) { break }
                case WebSocketFrameType.CloseWebFrame =>
                    ws.write(WebSocketFrameType.CloseWebFrame, frame.payload)
                    throw Exception("Received close frame")
                case WebSocketFrameType.PingWebFrame =>
                    ws.writePongFrame(frame.payload)
                case _ => ()
            }
            frame = ws.read()
        }
        return data
    }

    // ── Internal: JSON processing → publish domain events ──

    private func processMessage(msg: String): Unit {
        try {
            let jv = JsonValue.fromStr(msg)
            let obj = jv.asObject()
            if (!obj.containsKey("e")) { return }
            let eventTypeField = obj["e"].asString().getValue()
            if (eventTypeField != "kline") { return }

            let kObj = obj["k"].asObject()
            let kline = parseKlineFromJson(kObj)

            eventBus.publish(Event(EventType.KlineReceived, kline))

            if (kline.isClosed) {
                eventBus.publish(Event(EventType.KlineClosed, kline))
            }
        } catch (e: Exception) {
            eventBus.publish(Event(EventType.ErrorEvent,
                "Failed to parse Binance message: ${e}"))
        }
    }
}
