import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private let services = ServiceContainer.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController(services: services)
        services.processMonitor.startMonitoring()
    }

    func applicationWillTerminate(_ notification: Notification) {
        services.processMonitor.stopMonitoring()
    }
}
