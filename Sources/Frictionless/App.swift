import SwiftUI

@main
struct FrictionlessApp: App {
    // using NSApplicationDelegateAdaptor to handle lifecycle + menu bar manually
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings { 
            // Empty Settings scene as we handle settings in the popover/custom window
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var monitor: SystemMonitor!
    var settings: SettingsManager!
    var menuManager: MenuBarManager!
    
    override init() {
        super.init() // Call super.init() for NSObject
        
        // Single Instance Enforcement
        // Identify if another instance is running by Bundle ID (if bundled) or Executable Name
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "com.mstrslv.frictionless")
        let currentApp = NSRunningApplication.current
        
        // If there's another instance running that isn't this one
        for app in runningApps {
            if app != currentApp && app.executableURL == currentApp.executableURL {
                print("Another instance is already running. Terminating.")
                // Activate the existing instance?
                app.activate(options: .activateIgnoringOtherApps)
                NSApp.terminate(nil)
                return
            }
        }
        
        let monitor = SystemMonitor()
        let settings = SettingsManager.shared
        self.monitor = monitor
        self.settings = settings
        self.menuManager = MenuBarManager(monitor: monitor, settings: settings)
        
        // Set App Icon
        if let imagePath = Bundle.module.path(forResource: "FrictionlessIcon", ofType: "jpg"),
           let image = NSImage(contentsOfFile: imagePath) {
            NSApplication.shared.applicationIconImage = image
        }
        
        // Enforce Launch at Login (Default ON)
        SystemActions.setLaunchAtLogin(enabled: settings.launchAtLogin)
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide the dock icon
        NSApp.setActivationPolicy(.accessory)
    }
}
