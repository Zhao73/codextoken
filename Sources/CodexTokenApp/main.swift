import Cocoa

let application = NSApplication.shared
let codexTokenAppDelegate = MainActor.assumeIsolated { CodexTokenAppDelegate() }
application.delegate = codexTokenAppDelegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
