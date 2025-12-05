import Foundation
import AppKit
import Cocoa
import ServiceManagement

class SystemActions {
    
    // MARK: - Launch at Login
    static func setLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            do {
                if enabled {
                    if service.status == .enabled { return }
                    try service.register()
                } else {
                    if service.status == .notRegistered { return }
                    try service.unregister()
                }
            } catch {
                print("LaunchAtLogin Error: \(error)")
            }
        }
    }
    
    // MARK: - App Management
    
    struct RunningApp: Identifiable {
        let id: String
        let name: String
        let icon: NSImage?
        let pid: pid_t
        let bundleIdentifier: String?
    }
    
    static func getRunningApplications() -> [RunningApp] {
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .map { app in
                RunningApp(
                    id: String(app.processIdentifier),
                    name: app.localizedName ?? "Unknown",
                    icon: app.icon,
                    pid: app.processIdentifier,
                    bundleIdentifier: app.bundleIdentifier
                )
            }
            .sorted { $0.name < $1.name }
    }
    
    static func killApplication(pid: pid_t) {
        if let app = NSRunningApplication(processIdentifier: pid) {
            app.terminate()
            
            // Force kill if it doesn't exit after a delay?
            // For now, let's trust terminate, or we can use kill() syscall for aggression.
            // kill(pid, SIGTERM)
        }
    }
    
    // MARK: - Storage Management
    
    static func emptyTrash() {
        // Simple applescript approach to avoid permissions issues if possible, 
        // or FileManager but FileManager requires iterating ~/.Trash
        let source = "tell application \"Finder\" to empty trash"
        executeAppleScript(source)
    }
    
    private static func executeAppleScript(_ source: String) {
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: source) {
            scriptObject.executeAndReturnError(&error)
            if let err = error {
                let errCode = err["NSAppleScriptErrorNumber"] as? Int
                // -128 is "User cancelled" which happens if they dismiss a dialog or permission prompt
                if errCode != -128 {
                    print("AppleScript Error: \(err)")
                }
            }
        }
    }
    
    static func clearTempFiles() -> String {
        let tempDir = NSTemporaryDirectory()
        var deletedCount = 0
        var savedSpace: Int64 = 0
        
        do {
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(atPath: tempDir)
            
            for file in contents {
                let path = (tempDir as NSString).appendingPathComponent(file)
                do {
                    let attr = try fileManager.attributesOfItem(atPath: path)
                    let size = attr[.size] as? Int64 ?? 0
                    try fileManager.removeItem(atPath: path)
                    deletedCount += 1
                    savedSpace += size
                } catch {
                    // Ignore permission errors
                }
            }
        } catch {
            return "Error listing temp files."
        }
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return "Cleared \(deletedCount) items (\(formatter.string(fromByteCount: savedSpace)))"
    }
    
    static func openExternalApp(path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.open(url)
    }
}
