import SwiftUI
import Charts

// Common modifier for OLED theme - STRICT BLACK
struct OLEDTheme: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            content
        }
        .preferredColorScheme(.dark)
    }
}

extension View {
    func oledStyle() -> some View {
        self.modifier(OLEDTheme())
    }
}

// Global Header for Details
struct DetailHeader: View {
    let title: String
    @ObservedObject var settings = SettingsManager.shared
    @State private var showingSettings = false
    
    // Quick access to about
    // @State private var showingAbout = false // No longer used, using WindowManager
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            
            // About Icon
            Button(action: { WindowManager.shared.showAboutWindow() }) {
                Image(systemName: "info.circle")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)

            // Settings Icon (Outline)
            Button(action: { showingSettings.toggle() }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingSettings) {
                SettingsView()
                    .frame(width: 400, height: 650) // Expanded +300
                    .background(Color.black)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
    }
}

// MARK: - CPU View
struct CPUDetailView: View {
    @ObservedObject var monitor: SystemMonitor
    @State private var showProcesses = false
    
    // Data structure for proper stacking
    struct CPUData: Identifiable {
        let id = UUID()
        let index: Int
        let value: Double
        let type: String
    }
    
    var chartData: [CPUData] {
        var data: [CPUData] = []
        
        // System (bottom layer)
        for (index, value) in monitor.cpuSystemHistory.enumerated() {
            data.append(CPUData(index: index, value: value, type: "System"))
        }
        
        // User (top layer)
        for (index, value) in monitor.cpuUserHistory.enumerated() {
            data.append(CPUData(index: index, value: value, type: "User"))
        }
        
        return data
    }
    
    var body: some View {
        VStack(spacing: 8) {
            DetailHeader(title: "Processor")
            
            // Title above chart
            Text("CPU Load")
                .font(.system(size: 14, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
            
            // Chart with OLED black background
            Chart(chartData) { item in
                AreaMark(
                    x: .value("Time", item.index),
                    y: .value("Usage", item.value)
                )
                .foregroundStyle(by: .value("Type", item.type))
                .interpolationMethod(.monotone)
            }
            .chartForegroundStyleScale([
                "System": .red,
                "User": .blue
            ])
            .chartYScale(domain: 0...100)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .frame(height: 80)
            .background(Color.black)
            .cornerRadius(4)
            .padding(.horizontal, 12)
            
            // Legend below chart
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Circle().fill(Color.red).frame(width: 8, height: 8)
                    Text("System:")
                        .font(.system(size: 11))
                    Spacer()
                    Text(String(format: "%.1f%%", monitor.cpuSystem))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.red)
                }
                HStack {
                    Circle().fill(Color.blue).frame(width: 8, height: 8)
                    Text("User:")
                        .font(.system(size: 11))
                    Spacer()
                    Text(String(format: "%.1f%%", monitor.cpuUser))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.blue)
                }
                HStack {
                    Circle().fill(Color.gray).frame(width: 8, height: 8)
                    Text("Idle:")
                        .font(.system(size: 11))
                    Spacer()
                    Text(String(format: "%.1f%%", monitor.cpuIdle))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 12)
            
            Spacer()
            
            Button("Processes") {
                showProcesses.toggle()
            }
            .controlSize(.small)
            .popover(isPresented: $showProcesses) {
                ProcessListView()
                    .frame(width: 300, height: 400)
                    .background(Color.black)
            }
            .padding(.bottom, 12)
        }
        .frame(width: 240, height: 240)
        .oledStyle()
        .background(Color.black)
    }
}

// MARK: - RAM View
struct RAMDetailView: View {
    @ObservedObject var monitor: SystemMonitor
    
    var body: some View {
        VStack(spacing: 0) {
            DetailHeader(title: "Memory")
            
            let totalGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824.0
            let usedGB = totalGB * (monitor.memoryUsage / 100.0)
            
            Chart(Array(monitor.ramHistory.enumerated()), id: \.offset) { index, value in
                LineMark(
                    x: .value("Time", index),
                    y: .value("Usage", value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Color.green)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                
                AreaMark(
                     x: .value("Time", index),
                     y: .value("Usage", value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Color.green.opacity(0.15))
            }
            .chartYScale(domain: 0...100)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 80)
            .padding(.top, 10)
            
            VStack(spacing: 4) {
                Text(String(format: "%.1f GB Used", usedGB))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
                
                HStack(spacing: 4) {
                     Text("of \(String(format: "%.0f", totalGB)) GB Total")
                         .foregroundColor(.secondary)
                     Text("•")
                         .foregroundColor(.gray.opacity(0.5))
                     Text(String(format: "%.1f GB Free", totalGB - usedGB))
                         .foregroundColor(.secondary)
                }
                .font(.caption)
            }
            .padding(.vertical, 6)
        }
        .frame(width: 240, height: 220) // Width matched to 240, Height reduced
        .oledStyle()
        .background(Color.black)
    }
}

// MARK: - Storage View
struct DiskDetailView: View {
    @ObservedObject var monitor: SystemMonitor
    @ObservedObject var settings: SettingsManager
    
    // Calculate free percentage for color thresholds
    var freePercentage: Double {
        guard monitor.diskTotalBytes > 0 else { return 0 }
        return (Double(monitor.diskFreeBytes) / Double(monitor.diskTotalBytes)) * 100.0
    }
    
    var thresholdColor: Color {
        if freePercentage <= 10.0 {
            return .red
        } else if freePercentage <= 25.0 {
            return .yellow
        } else {
            return .green
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            DetailHeader(title: "Storage")
            
            ZStack {
                Circle()
                    .stroke(lineWidth: 12)
                    .opacity(0.2)
                    .foregroundColor(thresholdColor)
                
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(monitor.diskUsage / 100.0, 1.0)))
                    .stroke(style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
                    .foregroundColor(thresholdColor)
                    .rotationEffect(Angle(degrees: 270.0))
                    .animation(.linear, value: monitor.diskUsage)
                
                VStack {
                    Text(String(format: "%.0f%%", monitor.diskUsage))
                        .font(.title)
                        .fontWeight(.bold)
                }
            }
            .frame(width: 90, height: 90)
            .padding(.vertical, 10)
            
            VStack(spacing: 4) {
                // Prominent: Free space in threshold color
                Text("\(formatBytes(Double(monitor.diskFreeBytes))) free")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(thresholdColor)
                
                // Below: Used / Total
                Text("\(formatBytes(Double(monitor.diskUsedBytes))) used / \(formatBytes(Double(monitor.diskTotalBytes))) total")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            
            Spacer()
            
            // Optional: Visualizer button only (Clean Up removed)
            Button("Visualizer") {
                SystemActions.openExternalApp(path: settings.externalStorageAppPath)
            }
            .controlSize(.small)
            .padding(.bottom, 12)
        }
        .frame(width: 240, height: 240)
        .oledStyle()
        .background(Color.black)
    }
}

// MARK: - Network View
struct NetworkDetailView: View {
    @ObservedObject var monitor: SystemMonitor
    
    // Data structure for proper stacking (same pattern as CPU)
    struct NetworkData: Identifiable {
        let id = UUID()
        let index: Int
        let value: Double
        let type: String
    }
    
    var chartData: [NetworkData] {
        var data: [NetworkData] = []
        
        // Download (bottom layer)
        for (index, value) in monitor.networkInHistory.enumerated() {
            data.append(NetworkData(index: index, value: value, type: "Download"))
        }
        
        // Upload (top layer)
        for (index, value) in monitor.networkOutHistory.enumerated() {
            data.append(NetworkData(index: index, value: value, type: "Upload"))
        }
        
        return data
    }
    
    var body: some View {
        VStack(spacing: 8) {
            DetailHeader(title: "Network")
            
            Text(monitor.localIP)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
            
            // Network Chart
            Chart(chartData) { item in
                AreaMark(
                    x: .value("Time", item.index),
                    y: .value("Speed", item.value)
                )
                .foregroundStyle(by: .value("Type", item.type))
                .interpolationMethod(.monotone)
            }
            .chartForegroundStyleScale([
                "Download": .purple,
                "Upload": .orange
            ])
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .frame(height: 80)
            .background(Color.black)
            .cornerRadius(4)
            .padding(.horizontal, 12)
            
            // Legend with speeds
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Circle().fill(Color.purple).frame(width: 8, height: 8)
                    Text("Download:")
                        .font(.system(size: 11))
                    Spacer()
                    Text(formatBytes(monitor.networkIn) + "/s")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.purple)
                }
                HStack {
                    Circle().fill(Color.orange).frame(width: 8, height: 8)
                    Text("Upload:")
                        .font(.system(size: 11))
                    Spacer()
                    Text(formatBytes(monitor.networkOut) + "/s")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 12)
            
            Divider().background(Color.gray.opacity(0.3)).padding(.horizontal, 20)
            
            // Session Totals
            HStack(spacing: 24) {
                 VStack(spacing: 4) {
                     Text("Total In")
                         .font(.caption)
                         .foregroundColor(.secondary)
                     Text(formatBytes(Double(monitor.sessionNetworkIn)))
                         .font(.system(size: 14, weight: .medium))
                         .foregroundColor(.white)
                 }
                 
                 VStack(spacing: 4) {
                     Text("Total Out")
                         .font(.caption)
                         .foregroundColor(.secondary)
                     Text(formatBytes(Double(monitor.sessionNetworkOut)))
                         .font(.system(size: 14, weight: .medium))
                         .foregroundColor(.white)
                 }
            }
            
            Spacer()
        }
        .frame(width: 240, height: 240)
        .oledStyle()
        .background(Color.black)
    }
}
