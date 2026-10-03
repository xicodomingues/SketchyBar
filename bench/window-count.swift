// Count the WindowServer windows owned by a process name (default: sketchybar).
// usage: swift bench/window-count.swift [owner-name]
import CoreGraphics

let owner = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "sketchybar"
let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as! [[String: Any]]
print(list.filter { ($0[kCGWindowOwnerName as String] as? String) == owner }.count)
