import SwiftUI

struct DetailedStatsView: View {
    @ObservedObject var monitor: SystemMonitor
    @ObservedObject var settings: SettingsManager
    @State private var showingSettings = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("Frictionless")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Button(action: { showingSettings.toggle() }) {
                    Image(systemName: "gearshape.fill")
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
            
            // Cards
            VStack(spacing: 8) {
                CompactCard(
                    icon: "cpu",
                    color: .blue,
                    title: "CPU",
                    value: String(format: "%.1f%%", monitor.cpuUsage),
                    subtext: "\(monitor.physicalCores) Cores",
                    progress: monitor.cpuUsage / 100.0
                ) {
                    WindowManager.shared.openWindow(for: .cpu, monitor: monitor, settings: settings)
                }
                
                CompactCard(
                    icon: "memorychip",
                    color: .green,
                    title: "RAM",
                    value: String(format: "%.1f%%", monitor.memoryUsage),
                    subtext: String(format: "%.1f GB Used", Double(ProcessInfo.processInfo.physicalMemory) * monitor.memoryUsage / 100.0 / 1_073_741_824.0),
                    progress: monitor.memoryUsage / 100.0
                ) {
                    WindowManager.shared.openWindow(for: .ram, monitor: monitor, settings: settings)
                }
                
                CompactCard(
                    icon: "internaldrive",
                    color: .orange,
                    title: "Disk",
                    value: String(format: "%.0f%%", monitor.diskUsage),
                    subtext: "Free: \(getFreeSpace())",
                    progress: monitor.diskUsage / 100.0
                ) {
                    WindowManager.shared.openWindow(for: .disk, monitor: monitor, settings: settings)
                }
                
                CompactCard(
                    icon: "network",
                    color: .purple,
                    title: "Net",
                    value: formatBytes(monitor.networkIn + monitor.networkOut) + "/s",
                    subtext: "↓\(formatBytes(monitor.networkIn)) ↑\(formatBytes(monitor.networkOut))",
                    progress: min((monitor.networkIn + monitor.networkOut) / 1_000_000.0, 1.0) // 1MB/s scale approx
                ) {
                    WindowManager.shared.openWindow(for: .network, monitor: monitor, settings: settings)
                }
            }
            .padding(.horizontal, 8)
            
            Divider()
            
            HStack {
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.system(size: 11))
                .keyboardShortcut("q")
                Spacer()
            }
            .padding(12)
        }
        .frame(width: 240) // Fixed width, tight.
        .frame(width: 240) // Fixed width
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

struct CompactCard: View {
    let icon: String
    let color: Color
    let title: String
    let value: String
    let subtext: String
    let progress: Double
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(color.opacity(0.3), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear, value: progress)
                    
                    Image(systemName: icon)
                        .font(.system(size: 10))
                        .foregroundColor(color)
                }
                .frame(width: 28, height: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(title)
                            .font(.system(size: 12, weight: .bold))
                        Spacer()
                        Text(value)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                    }
                    Text(subtext)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(8)
            .padding(8)
            .background(Color.gray.opacity(0.15)) // Subtle card background for OLED
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
