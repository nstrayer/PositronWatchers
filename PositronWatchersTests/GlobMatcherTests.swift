import XCTest
@testable import PositronWatchers

final class GlobMatcherTests: XCTestCase {
    var matcher: GlobMatcher!

    override func setUp() {
        super.setUp()
        matcher = GlobMatcher()
    }

    override func tearDown() {
        matcher = nil
        super.tearDown()
    }

    // MARK: - Basic Glob Patterns

    func testSimpleWildcard() {
        XCTAssertTrue(matcher.matches("hello world", pattern: "*world"))
        XCTAssertTrue(matcher.matches("hello world", pattern: "hello*"))
        XCTAssertTrue(matcher.matches("hello world", pattern: "*llo*wor*"))
    }

    func testNoWildcard() {
        XCTAssertTrue(matcher.matches("exact match", pattern: "exact match"))
        XCTAssertFalse(matcher.matches("exact match", pattern: "not exact"))
    }

    func testFullWildcard() {
        XCTAssertTrue(matcher.matches("anything", pattern: "*"))
        XCTAssertTrue(matcher.matches("", pattern: "*"))
    }

    func testSingleCharWildcard() {
        XCTAssertTrue(matcher.matches("cat", pattern: "c?t"))
        XCTAssertTrue(matcher.matches("cut", pattern: "c?t"))
        XCTAssertFalse(matcher.matches("ct", pattern: "c?t"))
    }

    // MARK: - Gulp Watch Patterns (From PRD)

    func testGulpWatchClientPattern() {
        let pattern = "*gulp*watch-client*"

        XCTAssertTrue(matcher.matches("/usr/bin/node gulp watch-client", pattern: pattern))
        XCTAssertTrue(matcher.matches("node /path/to/gulp watch-client --debug", pattern: pattern))
        XCTAssertTrue(matcher.matches("gulp watch-client", pattern: pattern))
        XCTAssertFalse(matcher.matches("gulp watch-server", pattern: pattern))
        XCTAssertFalse(matcher.matches("npm run build", pattern: pattern))
    }

    func testGulpWatchExtensionsPattern() {
        let pattern = "*gulp*watch-extensions*"

        XCTAssertTrue(matcher.matches("/usr/bin/node gulp watch-extensions", pattern: pattern))
        XCTAssertTrue(matcher.matches("gulp watch-extensions --verbose", pattern: pattern))
        XCTAssertFalse(matcher.matches("gulp watch-client", pattern: pattern))
    }

    // MARK: - Case Insensitivity

    func testCaseInsensitive() {
        XCTAssertTrue(matcher.matches("GULP watch-CLIENT", pattern: "*gulp*watch-client*"))
        XCTAssertTrue(matcher.matches("Gulp Watch-Client", pattern: "*gulp*watch-client*"))
    }

    // MARK: - Special Characters

    func testEscapedSpecialChars() {
        XCTAssertTrue(matcher.matches("file.txt", pattern: "*.txt"))
        XCTAssertTrue(matcher.matches("test+plus", pattern: "*+plus"))
        XCTAssertTrue(matcher.matches("test$dollar", pattern: "*dollar"))
    }

    // MARK: - matchesAny

    func testMatchesAnyEnabled() {
        let patterns = [
            ProcessPattern(pattern: "*foo*", isEnabled: true),
            ProcessPattern(pattern: "*bar*", isEnabled: true)
        ]

        XCTAssertTrue(matcher.matchesAny("hello foo world", patterns: patterns))
        XCTAssertTrue(matcher.matchesAny("hello bar world", patterns: patterns))
        XCTAssertFalse(matcher.matchesAny("hello baz world", patterns: patterns))
    }

    func testMatchesAnyDisabled() {
        let patterns = [
            ProcessPattern(pattern: "*foo*", isEnabled: false),
            ProcessPattern(pattern: "*bar*", isEnabled: true)
        ]

        XCTAssertFalse(matcher.matchesAny("hello foo world", patterns: patterns))
        XCTAssertTrue(matcher.matchesAny("hello bar world", patterns: patterns))
    }

    func testMatchesAnyAllDisabled() {
        let patterns = [
            ProcessPattern(pattern: "*foo*", isEnabled: false),
            ProcessPattern(pattern: "*bar*", isEnabled: false)
        ]

        XCTAssertFalse(matcher.matchesAny("hello foo world", patterns: patterns))
        XCTAssertFalse(matcher.matchesAny("hello bar world", patterns: patterns))
    }

    // MARK: - Cache

    func testCacheClearance() {
        _ = matcher.matches("test", pattern: "*test*")
        matcher.clearCache()
        // Should still work after cache clear
        XCTAssertTrue(matcher.matches("test", pattern: "*test*"))
    }
}
