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

    private var presets: [Int] { breaks ? [15, 20, 25, 30, 45, 50] : [1, 5, 10, 15, 30, 45, 60] }
    @Default(.pomodoroShortBreakMinutes) private var shortBreak
    @Default(.pomodoroLongBreakMinutes) private var longBreak
    @Default(.pomodoroCyclesBeforeLongBreak) private var cycles

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
        .onChange(of: breaks) {
            // Leaving Pomodoro mode while a break is pending: back to a plain focus length
            if !breaks && pomodoro.phase != .work { pomodoro.reset() }
        }
    }

    // MARK: - Idle: pick a duration, then press play

    private var idleView: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Picker("", selection: $breaks) {
                    Text("Timer").tag(false)
                    Text("Pomodoro").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 190)

                if pomodoro.phase == .work {
                    HStack(spacing: 10) {
                        roundButton("minus", fill: Color.white.opacity(0.14), tint: .white, size: 26) {
                            pomodoro.setFocusMinutes(focusMinutes - (focusMinutes > 10 ? 5 : 1))
                        }
                        Text(String(format: "%d:00", focusMinutes))
                            .font(.system(size: 38, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Color.timerOrange)
                            .frame(minWidth: 110)
                        roundButton("plus", fill: Color.white.opacity(0.14), tint: .white, size: 26) {
                            pomodoro.setFocusMinutes(focusMinutes + (focusMinutes >= 10 ? 5 : 1))
                        }
                    }

                    // Choosing a preset only sets the length; the play button starts it
                    ScrollView(.horizontal) {
                        HStack(spacing: 6) {
                            ForEach(presets, id: \.self) { minutes in
                                Button("\(minutes)") { pomodoro.setFocusMinutes(minutes) }
                                    .buttonStyle(PresetChipStyle(selected: minutes == focusMinutes))
                            }
                        }
                    }
                    .scrollIndicators(.never)
                } else {
                    // Pomodoro: a break is waiting after a focus session
                    Text(pomodoro.phase.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.timerOrange)
                    Text(Duration.seconds(pomodoro.currentPhaseDuration).formatted(.time(pattern: .minuteSecond)))
                        .font(.system(size: 38, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.timerOrange)
                }

                if breaks { pomodoroSummary }
            }

            Spacer(minLength: 0)

            VStack(spacing: 8) {
                roundButton("play.fill", fill: Color.timerOrange, tint: .black, size: 56) {
                    pomodoro.start()
                }
                .help("Start")
                if breaks && pomodoro.phase != .work {
                    Button("Skip break") { pomodoro.skip() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// "Focus 25 · Break 5 · Long 15 (every 4)" with one dot per focus session of the current round.
    private var pomodoroSummary: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<max(1, cycles), id: \.self) { index in
                    Circle()
                        .fill(index < pomodoro.completedWorkSessions % max(1, cycles)
                              ? Color.timerOrange : Color.white.opacity(0.2))
                        .frame(width: 7, height: 7)
                }
            }
            Text("Focus \(focusMinutes) · Break \(shortBreak) · Long \(longBreak)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
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
