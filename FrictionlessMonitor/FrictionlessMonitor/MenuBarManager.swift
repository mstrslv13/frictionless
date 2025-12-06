import Cocoa
import Combine
import SwiftUI

class MenuBarManager: NSObject {
    private var statusItems: [NSStatusItem] = []
    private var cancellables = Set<AnyCancellable>()
    private var monitor: SystemMonitor
    private var settings: SettingsManager
    
    // Single active popover to prevent exclusivity crashes and ensure one-at-a-time behavior
    private var activePopover: NSPopover?
    private var activePopoverButton: NSStatusBarButton? // Track which button opened it
    
    // Stats formatting params for Single Mode rotation
    private var timer: Timer?
    private var currentIndex = 0
    
    private struct RotationConfig {
        let icon: String
        let text: (SystemMonitor) -> String
    }
    
    private let configurations: [String: RotationConfig] = [
        "cpu": RotationConfig(icon: "cpu", text: { String(format: "%.0f%%", $0.cpuUsage) }),
        "ram": RotationConfig(icon: "memorychip", text: { monitor in
            switch SettingsManager.shared.ramDisplayMode {
            case .percent: return String(format: "%.0f%%", monitor.memoryUsage)
            case .used: return formatBytes(Double(monitor.memoryUsedBytes))
            case .free: 
                let total = ProcessInfo.processInfo.physicalMemory
                let free = (total > monitor.memoryUsedBytes) ? (total - monitor.memoryUsedBytes) : 0
                return formatBytes(Double(free))
            }
        }),
        "disk": RotationConfig(icon: "internaldrive", text: { monitor in
             switch SettingsManager.shared.diskDisplayMode {
            case .percent: return String(format: "%.0f%%", monitor.diskUsage)
            case .used: return formatBytes(Double(monitor.diskUsedBytes))
            case .free: return formatBytes(Double(monitor.diskFreeBytes))
            }
        }),
        "net": RotationConfig(icon: "network", text: { formatBytes($0.networkIn + $0.networkOut) + "/s" })
    ]
    
    init(monitor: SystemMonitor, settings: SettingsManager) {
        self.monitor = monitor
        self.settings = settings
        super.init()
        
        setupObservers()
        setupMenuMode()
    }
    
    private func setupObservers() {
        UserDefaults.standard.publisher(for: \.isSingleIconMode)
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.setupMenuMode() }
            }.store(in: &cancellables)
            
        // Observe individual flags to update menu items dynamically
        let flags = [\UserDefaults.showCPU, \UserDefaults.showRAM, \UserDefaults.showDisk, \UserDefaults.showNet]
        for flag in flags {
             UserDefaults.standard.publisher(for: flag)
                .sink { [weak self] _ in
                    DispatchQueue.main.async { self?.setupMenuMode() }
                }.store(in: &cancellables)
        }
            
        UserDefaults.standard.publisher(for: \.rotationInterval)
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.setupRotationTimer() }
            }.store(in: &cancellables)
        
        // Watch for order changes
        UserDefaults.standard.publisher(for: \.menuOrderString)
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.setupMenuMode() }
            }.store(in: &cancellables)
        
        monitor.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.updateStatusItemViews() }
        }.store(in: &cancellables)
    }
    
    func setupMenuMode() {
        // Clear existing
        statusItems.forEach { NSStatusBar.system.removeStatusItem($0) }
        statusItems.removeAll()
        timer?.invalidate()
        closeActivePopover() // Close any open windows on mode switch
        buttonMap.removeAll()
        
        if settings.isSingleIconMode {
            // SINGLE ROTATING ICON logic
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            if let button = item.button {
                button.image = NSImage(systemSymbolName: "circle", accessibilityDescription: "Loading")
                button.action = #selector(statusBarClicked(_:))
                button.target = self
                buttonMap[button] = .main // Use .main as generic rotating handler
            }
            statusItems.append(item)
            setupRotationTimer()
        } else {
             // SPLIT ICONS logic
             // Only add enabled items
             var enabledItems: [String] = []
             let order = settings.menuOrder
             
             // Filter order by enabled status
             for key in order {
                 if key == "cpu" && !settings.showCPU { continue }
                 if key == "ram" && !settings.showRAM { continue }
                 if key == "disk" && !settings.showDisk { continue }
                 if key == "net" && !settings.showNet { continue }
                 enabledItems.append(key)
             }
             
             // Add in REVERSE order for Left-to-Right visual appearance
             for key in enabledItems.reversed() {
                guard let type = SplitItemType(rawValue: key) else { continue }
                let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
                setupClickAction(for: item, type: type)
                statusItems.append(item)
             }
        }
        
        // Trigger immediate update
        updateStatusItemViews()
    }
    
    private func setupRotationTimer() {
        timer?.invalidate()
        guard settings.isSingleIconMode else { return }
        
        timer = Timer.scheduledTimer(withTimeInterval: settings.rotationInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.rotateInfo()
        }
    }
    
    private func rotateInfo() {
        var enabledTypes: [String] = []
        if settings.showCPU { enabledTypes.append("cpu") }
        if settings.showRAM { enabledTypes.append("ram") }
        if settings.showDisk { enabledTypes.append("disk") }
        if settings.showNet { enabledTypes.append("net") }
        
        if enabledTypes.isEmpty {
             statusItems.first?.button?.title = " -"
             statusItems.first?.button?.image = NSImage(systemSymbolName: "circle.slash", accessibilityDescription: nil)
             return
        }
        
        currentIndex = (currentIndex + 1) % enabledTypes.count 
        let key = enabledTypes[currentIndex]
        
        guard let config = configurations[key] else { return }
        
        if let button = statusItems.first?.button {
            button.image = NSImage(systemSymbolName: config.icon, accessibilityDescription: nil)
            button.title = " " + config.text(monitor)
            button.imagePosition = .imageLeft
        }
    }
    
    private func updateStatusItemViews() {
        if settings.isSingleIconMode {
            // Initial update logic or just rely on timer/rotation?
            // If timer hasn't fired yet, show *something*
            if statusItems.first?.button?.title.isEmpty ?? true {
                 rotateInfo()
            }
            // For real-time updates of the CURRENTLY showing item, we could re-run rotateInfo logic but without incrementing index?
            // Or just fetch current key and update.
            // Simplified: Just let the timer handle rotation updates?
            // No, we want values to update live (e.g. CPU % changing every second).
            
            var enabledTypes: [String] = []
            if settings.showCPU { enabledTypes.append("cpu") }
            if settings.showRAM { enabledTypes.append("ram") }
            if settings.showDisk { enabledTypes.append("disk") }
            if settings.showNet { enabledTypes.append("net") }
            
            if !enabledTypes.isEmpty {
                 let safeIndex = currentIndex % enabledTypes.count 
                 let key = enabledTypes[safeIndex]
                 if let config = configurations[key], let button = statusItems.first?.button {
                      button.image = NSImage(systemSymbolName: config.icon, accessibilityDescription: nil)
                      button.title = " " + config.text(monitor)
                 }
            }
            
        } else {
            // "Separate Icons" Mode
            for item in statusItems {
                guard let button = item.button, let type = buttonMap[button] else { continue }
                
                switch type {
                case .cpu:
                    button.image = NSImage(systemSymbolName: "cpu", accessibilityDescription: "CPU")
                    button.title = String(format: " %.0f%%", monitor.cpuUsage)
                    
                case .ram:
                    button.image = NSImage(systemSymbolName: "memorychip", accessibilityDescription: "RAM")
                    switch settings.ramDisplayMode {
                    case .percent:
                        button.title = String(format: " %.0f%%", monitor.memoryUsage)
                    case .used:
                        button.title = " " + formatBytes(Double(monitor.memoryUsedBytes))
                    case .free:
                        let total = ProcessInfo.processInfo.physicalMemory
                        let free = (total > monitor.memoryUsedBytes) ? (total - monitor.memoryUsedBytes) : 0
                        button.title = " " + formatBytes(Double(free))
                    }
                    
                case .disk:
                    button.image = NSImage(systemSymbolName: "internaldrive", accessibilityDescription: "Disk")
                    switch settings.diskDisplayMode {
                    case .percent:
                        button.title = String(format: " %.0f%%", monitor.diskUsage)
                    case .used:
                        button.title = " " + formatBytes(Double(monitor.diskUsedBytes))
                    case .free:
                        button.title = " " + formatBytes(Double(monitor.diskFreeBytes))
                    }
                    
                case .net:
                    button.image = NSImage(systemSymbolName: "network", accessibilityDescription: "Net")
                    button.title = " " + formatBytes(monitor.networkIn + monitor.networkOut) + "/s"
                    
                case .main: break
                }
            }
        }
    }
    
    // MARK: - Interaction
    
    private enum SplitItemType: String {
        case main = "main"
        case cpu = "cpu"
        case ram = "ram"
        case disk = "disk"
        case net = "net"
    }
    
    private var buttonMap: [NSStatusBarButton: SplitItemType] = [:]
    
    private func setupClickAction(for item: NSStatusItem, type: SplitItemType) {
        guard let button = item.button else { return }
        buttonMap[button] = type
        button.target = self
        button.action = #selector(statusBarClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }
    
    @objc func statusBarClicked(_ sender: NSStatusBarButton) {
        guard let type = buttonMap[sender] else { return }
        
        // If clicking the same button that opened the current popover, close it.
        if let current = activePopover, current.isShown, activePopoverButton == sender {
            current.performClose(sender)
            activePopover = nil
            activePopoverButton = nil
            return
        }
        
        // Otherwise close any existing and open new
        closeActivePopover()
        
        var newPopover: NSPopover?
        
        switch type {
        case .main:
            newPopover = createPopover(content: DetailedStatsView(monitor: monitor, settings: settings))
        case .cpu:
            newPopover = createPopover(content: CPUDetailView(monitor: monitor))
        case .ram:
            newPopover = createPopover(content: RAMDetailView(monitor: monitor))
        case .disk:
            newPopover = createPopover(content: DiskDetailView(monitor: monitor, settings: settings))
        case .net:
            newPopover = createPopover(content: NetworkDetailView(monitor: monitor))
        }
        
        if let p = newPopover {
            p.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            NSApplication.shared.activate(ignoringOtherApps: true)
            activePopover = p
            activePopoverButton = sender
        }
    }
    
    private func closeActivePopover() {
        if let current = activePopover {
            current.close()
            activePopover = nil
            activePopoverButton = nil
        }
    }
    
    private func createPopover<Content: View>(content: Content) -> NSPopover {
        let p = NSPopover()
        p.behavior = .transient
        p.contentViewController = NSHostingController(rootView: content)
        return p
    }
}
