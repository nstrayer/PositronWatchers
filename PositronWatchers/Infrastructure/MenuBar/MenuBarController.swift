import AppKit
import Combine
import SwiftUI

final class MenuBarController {
    private var statusItem: NSStatusItem
    private let services: ServiceContainer
    private var cancellables = Set<AnyCancellable>()
    private var preferencesWindow: NSWindow?

    init(services: ServiceContainer) {
        self.services = services

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        setupStatusItem()
        setupBindings()
    }

    private func setupStatusItem() {
        if let button = statusItem.button {
            button.image = NSImage(named: "MenuBarIcon")
            button.imagePosition = .imageLeading
            updateBadge(count: 0, hasCrashes: false)
        }

        statusItem.menu = buildMenu()
    }

    private func setupBindings() {
        services.processMonitor.$projectPairCount
            .combineLatest(services.processMonitor.$hasCrashes)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count, hasCrashes in
                self?.updateBadge(count: count, hasCrashes: hasCrashes)
                self?.statusItem.menu = self?.buildMenu()
            }
            .store(in: &cancellables)
    }

    private func updateBadge(count: Int, hasCrashes: Bool) {
        guard let button = statusItem.button else { return }

        var title = ""
        if count > 0 {
            title = "\(count)"
        }
        if hasCrashes {
            title += " ⚠"
        }

        button.title = title
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let groups = services.processMonitor.processGroups
        let missingProcesses = services.processMonitor.missingProcesses

        if groups.isEmpty && missingProcesses.isEmpty {
            let emptyItem = NSMenuItem(title: "No matching processes", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            // Add process groups
            for (index, group) in groups.enumerated() {
                if index > 0 {
                    menu.addItem(NSMenuItem.separator())
                }

                // Working directory header
                menu.addItem(.headerItem(title: group.shortWorkingDirectory))

                // Process items
                for process in group.processes {
                    menu.addItem(.processItem(for: process, target: self, action: #selector(processItemClicked(_:))))
                }
            }

            // Missing processes section
            if !missingProcesses.isEmpty {
                menu.addItem(NSMenuItem.separator())

                menu.addItem(.warningHeaderItem(title: "⚠ Missing Processes"))

                for missing in missingProcesses {
                    let title = "  \(missing.name) (was: \(missing.pid))"
                    let item = NSMenuItem(title: title, action: #selector(missingProcessClicked(_:)), keyEquivalent: "")
                    item.target = self
                    item.representedObject = missing
                    menu.addItem(item)
                }

                let acknowledgeItem = NSMenuItem(title: "Acknowledge All", action: #selector(acknowledgeAllClicked), keyEquivalent: "")
                acknowledgeItem.target = self
                acknowledgeItem.indentationLevel = 1
                menu.addItem(acknowledgeItem)
            }
        }

        menu.addItem(NSMenuItem.separator())

        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(preferencesClicked), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        let quitItem = NSMenuItem(title: "Quit Process Watcher", action: #selector(quitClicked), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc private func processItemClicked(_ sender: NSMenuItem) {
        guard let process = sender.representedObject as? WatchedProcess else { return }
        let killCommand = "kill \(process.pid)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(killCommand, forType: .string)
    }

    @objc private func missingProcessClicked(_ sender: NSMenuItem) {
        guard let missing = sender.representedObject as? MissingProcess else { return }
        services.processMonitor.acknowledgeCrash(pid: missing.pid)
    }

    @objc private func acknowledgeAllClicked() {
        services.processMonitor.acknowledgeAllCrashes()
    }

    @objc private func preferencesClicked() {
        if preferencesWindow == nil {
            let preferencesView = PreferencesView(settings: services.settingsStorage)
            let hostingController = NSHostingController(rootView: preferencesView)

            let window = NSWindow(contentViewController: hostingController)
            window.title = "Process Watcher Preferences"
            window.styleMask = [.titled, .closable]
            window.setContentSize(NSSize(width: 450, height: 350))
            window.center()

            preferencesWindow = window
        }

        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitClicked() {
        NSApp.terminate(nil)
    }
}
