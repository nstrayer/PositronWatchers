import Foundation

struct ProcessPattern: Identifiable, Codable, Hashable {
    let id: UUID
    var pattern: String
    var isEnabled: Bool

    init(id: UUID = UUID(), pattern: String, isEnabled: Bool = true) {
        self.id = id
        self.pattern = pattern
        self.isEnabled = isEnabled
    }

    static let defaultPatterns: [ProcessPattern] = [
        ProcessPattern(pattern: "*gulp*watch-client*"),
        ProcessPattern(pattern: "*gulp*watch-extensions*")
    ]
}
