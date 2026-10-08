import AppKit

if CommandLine.arguments.contains("--self-test") {
    do { try runCoreTests(); exit(0) }
    catch { fputs("FAIL: \(error)\n", stderr); exit(1) }
}

let application = NSApplication.shared
application.setActivationPolicy(.regular)
let delegate = AppDelegate()
application.delegate = delegate
application.run()
