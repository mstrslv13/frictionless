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
        .padding(.horizontal)
        .padding(.top, 10)
    }
}

// MARK: - CPU View
struct CPUDetailView: View {
    @ObservedObject var monitor: SystemMonitor
    @State private var showProcesses = false
    
    var body: some View {
        VStack(spacing: 8) {
            DetailHeader(title: "CPU")
            
            Spacer(minLength: 0)
            
            Text("\(monitor.cpuModel) \(monitor.physicalCores) Cores")
                .font(.subheadline)
                .multilineTextAlignment(.center)
            
            Chart(Array(monitor.cpuHistory.enumerated()), id: \.offset) { index, value in
                LineMark(
                    x: .value("Time", index),
                    y: .value("Usage", value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Color.blue)
                .lineStyle(StrokeStyle(lineWidth: 1))
                
                AreaMark(
                     x: .value("Time", index),
                     y: .value("Usage", value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Color.blue.opacity(0.1))
            }
            .chartYScale(domain: 0...100)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 100)
            // Removed horizontal padding for edge-to-edge
            
            Text(String(format: "%.1f%%", monitor.cpuUsage))
                .font(.system(size: 28, weight: .bold, design: .rounded))
            
            Spacer(minLength: 0)
            
            Button("Manage Processes") {
                showProcesses.toggle()
            }
            .popover(isPresented: $showProcesses) {
                ProcessListView()
                    .frame(width: 300, height: 400)
                    .background(Color.black)
            }
            .padding(.bottom, 10)
        }
        .frame(width: 226, height: 360) // Expanded +80
        .oledStyle()
        .background(Color.black) // Ensure root black
    }
}

// MARK: - RAM View
struct RAMDetailView: View {
    @ObservedObject var monitor: SystemMonitor
    
    var body: some View {
        VStack(spacing: 4) {
            DetailHeader(title: "Memory")
            
            Spacer(minLength: 0)
            
            let totalGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824.0
            let usedGB = totalGB * (monitor.memoryUsage / 100.0)
            
            Chart(Array(monitor.ramHistory.enumerated()), id: \.offset) { index, value in
                LineMark(
                    x: .value("Time", index),
                    y: .value("Usage", value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Color.green)
                .lineStyle(StrokeStyle(lineWidth: 1))
                
                AreaMark(
                     x: .value("Time", index),
                     y: .value("Usage", value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Color.green.opacity(0.1))
            }
            .chartYScale(domain: 0...100)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 90)
            // Removed horizontal padding
            
            VStack(spacing: 0) {
                Text(String(format: "%.1f GB", usedGB))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
                Text("/ \(String(format: "%.0f", totalGB)) GB")
                    .foregroundColor(.secondary)
            }
            
            Spacer(minLength: 0)
        }
        .frame(width: 226, height: 310) // Expanded +80 from 230 -> 310
        .oledStyle()
        .background(Color.black)
    }
}

// MARK: - Storage View
struct DiskDetailView: View {
    @ObservedObject var monitor: SystemMonitor
    @ObservedObject var settings: SettingsManager
    
    var body: some View {
        VStack(spacing: 8) {
            DetailHeader(title: "Storage")
            
            Spacer(minLength: 0)
            
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
            .frame(width: 100, height: 100)
            .padding()
            
            VStack(alignment: .leading, spacing: 10) {
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
            
            Spacer(minLength: 0)
            Spacer(minLength: 0)
        }
        .frame(width: 226, height: 360) // Expanded +80
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
        VStack(spacing: 6) {
            DetailHeader(title: "Network")
            
            Spacer(minLength: 0)
            
            Text(monitor.localIP)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
            
            Chart {
                ForEach(Array(monitor.networkInHistory.enumerated()), id: \.offset) { index, value in
                    LineMark(
                        x: .value("Time", index),
                        y: .value("Download", value)
                    )
                    .foregroundStyle(.purple)
                    .lineStyle(StrokeStyle(lineWidth: 1))
                }
                
                ForEach(Array(monitor.networkOutHistory.enumerated()), id: \.offset) { index, value in
                    LineMark(
                        x: .value("Time", index),
                        y: .value("Upload", value)
                    )
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                }
            }
            // Log Scale for Network: Clamp min 1 to avoid log(0) error
            .chartYScale(domain: 1...max(1024, (monitor.networkInHistory.max() ?? 0) * 1.5), type: .log)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 90)
            // Removed horizontal padding
            
            // Speeds
            HStack(spacing: 20) {
                VStack(spacing: 2) {
                    Text("Download")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(formatBytes(monitor.networkIn) + "/s")
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                }
                
                VStack(spacing: 2) {
                    Text("Upload")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(formatBytes(monitor.networkOut) + "/s")
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }
            
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
            
            Spacer(minLength: 0)
        }
        .frame(width: 226, height: 380) // Expanded +80 from 300 -> 380
        .oledStyle()
        .background(Color.black)
    }
}
