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
            if let destination = state.destination {
                Text("Location: \(destination.location)")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text("Offset: \(destination.formattedOffset) m")
                        .lineLimit(1)
                    if state.status != .active {
                        Image(systemName: statusIcon(state.status))
                            .accessibilityLabel(statusLabel(state.status))
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            } else {
                Text(verbatim: "Anywhere")
                    .font(.headline)
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
