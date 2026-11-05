import ActivityKit
import SwiftUI
import WidgetKit

@main
struct AnywhereLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SimulationActivityAttributes.self) { context in
            HStack {
                status(context.state)
                Spacer()
                stopButton
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        status(context.state)
                        Spacer()
                        stopButton
                    }
                    .padding(.horizontal, 8)
                }
            } compactLeading: {
                Image(systemName: "location.circle.fill")
                    .foregroundStyle(.mint)
            } compactTrailing: {
                Image(systemName: statusIcon(context.state.status))
            } minimal: {
                Image(systemName: statusIcon(context.state.status))
                    .accessibilityLabel(statusLabel(context.state.status))
            }
        }
    }

    private var stopButton: some View {
        Button(intent: StopSimulationIntent()) {
            Label("Stop", systemImage: "stop.fill")
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 32)
        }
        .fixedSize()
        .buttonStyle(.bordered)
        .tint(.red)
    }

    private func status(_ state: SimulationActivityAttributes.ContentState) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: "Anywhere")
                .font(.headline)
            if let destination = state.destination {
                Text("\(destination.location) (offset \(destination.formattedOffset) m)")
                    .font(.subheadline)
                    .lineLimit(2)
                    .foregroundStyle(.secondary)
            }
            if state.destination == nil || state.status != .active {
                Label(statusLabel(state.status), systemImage: statusIcon(state.status))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func statusLabel(_ state: SimulationActivityAttributes.ContentState.Status) -> LocalizedStringKey {
        switch state {
        case .active: "Simulating Location"
        case .reconnecting: "Reconnecting…"
        case .interrupted: "Simulation Interrupted"
        }
    }

    private func statusIcon(_ state: SimulationActivityAttributes.ContentState.Status) -> String {
        switch state {
        case .active: "location.fill"
        case .reconnecting: "arrow.trianglehead.clockwise.rotate.90"
        case .interrupted: "exclamationmark.circle.fill"
        }
    }
}
