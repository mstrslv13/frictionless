import Foundation
import Combine
import Darwin

class SystemMonitor: ObservableObject {
    @Published var cpuUsage: Double = 0.0
    @Published var memoryUsage: Double = 0.0
    @Published var diskUsage: Double = 0.0
    @Published var networkIn: Double = 0.0 // Bytes per second
    @Published var networkOut: Double = 0.0 // Bytes per second
    
    // Raw Values for Display Modes
    @Published var memoryUsedBytes: UInt64 = 0
    @Published var diskUsedBytes: Int64 = 0
    @Published var diskFreeBytes: Int64 = 0
    
    // Advanced Stats
    @Published var physicalCores: Int = 0
    @Published var logicalCores: Int = 0
    @Published var cpuModel: String = "Unknown"
    
    @Published var sessionNetworkIn: UInt64 = 0
    @Published var sessionNetworkOut: UInt64 = 0
    
    @Published var localIP: String = "Checking..."
    
    // History for Charts (last 60 points)
    @Published var cpuHistory: [Double] = Array(repeating: 0.0, count: 60)
    @Published var ramHistory: [Double] = Array(repeating: 0.0, count: 60)
    @Published var networkInHistory: [Double] = Array(repeating: 0.0, count: 60)
    @Published var networkOutHistory: [Double] = Array(repeating: 0.0, count: 60)
    
    private var timer: Timer?
    private var previousNetworkStats: (inBytes: UInt64, outBytes: UInt64)?
    private var initialNetworkStats: (inBytes: UInt64, outBytes: UInt64)?
    private var lastCheckTime: Date?

    init() {
        self.physicalCores = ProcessInfo.processInfo.activeProcessorCount
        self.logicalCores = ProcessInfo.processInfo.processorCount
        self.cpuModel = SystemMonitor.getCPUModel()
        self.localIP = SystemMonitor.getLocalIP()
        startMonitoring()
    }
    
    func startMonitoring() {
        // Update every 1 second
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateStats()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func updateStats() {
        let cpu = getCPUUsage()
        let ram = getMemoryUsage()
        let disk = getDiskUsage()
        
        self.cpuUsage = cpu
        self.memoryUsage = ram
        self.diskUsage = disk
        
        // Update History
        updateHistory(&cpuHistory, newValue: cpu)
        updateHistory(&ramHistory, newValue: ram)
        
        let currentNetwork = getNetworkUsage()
        if let prev = previousNetworkStats, let lastTime = lastCheckTime {
            let timeDiff = Date().timeIntervalSince(lastTime)
            if timeDiff > 0 {
                let inSpeed = Double(currentNetwork.inBytes - prev.inBytes) / timeDiff
                let outSpeed = Double(currentNetwork.outBytes - prev.outBytes) / timeDiff
                
                self.networkIn = inSpeed
                self.networkOut = outSpeed
                
                updateHistory(&networkInHistory, newValue: inSpeed)
                updateHistory(&networkOutHistory, newValue: outSpeed)
            }
            
            // Update session totals
            if let initial = initialNetworkStats {
                 self.sessionNetworkIn = currentNetwork.inBytes - initial.inBytes
                 self.sessionNetworkOut = currentNetwork.outBytes - initial.outBytes
            } else {
                self.initialNetworkStats = currentNetwork
            }
        }
        self.previousNetworkStats = currentNetwork
        self.lastCheckTime = Date()
    }

    // MARK: - CPU Usage
    private func getCPUUsage() -> Double {
        var cpuLoad = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &cpuLoad) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return 0.0 }
        
        // This gives cumulative ticks. To get usage, we need delta since last check.
        // For simplicity in this lightweight version, we can use a simpler approach or maintain state.
        // Let's implement a stateful calculation for accuracy.
        
        return calculateCPUPercentage(load: cpuLoad)
    }
    
    private var previousCPULoad: host_cpu_load_info?
    
    private func calculateCPUPercentage(load: host_cpu_load_info) -> Double {
        guard let prev = previousCPULoad else {
            previousCPULoad = load
            return 0.0
        }
        
        let userDiff = Double(load.cpu_ticks.0 - prev.cpu_ticks.0)
        let sysDiff = Double(load.cpu_ticks.1 - prev.cpu_ticks.1)
        let idleDiff = Double(load.cpu_ticks.2 - prev.cpu_ticks.2)
        let niceDiff = Double(load.cpu_ticks.3 - prev.cpu_ticks.3)
        
        let totalTicks = userDiff + sysDiff + idleDiff + niceDiff
        let sysUser = userDiff + sysDiff + niceDiff
        
        previousCPULoad = load
        
        if totalTicks == 0 { return 0.0 }
        return (sysUser / totalTicks) * 100.0
    }

    // MARK: - Memory Usage
    private func getMemoryUsage() -> Double {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return 0.0 }
        
        let pageSize = UInt64(vm_kernel_page_size)
        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        
    
        // "App Memory" + "Wired Memory" + "Compressed" is a good approximation of "Used"
        let used = active + wired + compressed
        let total = ProcessInfo.processInfo.physicalMemory
        
        DispatchQueue.main.async {
            self.memoryUsedBytes = used
        }
        
        return (Double(used) / Double(total)) * 100.0
    }

    // MARK: - Disk Usage
    private func getDiskUsage() -> Double {
        do {
            let url = URL(fileURLWithPath: "/")
            let values = try url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
            
            if let total = values.volumeTotalCapacity, let available = values.volumeAvailableCapacity {
                let used = Int64(total - available)
                
                DispatchQueue.main.async {
                    self.diskUsedBytes = used
                    self.diskFreeBytes = Int64(available)
                }
                
                return (Double(used) / Double(total)) * 100.0
            }
        } catch {
            print("Error getting disk usage: \(error)")
        }
        return 0.0
    }

    // MARK: - Helpers
    
    private func updateHistory(_ history: inout [Double], newValue: Double) {
        history.append(newValue)
        if history.count > 60 {
            history.removeFirst()
        }
    }

    static func getCPUModel() -> String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &model, &size, nil, 0)
        return String(cString: model)
    }
    
    static func getLocalIP() -> String {
        return Host.current().addresses.first(where: { $0.contains(".") && !$0.hasPrefix("127.") }) ?? "Unknown"
    }

    // MARK: - Network Usage
    private func getNetworkUsage() -> (inBytes: UInt64, outBytes: UInt64) {
        var ifaddr: TypeP?
        guard getifaddrs(&ifaddr) == 0 else { return (0, 0) }
        
        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
        
        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }
            
            guard let interface = ptr?.pointee else { continue }
            let name = String(cString: interface.ifa_name)
            
            // Filter loopback and focus on en0 (usually Wi-Fi) or en1/etc. 
            // Better to sum all non-loopback link-level interfaces.
            if name.hasPrefix("lo") || (Int(interface.ifa_flags) & Int(IFF_LOOPBACK)) != 0 {
                continue
            }
            
            if let addr = interface.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK) {
                if let data = interface.ifa_data {
                   let networkData = data.assumingMemoryBound(to: if_data.self).pointee
                   totalIn += UInt64(networkData.ifi_ibytes)
                   totalOut += UInt64(networkData.ifi_obytes)
                }
            }
        }
        
        freeifaddrs(ifaddr)
        return (totalIn, totalOut)
    }
}

// Helper typealias for getifaddrs
typealias TypeP = UnsafeMutablePointer<ifaddrs>
