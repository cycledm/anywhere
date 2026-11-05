import ActivityKit

struct SimulationActivityAttributes: ActivityAttributes {
    struct Destination: Codable, Hashable {
        let location: String
        let offsetMeters: Double

        var formattedOffset: String {
            offsetMeters.formatted(.number.precision(.fractionLength(0...1)))
        }
    }

    struct ContentState: Codable, Hashable {
        enum Status: String, Codable, Hashable {
            case active
            case reconnecting
            case interrupted
        }

        let status: Status
        let destination: Destination?

        init(status: Status, destination: Destination?) {
            self.status = status
            self.destination = destination
        }

        init(from decoder: Decoder) throws {
            if let legacyStatus = try? decoder.singleValueContainer().decode(Status.self) {
                self.init(status: legacyStatus, destination: nil)
                return
            }
            let values = try decoder.container(keyedBy: CodingKeys.self)
            self.init(
                status: try values.decode(Status.self, forKey: .status),
                destination: try values.decodeIfPresent(Destination.self, forKey: .destination)
            )
        }
    }
}
