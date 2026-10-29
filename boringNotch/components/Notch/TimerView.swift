//
//  TimerView.swift
//  boringNotch
//
//  Timer panel of the open notch. Modeled on the iPhone Timer: orange, big countdown,
//  pause and cancel buttons while it runs, quick presets when it's idle.
//

import Defaults
import SwiftUI

extension Color {
    /// iOS system orange, used for the whole timer UI like on the iPhone.
    static let timerOrange = Color(red: 1.0, green: 0.62, blue: 0.04)
}

struct TimerView: View {
    @ObservedObject var pomodoro = PomodoroManager.shared
    @Default(.pomodoroWorkMinutes) private var focusMinutes
    @Default(.pomodoroBreaks) private var breaks

    private let presets = [1, 5, 10, 15, 25, 30, 45, 60]

    var body: some View {
        Group {
            if pomodoro.runState == .idle {
                idleView
            } else {
                runningView
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.smooth, value: pomodoro.runState)
    }

    // MARK: - Idle: pick a duration and start

    private var idleView: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    roundButton("minus", fill: Color.white.opacity(0.14), tint: .white, size: 28) {
                        pomodoro.setFocusMinutes(focusMinutes - (focusMinutes > 10 ? 5 : 1))
                    }
                    Text(String(format: "%d:00", focusMinutes))
                        .font(.system(size: 42, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.timerOrange)
                        .frame(minWidth: 130)
                    roundButton("plus", fill: Color.white.opacity(0.14), tint: .white, size: 28) {
                        pomodoro.setFocusMinutes(focusMinutes + (focusMinutes >= 10 ? 5 : 1))
                    }
                }

                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(presets, id: \.self) { minutes in
                            Button("\(minutes)") { pomodoro.startFocus(minutes: minutes) }
                                .buttonStyle(PresetChipStyle(selected: minutes == focusMinutes))
                        }
                    }
                }
                .scrollIndicators(.never)

                Toggle(isOn: $breaks) {
                    Text("Add a break after (Pomodoro)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .toggleStyle(.checkbox)
                .tint(Color.timerOrange)
            }

            Spacer(minLength: 0)

            roundButton("play.fill", fill: Color.timerOrange, tint: .black, size: 56) {
                pomodoro.start()
            }
            .help("Start")
        }
    }

    // MARK: - Running / paused: countdown and controls

    private var runningView: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "timer")
                    Text(pomodoro.phase.title)
                    if pomodoro.runState == .paused {
                        Text("· Paused").foregroundStyle(.secondary)
                    }
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.timerOrange)

                countdown
                    .font(.system(size: 52, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.timerOrange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                if pomodoro.runState == .running, let start = pomodoro.phaseStartDate, let end = pomodoro.endDate {
                    ProgressView(timerInterval: start...end, countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
                        .tint(Color.timerOrange)
                        .frame(maxWidth: 220)
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 14) {
                // Cancel: stops the timer and goes back to the presets
                roundButton("xmark", fill: Color.white.opacity(0.18), tint: .white, size: 48) {
                    pomodoro.reset()
                }
                .help("Cancel")

                roundButton(
                    pomodoro.runState == .running ? "pause.fill" : "play.fill",
                    fill: Color.timerOrange.opacity(0.3), tint: Color.timerOrange, size: 48
                ) {
                    pomodoro.toggle()
                }
                .help(pomodoro.runState == .running ? "Pause" : "Resume")
            }
        }
    }

    @ViewBuilder
    private var countdown: some View {
        if pomodoro.runState == .running, let end = pomodoro.endDate {
            Text(timerInterval: Date()...max(end, Date().addingTimeInterval(1)), countsDown: true)
        } else {
            Text(Duration.seconds(pomodoro.remainingWhenPaused).formatted(.time(pattern: .minuteSecond)))
                .opacity(0.6)
        }
    }

    private func roundButton(
        _ symbol: String, fill: Color, tint: Color, size: CGFloat, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(fill, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

private struct PresetChipStyle: ButtonStyle {
    let selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(selected ? Color.black : Color.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(selected ? Color.timerOrange : Color.white.opacity(0.14), in: Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
