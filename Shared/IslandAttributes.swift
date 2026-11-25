import ActivityKit
import Foundation

struct IslandAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startedAt: Date
        var endsAt: Date
        var vietnamese: Bool
    }
    var sessionID: String
}
