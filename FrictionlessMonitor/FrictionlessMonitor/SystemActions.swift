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
        // Simple applescript approach to verify user intent and permissions
        let source = """
        try
            tell application "Finder" to empty trash
        on error errMsg number errNum
            return errNum
        end try
        """
        executeAppleScript(source)
    }
    
    private static func executeAppleScript(_ source: String) {
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: source) {
            let output = scriptObject.executeAndReturnError(&error)
            
            // Check for explicit returns (like error numbers)
            if let desc = output.stringValue {
                print("AppleScript Result: \(desc)")
            }
            
            if let err = error {
                print("AppleScript Error: \(err)")
            }
        }
    }
    
    static func clearTempFiles() -> String {
        let fileManager = FileManager.default
        var deletedCount = 0
        var savedSpace: Int64 = 0
        
        let pathsToClear = [
            NSTemporaryDirectory(),
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.path
        ].compactMap { $0 }
        
        for rootPath in pathsToClear {
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: rootPath)
                for file in contents {
                    let path = (rootPath as NSString).appendingPathComponent(file)
                    
                    // Skip essential system caches if needed (optional safety)
                    
                    do {
                        let attr = try fileManager.attributesOfItem(atPath: path)
                        let size = attr[.size] as? Int64 ?? 0
                        try fileManager.removeItem(atPath: path)
                        deletedCount += 1
                        savedSpace += size
                    } catch {
                        // Skip items we can't delete (in use/permissions)
                        continue
                    }
                }
            } catch {
                continue
            }
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
