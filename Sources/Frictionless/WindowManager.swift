import SwiftUI
import AppKit

class WindowManager: NSObject, ObservableObject {
    static let shared = WindowManager()
    
    // Check if windows are open
    private var cpuWindow: NSWindow?
    private var ramWindow: NSWindow?
    private var diskWindow: NSWindow?
    private var netWindow: NSWindow?
    private var aboutWindow: NSWindow?
    
    func openWindow(for type: ResourceType, monitor: SystemMonitor, settings: SettingsManager) {
        let title = type.rawValue
        
        // Bring to front if already exists
        switch type {
        case .cpu:
            if let w = cpuWindow { w.makeKeyAndOrderFront(nil); return }
        case .ram:
            if let w = ramWindow { w.makeKeyAndOrderFront(nil); return }
        case .disk:
            if let w = diskWindow { w.makeKeyAndOrderFront(nil); return }
        case .network:
            if let w = netWindow { w.makeKeyAndOrderFront(nil); return }
        }
        
        // Create new window
        let window = createWindow(title: title)
        
        // Set Content
        switch type {
        case .cpu:
            let view = CPUDetailView(monitor: monitor)
            window.contentViewController = NSHostingController(rootView: view)
            cpuWindow = window
            window.delegate = self // To handle closing cleanup
            
        case .ram:
            let view = RAMDetailView(monitor: monitor)
            window.contentViewController = NSHostingController(rootView: view)
            ramWindow = window
            window.delegate = self
            
        case .disk:
            let view = DiskDetailView(monitor: monitor, settings: settings)
            window.contentViewController = NSHostingController(rootView: view)
            diskWindow = window
            window.delegate = self
            
        case .network:
            let view = NetworkDetailView(monitor: monitor)
            window.contentViewController = NSHostingController(rootView: view)
            netWindow = window
            window.delegate = self
        }
        
        centerWindow(window)
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        centerWindow(window)
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    func showAboutWindow() {
        if aboutWindow == nil {
            let view = AboutView()
                .frame(width: 350, height: 310) // Expanded +30
            
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 350, height: 310),
                styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
                backing: .buffered, defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.titlebarAppearsTransparent = true
            panel.title = "About"
            panel.backgroundColor = .black // Strict black
            panel.isMovableByWindowBackground = true
            panel.contentViewController = NSHostingController(rootView: view)
            panel.delegate = self
            centerWindow(panel)
            aboutWindow = panel
        }
        
        aboutWindow?.makeKeyAndOrderFront(nil)
        aboutWindow?.center()
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    private func createWindow(title: String) -> NSWindow {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 500),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel], // Utility style, non-activating
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.level = .floating // Float above other windows
        window.collectionBehavior = [.canJoinAllSpaces, .transient]
        window.backgroundColor = NSColor.windowBackgroundColor
        return window
    }
    
    private func centerWindow(_ window: NSWindow) {
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let windowRect = window.frame
            
            let x = screenRect.midX - (windowRect.width / 2)
            let y = screenRect.midY - (windowRect.height / 2)
            
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
}

extension WindowManager: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        
        if window == cpuWindow { cpuWindow = nil }
        if window == ramWindow { ramWindow = nil }
        if window == diskWindow { diskWindow = nil }
        if window == netWindow { netWindow = nil }
        if window == aboutWindow { aboutWindow = nil }
    }
}

enum ResourceType: String {
    case cpu = "Processor"
    case ram = "Memory"
    case disk = "Storage"
    case network = "Network"
}
