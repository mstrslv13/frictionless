import SwiftUI

struct SettingsView: View {
    @AppStorage("externalStorageAppPath") var externalStorageAppPath: String = "/Applications/GrandPerspective.app"
    @AppStorage("menuOrderString") var menuOrderString: String = "cpu,ram,disk,net"
    @AppStorage("isSingleIconMode") var isSingleIconMode: Bool = false
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = true
    @AppStorage("rotationInterval") var rotationInterval: Double = 5.0
    
    @AppStorage("ramDisplayMode") var ramDisplayMode: SettingsManager.RAMDisplayMode = .percent
    @AppStorage("diskDisplayMode") var diskDisplayMode: SettingsManager.DiskDisplayMode = .percent
    
    // Toggles
    @AppStorage("showCPU") var showCPU: Bool = true
    @AppStorage("showRAM") var showRAM: Bool = true
    @AppStorage("showDisk") var showDisk: Bool = true
    @AppStorage("showNet") var showNet: Bool = true
    
    @State private var order: [String] = []
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                // Options Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Options")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Toggle("Single Icon Mode", isOn: $isSingleIconMode)
                        .toggleStyle(.switch)
                    
                    Toggle("Launch at Login", isOn: Binding(
                        get: { launchAtLogin },
                        set: { newValue in
                             launchAtLogin = newValue
                             SystemActions.setLaunchAtLogin(enabled: newValue)
                        }
                    ))
                    .toggleStyle(.switch)
                    
                    if isSingleIconMode {
                         VStack(alignment: .leading) {
                             Text("Update Interval: \(Int(rotationInterval))s")
                             Slider(value: $rotationInterval, in: 1...30, step: 1)
                         }
                    } else {
                          VStack(alignment: .leading) {
                             Text("Update Interval: \(Int(rotationInterval))s")
                             Slider(value: $rotationInterval, in: 1...30, step: 1)
                                 .disabled(true)
                                 .opacity(0.5)
                         }
                    }
                }
                
                Divider().background(Color.gray.opacity(0.3))
                
                // Resources Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Resources")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Toggle("CPU", isOn: $showCPU)
                    Toggle("Memory", isOn: $showRAM)
                    Toggle("Disk", isOn: $showDisk)
                    Toggle("Network", isOn: $showNet)
                    
                    if showRAM {
                        Picker("RAM Display", selection: $ramDisplayMode) {
                            ForEach(SettingsManager.RAMDisplayMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    if showDisk {
                        Picker("Disk Display", selection: $diskDisplayMode) {
                            ForEach(SettingsManager.DiskDisplayMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .toggleStyle(.switch)
                
                if !isSingleIconMode {
                    Divider().background(Color.gray.opacity(0.3))
                    
                    // Reorder Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Reorder")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        // Simple list for reorder
                        // Note: Standard List in ScrollView can be tricky. Using simple ForEach with drag might be complex.
                        // For now, simpler non-reorderable list or just List?
                        // "Reorder" was in the user screenshot. Let's keep it but maybe just render it simply.
                        // Standard List doesn't render well inside another ScrollView.
                        // We will use a VStack for display, but reordering might need a List or bespoke code.
                        // User's previous request implies they want it to work.
                        // Let's use a strict frame List to avoid infinite expansion.
                        List {
                            ForEach(order, id: \.self) { item in
                                HStack {
                                    Image(systemName: iconFor(item))
                                    Text(item.uppercased())
                                }
                                .listRowBackground(Color.black)
                            }
                            .onMove(perform: moveItem)
                        }
                        .frame(height: 120)
                        .scrollContentBackground(.hidden)
                        .background(Color.black)
                    }
                }
                
                Divider().background(Color.gray.opacity(0.3))
                
                // External Tools Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("External Tools")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    TextField("Storage App Path", text: $externalStorageAppPath)
                        .textFieldStyle(.roundedBorder)
                }
                
                Divider().background(Color.gray.opacity(0.3))
                
                // Footer
                Button("Quit App") {
                     NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
            .padding()
        }
        .frame(width: 400, height: 650)
        .background(Color.black)
        .onAppear {
            self.order = menuOrderString.split(separator: ",").map { String($0) }
            if self.order.isEmpty { self.order = ["cpu", "ram", "disk", "net"] }
        }
        .onChange(of: order) { newOrder in
            self.menuOrderString = newOrder.joined(separator: ",")
        }
    }
    
    func moveItem(from source: IndexSet, to destination: Int) {
        order.move(fromOffsets: source, toOffset: destination)
    }
    
    func iconFor(_ key: String) -> String {
        switch key {
        case "cpu": return "cpu"
        case "ram": return "memorychip"
        case "disk": return "internaldrive"
        case "net": return "network"
        default: return "questionmark"
        }
    }
}

struct ProcessListView: View {
    @State private var processes: [SystemActions.RunningApp] = []
    @State private var selection: Set<String> = []
    
    var body: some View {
        VStack {
            List(processes, selection: $selection) { app in
                HStack {
                    if let icon = app.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 16, height: 16)
                    }
                    Text(app.name)
                        .foregroundColor(.white)
                    Spacer()
                    Button("Kill") {
                        SystemActions.killApplication(pid: app.pid)
                        refresh()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
                .listRowBackground(Color.black)
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .onAppear(perform: refresh)
            
            Button("Refresh list") {
                refresh()
            }
            .padding(.bottom)
        }
        .background(Color.black)
    }
    
    func refresh() {
        processes = SystemActions.getRunningApplications()
    }
}
