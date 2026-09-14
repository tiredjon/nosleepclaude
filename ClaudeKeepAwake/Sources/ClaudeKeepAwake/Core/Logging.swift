import os.log

enum Log {
    static let subsystem = "dev.tiredjon.ClaudeKeepAwake"

    static let sleep = Logger(subsystem: subsystem, category: "SleepManager")
    static let power = Logger(subsystem: subsystem, category: "PowerMonitor")
    static let system = Logger(subsystem: subsystem, category: "SystemEvents")
    static let login = Logger(subsystem: subsystem, category: "LaunchAtLogin")
    static let app = Logger(subsystem: subsystem, category: "App")
}
