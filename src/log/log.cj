package trade.log

import std.deriving.*
import std.time.*

// ──────────────────────────────────────────────
// 日志组件 — 轻量结构化日志
// 输出格式: [2026-06-25 15:04:12] [INFO] [组件] 消息
// ──────────────────────────────────────────────

@Derive[Equatable]
public enum LogLevel {
    | Debug
    | Info
    | Warn
    | Error
}

public class Logger {
    private let component: String
    private var minLevel: LogLevel

    public init(component: String, minLevel: LogLevel) {
        this.component = component
        this.minLevel = minLevel
    }

    public func setLevel(lvl: LogLevel): Unit { this.minLevel = lvl }

    public func debug(msg: String): Unit { logMessage(LogLevel.Debug, msg) }
    public func info(msg: String): Unit  { logMessage(LogLevel.Info, msg) }
    public func warn(msg: String): Unit  { logMessage(LogLevel.Warn, msg) }
    public func error(msg: String): Unit { logMessage(LogLevel.Error, msg) }

    private func logMessage(lvl: LogLevel, msg: String): Unit {
        if (shouldLog(lvl)) {
            let lvlStr = match (lvl) {
                case LogLevel.Debug => "DEBUG"
                case LogLevel.Info => "INFO"
                case LogLevel.Warn => "WARN"
                case LogLevel.Error => "ERROR"
            }
            println("${nowStr()} [${lvlStr}] [${component}] ${msg}")
        }
    }

    private func shouldLog(lvl: LogLevel): Bool {
        match (minLevel) {
            case LogLevel.Debug => true
            case LogLevel.Info =>
                match (lvl) {
                    case LogLevel.Debug => false
                    case _ => true
                }
            case LogLevel.Warn =>
                match (lvl) {
                    case LogLevel.Debug | LogLevel.Info => false
                    case _ => true
                }
            case LogLevel.Error =>
                lvl == LogLevel.Error
        }
    }
}

func nowStr(): String {
    let dt = DateTime.now()
    let s = dt.toString()
    // 格式: "2026-06-25T15:04:12.123" → "2026-06-25 15:04:12"
    let parts = s.split("T")
    if (parts.size >= 2) {
        let datePart = parts[0]
        let timePart = parts[1]
        if (timePart.size >= 8 && datePart.size >= 10) {
            let bytes: Array<UInt8> = [
                datePart[0], datePart[1], datePart[2], datePart[3],
                datePart[4], datePart[5], datePart[6], datePart[7],
                datePart[8], datePart[9],
                b' ',
                timePart[0], timePart[1], timePart[2],
                timePart[3], timePart[4], timePart[5],
                timePart[6], timePart[7]
            ]
            String.fromUtf8(bytes)
        } else { s }
    } else { s }
}

public func logger(component: String): Logger {
    Logger(component, LogLevel.Info)
}
