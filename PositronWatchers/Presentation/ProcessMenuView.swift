import AppKit

// Note: Menu building is handled directly in MenuBarController
// This file provides helper extensions for menu formatting

extension NSMenuItem {
    static func processItem(for process: WatchedProcess, target: AnyObject?, action: Selector?) -> NSMenuItem {
        let cpu = String(format: "%.1f%%", process.cpuPercent)
        let mem = String(format: "%.0fMB", process.memoryMB)
        let title = "\(process.displayName)  \(cpu)  \(mem)"

        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = target
        item.representedObject = process
        item.indentationLevel = 1

        return item
    }

    static func headerItem(title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false

        let font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
        item.attributedTitle = NSAttributedString(
            string: title,
            attributes: [.font: font, .foregroundColor: NSColor.secondaryLabelColor]
        )

        return item
    }

    static func killGroupItem(target: AnyObject?, action: Selector?) -> NSMenuItem {
        let title = "Kill All in Folder"
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = target
        item.indentationLevel = 1

        let font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .medium)
        item.attributedTitle = NSAttributedString(
            string: title,
            attributes: [.font: font, .foregroundColor: NSColor.systemRed]
        )

        return item
    }

    static func warningHeaderItem(title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false

        let font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
        item.attributedTitle = NSAttributedString(
            string: title,
            attributes: [.font: font, .foregroundColor: NSColor.systemOrange]
        )

        return item
    }
}
