import SwiftUI

struct ContentView: View {
    @EnvironmentObject var session: WatchSessionManager

    var body: some View {
        Group {
            if session.state.isRecording {
                RecordingView()
            } else {
                StartView()
            }
        }
        .background(WatchTheme.bg)
    }
}

/// Idle screen: pick an activity type to start recording on the phone.
struct StartView: View {
    @EnvironmentObject var session: WatchSessionManager

    private let types = ["Ride", "Run", "Walk", "Swim", "Football"]

    var body: some View {
        List {
            Section {
                ForEach(types, id: \.self) { type in
                    Button {
                        session.start(activityType: type)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: WatchTheme.typeSymbol(type))
                                .foregroundStyle(WatchTheme.typeTint(type))
                                .frame(width: 24)
                            Text(type)
                                .foregroundStyle(WatchTheme.txt)
                        }
                    }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(WatchTheme.s1)
                    )
                }
            } header: {
                Text("Track.")
                    .font(.system(.footnote, design: .monospaced).weight(.bold))
                    .foregroundStyle(WatchTheme.accent)
            } footer: {
                if !session.phoneReachable {
                    Text("Open Track on iPhone")
                        .foregroundStyle(WatchTheme.txt3)
                }
            }
        }
        .environment(\.defaultMinListRowHeight, 36)
    }
}

/// Live stats mirror + remote controls while the phone records.
struct RecordingView: View {
    @EnvironmentObject var session: WatchSessionManager

    var body: some View {
        let state = session.state
        let tint = WatchTheme.typeTint(state.activityType)

        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: WatchTheme.typeSymbol(state.activityType))
                        .foregroundStyle(tint)
                    Text(state.activityType.uppercased())
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(WatchTheme.txt2)
                    Spacer()
                    if state.isPaused {
                        Text("PAUSED")
                            .font(.system(.caption2, design: .monospaced).weight(.bold))
                            .foregroundStyle(WatchTheme.pause)
                    } else {
                        Circle()
                            .fill(WatchTheme.stop)
                            .frame(width: 8, height: 8)
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(state.formattedDistance)
                        .font(.system(size: 40, weight: .bold, design: .monospaced))
                        .foregroundStyle(state.isPaused ? WatchTheme.txt3 : WatchTheme.txt)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("km")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(WatchTheme.txt3)
                }

                statRow(label: "TIME", value: state.elapsed)
                statRow(label: "KM/H", value: state.formattedSpeed)

                HStack(spacing: 8) {
                    Button {
                        session.togglePause()
                    } label: {
                        Image(systemName: state.isPaused ? "play.fill" : "pause.fill")
                            .foregroundStyle(WatchTheme.bg)
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(WatchTheme.pause, in: RoundedRectangle(cornerRadius: 10))
                    }
                    Button {
                        session.stop()
                    } label: {
                        Image(systemName: "stop.fill")
                            .foregroundStyle(WatchTheme.txt)
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(WatchTheme.stop, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(.horizontal, 4)
        }
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(WatchTheme.txt3)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced).weight(.semibold))
                .foregroundStyle(WatchTheme.txt)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 6)
        .background(WatchTheme.s1, in: RoundedRectangle(cornerRadius: 8))
    }
}
