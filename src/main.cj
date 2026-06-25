package trade

import trade.conf.*

// ──────────────────────────────────────────────
// 入口点 — 创建配置和 App，启动系统
// ──────────────────────────────────────────────

main(): Int64 {
    let config = defaultConfig()
    let app = App(config)

    // 捕获 Ctrl+C 优雅退出
    // 简化：直接运行
    app.run()

    0
}
