import Foundation
import Combine
import Darwin

class SystemMonitor: ObservableObject {
    @Published var cpuUsage: Double = 0.0
    @Published var memoryUsage: Double = 0.0
    @Published var diskUsage: Double = 0.0
    @Published var networkIn: Double = 0.0 // Bytes per second
    @Published var networkOut: Double = 0.0 // Bytes per second
    
    // CPU Detail
    @Published var cpuUser: Double = 0.0
    @Published var cpuSystem: Double = 0.0
    @Published var cpuIdle: Double = 0.0
    

    
    // Raw Values for Display Modes
    @Published var memoryUsedBytes: UInt64 = 0
    @Published var diskUsedBytes: Int64 = 0
    @Published var diskFreeBytes: Int64 = 0
    @Published var diskTotalBytes: Int64 = 0
    
    // Advanced Stats
    @Published var physicalCores: Int = 0
    @Published var logicalCores: Int = 0
    @Published var cpuModel: String = "Unknown"
    
    @Published var sessionNetworkIn: UInt64 = 0
    @Published var sessionNetworkOut: UInt64 = 0
    
    @Published var localIP: String = "Checking..."
    
    // History for Charts (last 60 points)
    @Published var cpuHistory: [Double] = Array(repeating: 0.0, count: 60)
    @Published var cpuUserHistory: [Double] = Array(repeating: 0.0, count: 60)
    @Published var cpuSystemHistory: [Double] = Array(repeating: 0.0, count: 60)
    @Published var ramHistory: [Double] = Array(repeating: 0.0, count: 60)
    @Published var networkInHistory: [Double] = Array(repeating: 0.0, count: 60)
    @Published var networkOutHistory: [Double] = Array(repeating: 0.0, count: 60)
    
    private var timer: Timer?
    private let monitorQueue = DispatchQueue(label: "com.mstrslv.frictionless.monitor", qos: .userInitiated)
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
        // Timer fires on Main, but we offload work to background queue immediately
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.monitorQueue.async {
                self.updateStats()
            }
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func updateStats() {
        // BACKGROUND THREAD: Perform heavy system calls here
        let cpuDetails = getCPUUsage() // Returns (user, system, idle)
        let ramDetails = getMemoryUsage() // Returns (usagePercent, usedBytes)
        let diskDetails = getDiskUsage() // Returns (usagePercent, usedBytes, freeBytes, totalBytes)
        
        let currentNetwork = getNetworkUsage()
        var netIn: Double = 0
        var netOut: Double = 0
        
        // Network Logic
        if let prev = previousNetworkStats, let lastTime = lastCheckTime {
            let timeDiff = Date().timeIntervalSince(lastTime)
            if timeDiff > 0 {
                // Prevent UInt64 underflow crash if interfaces reset (current < prev)
                // This happens if Wi-Fi toggles or adapters change.
                let inBytesDiff = currentNetwork.inBytes >= prev.inBytes ? currentNetwork.inBytes - prev.inBytes : 0
                let outBytesDiff = currentNetwork.outBytes >= prev.outBytes ? currentNetwork.outBytes - prev.outBytes : 0
                
                netIn = Double(inBytesDiff) / timeDiff
                netOut = Double(outBytesDiff) / timeDiff
            }
        }
        
        // Update session totals logic (simplified for background calc)
        var sessIn: UInt64 = 0
        var sessOut: UInt64 = 0
        let isInitialNetworkStatsSet = initialNetworkStats == nil
        
        if let initial = initialNetworkStats {
             sessIn = currentNetwork.inBytes >= initial.inBytes ? currentNetwork.inBytes - initial.inBytes : 0
             sessOut = currentNetwork.outBytes >= initial.outBytes ? currentNetwork.outBytes - initial.outBytes : 0
        }

        // Capture values to capture in closure
        let finalNetworkIn = netIn
        let finalNetworkOut = netOut
        let finalSessIn = sessIn
        let finalSessOut = sessOut
        let finalCurrentNetwork = currentNetwork
        
        // UI UPDATES: Dispatch back to Main
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.cpuUser = cpuDetails.user
            self.cpuSystem = cpuDetails.system
            self.cpuIdle = cpuDetails.idle
            self.cpuUsage = cpuDetails.user + cpuDetails.system
            
            self.memoryUsage = ramDetails.usagePercent
            self.memoryUsedBytes = ramDetails.usedBytes
            
            self.diskUsage = diskDetails.usagePercent
            self.diskUsedBytes = diskDetails.usedBytes
            self.diskFreeBytes = diskDetails.freeBytes
            self.diskTotalBytes = diskDetails.totalBytes
            
            self.networkIn = finalNetworkIn
            self.networkOut = finalNetworkOut
            
            // History
            self.updateHistory(&self.cpuHistory, newValue: self.cpuUsage)
            self.updateHistory(&self.cpuUserHistory, newValue: self.cpuUser)
            self.updateHistory(&self.cpuSystemHistory, newValue: self.cpuSystem)
            self.updateHistory(&self.ramHistory, newValue: ramDetails.usagePercent)
            self.updateHistory(&self.networkInHistory, newValue: finalNetworkIn)
            self.updateHistory(&self.networkOutHistory, newValue: finalNetworkOut)
            
            // Session
             if isInitialNetworkStatsSet {
                self.initialNetworkStats = finalCurrentNetwork
            } else {
                self.sessionNetworkIn = finalSessIn
                self.sessionNetworkOut = finalSessOut
            }
        }
        
        // Update internal state on background queue (Serial)
        self.previousNetworkStats = currentNetwork
        self.lastCheckTime = Date()
    }

    // MARK: - CPU Usage
    private func getCPUUsage() -> (user: Double, system: Double, idle: Double) {
        var cpuLoad = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &cpuLoad) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return (0, 0, 0) }
        return calculateCPUPercentage(load: cpuLoad)
    }
    
    private var previousCPULoad: host_cpu_load_info?
    
    // Returns (User, System, Idle) percentages
    private func calculateCPUPercentage(load: host_cpu_load_info) -> (user: Double, system: Double, idle: Double) {
        guard let prev = previousCPULoad else {
            previousCPULoad = load
            return (0, 0, 0)
        }
        
        let userDiff = Double(load.cpu_ticks.0 - prev.cpu_ticks.0)
        let sysDiff = Double(load.cpu_ticks.1 - prev.cpu_ticks.1)
        let idleDiff = Double(load.cpu_ticks.2 - prev.cpu_ticks.2)
        let niceDiff = Double(load.cpu_ticks.3 - prev.cpu_ticks.3)
        
        let totalTicks = userDiff + sysDiff + idleDiff + niceDiff
        
        previousCPULoad = load
        
        if totalTicks == 0 { return (0, 0, 0) }
        
        let userPercent = ((userDiff + niceDiff) / totalTicks) * 100.0
        let sysPercent = (sysDiff / totalTicks) * 100.0
        let idlePercent = (idleDiff / totalTicks) * 100.0
        
        return (userPercent, sysPercent, idlePercent)
    }

    // MARK: - Memory Usage
    private func getMemoryUsage() -> (usagePercent: Double, usedBytes: UInt64) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return (0, 0) }
        
        let pageSize = UInt64(vm_kernel_page_size)
        let total = ProcessInfo.processInfo.physicalMemory
        
        let freeBytes = UInt64(stats.free_count) * pageSize
        let inactiveBytes = UInt64(stats.inactive_count) * pageSize  
        let speculativeBytes = UInt64(stats.speculative_count) * pageSize
        
        // Available memory that could be used
        let available = freeBytes + inactiveBytes + speculativeBytes
        
        // Used = Total - Available
        let used = total > available ? total - available : 0
        
        let percent = (Double(used) / Double(total)) * 100.0
        
        return (percent, used)
    }

    // MARK: - Disk Usage
    private func getDiskUsage() -> (usagePercent: Double, usedBytes: Int64, freeBytes: Int64, totalBytes: Int64) {
        do {
            let url = URL(fileURLWithPath: "/")
            let values = try url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
            
            if let total = values.volumeTotalCapacity, let available = values.volumeAvailableCapacityForImportantUsage {
                let used = Int64(total) - available
                let percent = (Double(used) / Double(total)) * 100.0
                
                return (percent, used, Int64(available), Int64(total))
            }
        } catch {
            print("Error getting disk usage: \(error)")
        }
        return (0, 0, 0, 0)
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
        return Host.current().addresses.first(where: { 
            $0.contains(".") && 
            !$0.hasPrefix("127.") && 
            !$0.hasPrefix("169.254") 
        }) ?? "No Connection"
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
    
    // MARK: - Disk I/O (Removed: Sandbox Limitation)
    // Disk Speed monitoring via `top` or `iostat` is not allowed in Mac App Store (Sandbox).
    // We strictly monitor Storage Space (Free/Used) via URLResourceValues which is compliant.
}
// Helper typealias for getifaddrs
typealias TypeP = UnsafeMutablePointer<ifaddrs>
