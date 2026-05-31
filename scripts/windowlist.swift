import Foundation
import CoreGraphics

// 打印指定 pid 拥有的、有可见尺寸的窗口: windowID 宽 高 标题
let pid = Int32(CommandLine.arguments.count > 1 ? (Int(CommandLine.arguments[1]) ?? -1) : -1)
guard let infoList = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] else {
    exit(1)
}
for info in infoList {
    guard let owner = info[kCGWindowOwnerPID as String] as? Int32, owner == pid else { continue }
    let windowID = info[kCGWindowNumber as String] as? Int ?? -1
    let bounds = info[kCGWindowBounds as String] as? [String: Any] ?? [:]
    let width = bounds["Width"] as? Double ?? 0
    let height = bounds["Height"] as? Double ?? 0
    let title = info[kCGWindowName as String] as? String ?? ""
    let x = bounds["X"] as? Double ?? 0
    let y = bounds["Y"] as? Double ?? 0
    if width > 50 && height > 50 {
        print("\(windowID) \(Int(x)) \(Int(y)) \(Int(width)) \(Int(height)) \(title)")
    }
}
