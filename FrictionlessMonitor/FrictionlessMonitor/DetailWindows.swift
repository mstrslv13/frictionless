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
    
    var body: some View {
        VStack(spacing: 0) { // Tight spacing
            DetailHeader(title: "CPU")
            
            Text("\(monitor.cpuModel) \(monitor.physicalCores) Cores")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding(.top, 10)
                .padding(.bottom, 4)
            
            Chart(Array(monitor.cpuHistory.enumerated()), id: \.offset) { index, value in
                LineMark(
                    x: .value("Time", index),
                    y: .value("Usage", value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Color.blue)
                .lineStyle(StrokeStyle(lineWidth: 1.5)) // Slightly thicker line
                
                AreaMark(
                     x: .value("Time", index),
                     y: .value("Usage", value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Color.blue.opacity(0.15)) // Better fill
            }
            .chartYScale(domain: 0...100)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 80) // Compact chart
            
            Text(String(format: "%.1f%%", monitor.cpuUsage))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .padding(.vertical, 8)
            
            Button("Manage Processes") {
                showProcesses.toggle()
            }
            .popover(isPresented: $showProcesses) {
                ProcessListView()
                    .frame(width: 300, height: 400)
                    .background(Color.black)
            }
            .padding(.bottom, 12)
        }
        .frame(width: 240, height: 250) // Width matched to 240, Height reduced
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
            
            VStack(spacing: 2) {
                Text(String(format: "%.1f GB", usedGB))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
                Text("/ \(String(format: "%.0f", totalGB)) GB")
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 10)
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
    
    var body: some View {
        VStack(spacing: 0) {
            DetailHeader(title: "Storage")
            
            ZStack {
                Circle()
                    .stroke(lineWidth: 12)
                    .opacity(0.2)
                    .foregroundColor(.orange)
                
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(monitor.diskUsage / 100.0, 1.0)))
                    .stroke(style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
                    .foregroundColor(.orange)
                    .rotationEffect(Angle(degrees: 270.0))
                    .animation(.linear, value: monitor.diskUsage)
                
                VStack {
                    Text(String(format: "%.0f%%", monitor.diskUsage))
                        .font(.title)
                        .fontWeight(.bold)
                }
            }
            .frame(width: 90, height: 90) // Slightly smaller
            .padding(.vertical, 10)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Free: " + getFreeSpace())
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                HStack {
                    Button("Clean Up") {
                        SystemActions.emptyTrash()
                        _ = SystemActions.clearTempFiles()
                    }
                    .help("Empty Trash & Clear Temp")
                    
                    Spacer()
                    
                    Button("Visualizer") {
                        SystemActions.openExternalApp(path: settings.externalStorageAppPath)
                    }
                }
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .frame(width: 240, height: 240) // Width matched to 240, Height reduced
        .oledStyle()
        .background(Color.black)
    }
    
    func getFreeSpace() -> String {
         guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
               let free = attrs[.systemFreeSize] as? Int64 else {
             return "?"
         }
         return formatBytes(Double(free))
    }
}

// MARK: - Network View
struct NetworkDetailView: View {
    @ObservedObject var monitor: SystemMonitor
    
    var body: some View {
        VStack(spacing: 0) {
            DetailHeader(title: "Network")
            
            Text(monitor.localIP)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.top, 4)
                .padding(.bottom, 8)
            
            Chart {
                ForEach(Array(monitor.networkInHistory.enumerated()), id: \.offset) { index, value in
                    LineMark(
                        x: .value("Time", index),
                        y: .value("Download", max(1.0, value)) // Clamp min 1.0
                    )
                    .foregroundStyle(.cyan)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                    
                    AreaMark(
                         x: .value("Time", index),
                         y: .value("Download", max(1.0, value)) // Clamp min 1.0
                    )
                    .foregroundStyle(.cyan.opacity(0.15))
                }
                
                ForEach(Array(monitor.networkOutHistory.enumerated()), id: \.offset) { index, value in
                    LineMark(
                        x: .value("Time", index),
                        y: .value("Upload", max(1.0, value)) // Clamp min 1.0
                    )
                    .foregroundStyle(.orange)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                    
                    AreaMark(
                         x: .value("Time", index),
                         y: .value("Upload", max(1.0, value)) // Clamp min 1.0
                    )
                    .foregroundStyle(.orange.opacity(0.1))
                }
            }
            // Log Scale, clamp min.
            .chartYScale(domain: 1...max(1024, (monitor.networkInHistory.max() ?? 0) * 1.5), type: .log)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 80) // Reduced height
            
            // Speeds
            HStack(spacing: 20) {
                VStack(spacing: 2) {
                    Text("Download")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(formatBytes(monitor.networkIn) + "/s")
                        .fontWeight(.semibold)
                        .foregroundColor(.cyan)
                }
                
                VStack(spacing: 2) {
                    Text("Upload")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(formatBytes(monitor.networkOut) + "/s")
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
            }
            .padding(.vertical, 10)
            
            Divider().background(Color.gray.opacity(0.3)).padding(.horizontal, 20)
            
            // Session Totals
            HStack(spacing: 20) {
                 VStack(spacing: 2) {
                     Text("Total In")
                         .font(.caption2)
                         .foregroundColor(.secondary)
                     Text(formatBytes(Double(monitor.sessionNetworkIn)))
                         .font(.caption)
                         .foregroundColor(.white)
                 }
                 
                 VStack(spacing: 2) {
                     Text("Total Out")
                         .font(.caption2)
                         .foregroundColor(.secondary)
                     Text(formatBytes(Double(monitor.sessionNetworkOut)))
                         .font(.caption)
                         .foregroundColor(.white)
                 }
            }
            .padding(.vertical, 10)
        }
        .frame(width: 240, height: 270) // Width matched to 240, Height reduced
        .oledStyle()
        .background(Color.black)
    }
}
