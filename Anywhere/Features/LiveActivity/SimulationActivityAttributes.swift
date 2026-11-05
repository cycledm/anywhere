import ActivityKit

struct SimulationActivityAttributes: ActivityAttributes {
    enum ContentState: String, Codable, Hashable {
        case active
        case reconnecting
        case interrupted
    }
}
