import SwiftUI
import Combine

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    // V3.6 New Settings
    @AppStorage("isSingleIconMode") var isSingleIconMode: Bool = true
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = true // Default ON
    
    @AppStorage("showCPU") var showCPU: Bool = true
    @AppStorage("showRAM") var showRAM: Bool = true
    @AppStorage("showDisk") var showDisk: Bool = true
    @AppStorage("showNet") var showNet: Bool = true
    
    // Display Modes
    enum RAMDisplayMode: String, CaseIterable, Identifiable {
        case percent = "Percent"
        case used = "Used"
        case free = "Free"
        var id: String { self.rawValue }
    }
    
    enum DiskDisplayMode: String, CaseIterable, Identifiable {
        case percent = "Percent"
        case used = "Used"
        case free = "Free"
        var id: String { self.rawValue }
    }
    
    @AppStorage("ramDisplayMode") var ramDisplayMode: RAMDisplayMode = .percent
    @AppStorage("diskDisplayMode") var diskDisplayMode: DiskDisplayMode = .percent
    
    @AppStorage("rotationInterval") var rotationInterval: Double = 5.0
    @AppStorage("externalStorageAppPath") var externalStorageAppPath: String = "/Applications/GrandPerspective.app"
    @AppStorage("menuOrderString") var menuOrderString: String = "cpu,ram,disk,net"
    
    var menuOrder: [String] {
        get { menuOrderString.split(separator: ",").map { String($0) } }
        set { menuOrderString = newValue.joined(separator: ",") }
    }
}

// Extension to support KVO/Publisher observation
extension UserDefaults {
    @objc dynamic var menuOrderString: String {
        return string(forKey: "menuOrderString") ?? "cpu,ram,disk,net"
    }
    
    @objc dynamic var isSingleIconMode: Bool {
        return bool(forKey: "isSingleIconMode")
    }
    
    // We also need to observe show* flags if we want live updates for 'Separate' mode adding/removing items
    @objc dynamic var showCPU: Bool { return bool(forKey: "showCPU") }
    @objc dynamic var showRAM: Bool { return bool(forKey: "showRAM") }
    @objc dynamic var showDisk: Bool { return bool(forKey: "showDisk") }
    @objc dynamic var showNet: Bool { return bool(forKey: "showNet") }
    
    @objc dynamic var rotationInterval: Double {
        return double(forKey: "rotationInterval")
    }
}
