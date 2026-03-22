import ActivityKit
import SwiftUI
import WidgetKit

struct TrackLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TrackActivityAttributes.self) { context in
            // Lock screen / banner UI
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.activityType, systemImage: activityIcon(context.attributes.activityType))
                        .font(.caption)
                        .foregroundColor(.white)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isPaused {
                        Text("PAUSED")
                            .font(.caption.bold())
                            .foregroundColor(.orange)
                    } else {
                        Text("Track.")
                            .font(.caption.bold())
                            .foregroundColor(.gray)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 24) {
                        StatColumn(label: "KM", value: context.state.distance)
                        StatColumn(label: "TIME", value: context.state.movingTime)
                        StatColumn(label: "KM/H", value: context.state.avgSpeed)
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: activityIcon(context.attributes.activityType))
                    .foregroundColor(context.state.isPaused ? .orange : .red)
            } compactTrailing: {
                Text("\(context.state.distance) km")
                    .font(.caption2)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: activityIcon(context.attributes.activityType))
                    .foregroundColor(.red)
            }
        }
    }
}

private func activityIcon(_ type: String) -> String {
    switch type {
    case "Ride": return "bicycle"
    case "Football": return "sportscourt"
    default: return "figure.walk"
    }
}

private struct StatColumn: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.body, design: .rounded).bold())
                .monospacedDigit()
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<TrackActivityAttributes>

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Label(context.attributes.activityType, systemImage: activityIcon(context.attributes.activityType))
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Spacer()
                if context.state.isPaused {
                    Text("PAUSED")
                        .font(.caption.bold())
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .clipShape(Capsule())
                } else {
                    Text("Track.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }

            HStack(spacing: 0) {
                StatCell(value: "\(context.state.distance)", unit: "km", label: "DISTANCE")
                Spacer()
                StatCell(value: context.state.movingTime, unit: "", label: "MOVING TIME")
                Spacer()
                StatCell(value: "\(context.state.avgSpeed)", unit: "km/h", label: "AVG SPEED")
            }
        }
        .padding(16)
        .activityBackgroundTint(.black.opacity(0.75))
    }
}

private struct StatCell: View {
    let value: String
    let unit: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(.title2, design: .rounded).bold())
                    .monospacedDigit()
                    .foregroundColor(.white)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.gray)
        }
    }
}
