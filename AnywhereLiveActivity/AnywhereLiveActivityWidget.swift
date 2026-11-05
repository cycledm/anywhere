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
                Image(systemName: statusIcon(context.state))
            } minimal: {
                Image(systemName: statusIcon(context.state))
                    .accessibilityLabel(statusLabel(context.state))
            }
        }
    }

    private var stopButton: some View {
        Button(intent: StopSimulationIntent()) {
            Label("Stop Simulated Location", systemImage: "stop.fill")
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 32)
        }
        .buttonStyle(.bordered)
        .tint(.red)
    }

    private func status(_ state: SimulationActivityAttributes.ContentState) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: "Anywhere")
                .font(.headline)
            Label(statusLabel(state), systemImage: statusIcon(state))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func statusLabel(_ state: SimulationActivityAttributes.ContentState) -> LocalizedStringKey {
        switch state {
        case .active: "Simulating Location"
        case .reconnecting: "Reconnecting…"
        case .interrupted: "Simulation Interrupted"
        }
    }

    private func statusIcon(_ state: SimulationActivityAttributes.ContentState) -> String {
        switch state {
        case .active: "location.fill"
        case .reconnecting: "arrow.trianglehead.clockwise.rotate.90"
        case .interrupted: "exclamationmark.circle.fill"
        }
    }
}
