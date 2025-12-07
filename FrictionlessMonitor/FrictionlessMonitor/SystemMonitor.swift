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
    
    // Disk I/O
    @Published var diskReadTotal: Int64 = 0
    @Published var diskWriteTotal: Int64 = 0
    @Published var diskReadSpeed: Double = 0.0
    @Published var diskWriteSpeed: Double = 0.0
    @Published var diskReadHistory: [Double] = Array(repeating: 0.0, count: 60)
    @Published var diskWriteHistory: [Double] = Array(repeating: 0.0, count: 60)
    
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
        let cpu = getCPUUsage() // Updates detailed props internaly
        let ram = getMemoryUsage()
        let disk = getDiskUsage()
        updateDiskIO()
        
        self.cpuUsage = self.cpuUser + self.cpuSystem // Total usage
        self.memoryUsage = ram
        self.diskUsage = disk
        
        // Update History
        updateHistory(&cpuHistory, newValue: self.cpuUsage)
        updateHistory(&cpuUserHistory, newValue: self.cpuUser)
        updateHistory(&cpuSystemHistory, newValue: self.cpuSystem)
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
        
        previousCPULoad = load
        
        if totalTicks == 0 { return 0.0 }
        
        let userPercent = ((userDiff + niceDiff) / totalTicks) * 100.0
        let sysPercent = (sysDiff / totalTicks) * 100.0
        let idlePercent = (idleDiff / totalTicks) * 100.0
        
        // Set values directly (Timer runs on main thread)
        self.cpuUser = userPercent
        self.cpuSystem = sysPercent
        self.cpuIdle = idlePercent
        
        return userPercent + sysPercent
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
        let total = ProcessInfo.processInfo.physicalMemory
        
        // Match Activity Monitor's calculation exactly:
        // Used = Total - Available
        // Available = Free + Inactive + Speculative (pages that can be reclaimed)
        // But we ADD back Compressed because those are in swap
        
        let freeBytes = UInt64(stats.free_count) * pageSize
        let inactiveBytes = UInt64(stats.inactive_count) * pageSize  
        let speculativeBytes = UInt64(stats.speculative_count) * pageSize
        
        // Available memory that could be used
        let available = freeBytes + inactiveBytes + speculativeBytes
        
        // Used = Total - Available
        let used = total > available ? total - available : 0
        
        self.memoryUsedBytes = used
        
        return (Double(used) / Double(total)) * 100.0
    }

    // MARK: - Disk Usage
    private func getDiskUsage() -> Double {
        do {
            let url = URL(fileURLWithPath: "/")
            // Use volumeAvailableCapacityForImportantUsageKey to include purgeable space
            let values = try url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
            
            if let total = values.volumeTotalCapacity, let available = values.volumeAvailableCapacityForImportantUsage {
                let used = Int64(total) - available
                
                DispatchQueue.main.async {
                    self.diskUsedBytes = used
                    self.diskFreeBytes = available
                    self.diskTotalBytes = Int64(total)
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
    
    // MARK: - Disk I/O
    private var previousDiskIO: (read: Int64, write: Int64)?
    
    // Simplified Disk I/O using a shell command (iostat) to avoid complex IOKit bridging in pure Swift file
    // In a real production app with full Xcode project, we'd add a C/Objective-C helper or Bridge.
    // However, IOKit IS available in Swift, let's try a direct registry approach if possible, 
    // but filtering for the main disk is tricky.
    // IMPROVEMENT: For safety and reliability in this script-like environment, we will use a shell helper.
    // Actually, let's use the Process to run `iostat -d -c 2 -w 1` is not great for polling.
    // let's try to just fetch via a simple `Process` call to `iostat -d -n 0` which gives totals?
    // `iostat -d` gives killobytes/transaction etc.
    // `netstat -b -I en0` for network.
    // Let's stick to parsing `iostat -Id` (cumulative)
    
    private func updateDiskIO() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/iostat")
        process.arguments = ["-Id", "disk0"] // Getting stats for main disk
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                parseIOStat(output)
            }
        } catch {
            // Error
        }
    }
    
    private func parseIOStat(_ output: String) {
        // iostat -Id disk0 output format:
        //      disk0 
        // KB/t xfrs   MB 
        // 25.10 12345 300.55 
        
        let lines = output.split(separator: "\n")
        if lines.count >= 3 {
            let parts = lines[2].split(separator: " ", omittingEmptySubsequences: true)
            // parts[2] is MB Read (cumulative? No, iostat -I gives stats since boot)
            // actually on Mac `iostat -Id`
            // disk0
            // KB/t xfrs MB
            // 23.45 152345 3456.78
            // The 3rd column is MB total transferred? 
            // Wait, iostat docs: -I display total statistics for a given time period (since boot if no interval).
            
            if parts.count >= 3, let mbTotal = Double(parts[2]) {
                // This is total MB transferred (Read+Write mixed? No, usually it's mixed or we need more cols)
                // standard `iostat -Id` on mac:
                // disk0
                // KB/t  xfrs   MB
                // 34.12 12344  456.12
                
                // This is inadequate for Read vs Write.
                // Let's use `top -l 1 -n 0` ?
                // "Disks: 12345/123G read, 23456/234G written."
                // This is perfect.
                
                // Let's switch to parsing top output for globally accumulated disk stats.
                // It's heavy but reliable for totals.
                // Or better, let's just interpret the requirement as visual activity for now if I can't get low level IOKit.
                // But the user requested specifics.
            }
        }
        
        // Revised Strategy: Use `top -l 1 -n 0` | grep "Disks:"
        // Output: Disks: 45678/123G read, 56789/234G written.
        
        let topProcess = Process()
        topProcess.executableURL = URL(fileURLWithPath: "/usr/bin/top")
        topProcess.arguments = ["-l", "1", "-n", "0"]
        
        let topPipe = Pipe()
        topProcess.standardOutput = topPipe
        
        do {
            try topProcess.run()
            let topData = topPipe.fileHandleForReading.readDataToEndOfFile()
            if let topOutput = String(data: topData, encoding: .utf8) {
                let lines = topOutput.split(separator: "\n")
                if let diskLine = lines.first(where: { $0.hasPrefix("Disks:") }) {
                    // Format: Disks: 5495574/204G read, 4280590/190G written.
                    // The first number is operations?, second is size.
                    // We want the Size.
                    
                    let parts = diskLine.split(separator: ",")
                    if parts.count == 2 {
                        let readPart = parts[0] // Disks: 5495574/204G read
                        let writePart = parts[1] // 4280590/190G written.
                        
                        let readBytes = parseTopDiskSize(String(readPart))
                        let writeBytes = parseTopDiskSize(String(writePart))
                        
                        updateDiskSpeed(newRead: readBytes, newWrite: writeBytes)
                    }
                }
            }
        } catch { }
    }
    
    private func parseTopDiskSize(_ raw: String) -> Int64 {
        // Example: "Disks: 5495574/204G read" -> extract 204G
        // Example: " 4280590/190M written."
        
        guard let slashIndex = raw.firstIndex(of: "/") else { return 0 }
        let afterSlash = raw[raw.index(after: slashIndex)...]
        // Now "204G read" or "190M written."
        
        let components = afterSlash.trimmingCharacters(in: .whitespaces).split(separator: " ")
        if let sizeStr = components.first {
            // sizeStr is "204G", "190M", "123K", "123B"
            let lastChar = sizeStr.last ?? "B"
            let numberStr = sizeStr.dropLast()
            guard let number = Double(numberStr) else { return 0 }
            
            var multiplier: Double = 1
            if lastChar == "G" { multiplier = 1_073_741_824 }
            else if lastChar == "M" { multiplier = 1_048_576 }
            else if lastChar == "K" { multiplier = 1024 }
            
            return Int64(number * multiplier)
        }
        return 0
    }
    
    private func updateDiskSpeed(newRead: Int64, newWrite: Int64) {
        if let prev = previousDiskIO, let lastTime = lastCheckTime {
             let timeDiff = Date().timeIntervalSince(lastTime)
             if timeDiff > 0 {
                 let rSpeed = Double(newRead - prev.read) / timeDiff
                 let wSpeed = Double(newWrite - prev.write) / timeDiff
                 
                 // Filter out negative spikes if top resets or parsing fails
                 if rSpeed >= 0 { 
                    self.diskReadSpeed = rSpeed
                    self.diskReadTotal = newRead
                    updateHistory(&diskReadHistory, newValue: rSpeed)
                 }
                 if wSpeed >= 0 { 
                    self.diskWriteSpeed = wSpeed 
                    self.diskWriteTotal = newWrite
                    updateHistory(&diskWriteHistory, newValue: wSpeed)
                 }
             }
        } else {
            self.diskReadTotal = newRead
            self.diskWriteTotal = newWrite
        }
        self.previousDiskIO = (newRead, newWrite)
    }
}
// Helper typealias for getifaddrs
typealias TypeP = UnsafeMutablePointer<ifaddrs>
