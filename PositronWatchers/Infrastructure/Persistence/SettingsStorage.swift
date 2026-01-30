import Foundation
import ServiceManagement

final class SettingsStorage: ObservableObject {
    private let patternsKey = "watchPatterns"
    private let launchAtLoginKey = "launchAtLogin"
    private let defaults = UserDefaults.standard

    @Published var patterns: [ProcessPattern] {
        didSet {
            savePatterns()
        }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            updateLaunchAtLogin()
        }
    }

    init() {
        // Load patterns
        if let data = defaults.data(forKey: patternsKey),
           let decoded = try? JSONDecoder().decode([ProcessPattern].self, from: data) {
            patterns = decoded
        } else {
            patterns = ProcessPattern.defaultPatterns
        }

        // Load launch at login preference
        launchAtLogin = defaults.bool(forKey: launchAtLoginKey)
    }

    private func savePatterns() {
        if let data = try? JSONEncoder().encode(patterns) {
            defaults.set(data, forKey: patternsKey)
        }
    }

    private func updateLaunchAtLogin() {
        defaults.set(launchAtLogin, forKey: launchAtLoginKey)
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Silently fail - user can try again
        }
    }

    func addPattern(_ pattern: String) {
        let newPattern = ProcessPattern(pattern: pattern)
        patterns.append(newPattern)
    }

    func removePattern(id: UUID) {
        patterns.removeAll { $0.id == id }
    }

    func updatePattern(id: UUID, pattern: String? = nil, isEnabled: Bool? = nil) {
        guard let index = patterns.firstIndex(where: { $0.id == id }) else { return }
        if let pattern = pattern {
            patterns[index].pattern = pattern
        }
        if let isEnabled = isEnabled {
            patterns[index].isEnabled = isEnabled
        }
    }

    func resetToDefaults() {
        patterns = ProcessPattern.defaultPatterns
    }
}
