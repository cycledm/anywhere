import ActivityKit
import OSLog

@MainActor
final class SimulationLiveActivity {
    private let logger = Logger(subsystem: "dev.cycledm.anywhere", category: "LiveActivity")
    private var activity: Activity<SimulationActivityAttributes>?
    private var state: SimulationActivityAttributes.ContentState?
    private var pendingUpdate: Task<Void, Never>?
    private var endingIDs: Set<String> = []

    func start(_ state: SimulationActivityAttributes.ContentState) {
        guard activity == nil, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        if let existing = Activity<SimulationActivityAttributes>.activities.first(where: { !endingIDs.contains($0.id) }) {
            activity = existing
            update(state)
            return
        }
        do {
            activity = try Activity.request(
                attributes: SimulationActivityAttributes(),
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
            self.state = state
        } catch {
            logger.error("Could not start Live Activity: \(error.localizedDescription, privacy: .public)")
        }
    }

    func update(_ state: SimulationActivityAttributes.ContentState) {
        guard let activity, self.state != state else { return }
        self.state = state
        let previous = pendingUpdate
        pendingUpdate = Task {
            await previous?.value
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    func end() {
        var activities = Activity<SimulationActivityAttributes>.activities.filter { !endingIDs.contains($0.id) }
        if let activity, !activities.contains(where: { $0.id == activity.id }) {
            activities.append(activity)
        }
        let previous = pendingUpdate
        activity = nil
        state = nil
        pendingUpdate = nil
        guard !activities.isEmpty else { return }
        endingIDs.formUnion(activities.map(\.id))
        Task {
            await previous?.value
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
                endingIDs.remove(activity.id)
            }
        }
    }
}
