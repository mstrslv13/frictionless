import Foundation

func formatBytes(_ bytes: Double) -> String {
    if bytes < 1.0 { return "0 B" }
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
    formatter.countStyle = .file
    formatter.includesUnit = true
    return formatter.string(fromByteCount: Int64(bytes))
}
