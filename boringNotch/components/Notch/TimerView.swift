//
//  TimerView.swift
//  boringNotch
//
//  Timer panel of the open notch. Orange like the iPhone Timer, with two modes:
//  - Timer: a plain countdown with quick presets
//  - Pomodoro: focus / short break / long break cycles shown as dots, optional task name,
//    phases chained automatically
//  Presets only choose the length; the play button starts.
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
    @Default(.pomodoroBreaks) private var pomodoroMode
    @Default(.pomodoroTask) private var task

    private var presets: [Int] { pomodoroMode ? [15, 20, 25, 30, 45, 50] : [1, 5, 10, 15, 30, 45, 60] }

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
        .onChange(of: pomodoroMode) {
            // Leaving Pomodoro mode while a break is pending: back to a plain focus length
            if !pomodoroMode && pomodoro.phase != .work { pomodoro.reset() }
        }
    }

    // MARK: - Idle: pick a duration, then press play

    private var idleView: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 12) {
                    Picker("", selection: $pomodoroMode) {
                        Text("Timer").tag(false)
                        Text("Pomodoro").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 170)

                    if pomodoroMode { CycleDots(pomodoro: pomodoro) }
                }

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
                    // A break is waiting after a focus session
                    Text(pomodoro.phase.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.timerOrange)
                    Text(Duration.seconds(pomodoro.currentPhaseDuration).formatted(.time(pattern: .minuteSecond)))
                        .font(.system(size: 38, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.timerOrange)
                }

                if pomodoroMode { taskField }
            }

            Spacer(minLength: 0)

            VStack(spacing: 8) {
                roundButton("play.fill", fill: Color.timerOrange, tint: .black, size: 56) {
                    pomodoro.start()
                }
                .help("Start")
                if pomodoroMode && pomodoro.phase != .work {
                    Button("Skip break") { pomodoro.skip() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var taskField: some View {
        TextField("What are you working on?", text: $task)
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.1), in: Capsule())
            .frame(maxWidth: 260)
    }

    // MARK: - Running / paused: countdown and controls

    private var runningView: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: "timer")
                        Text(headline).lineLimit(1)
                        if pomodoro.runState == .paused {
                            Text("· Paused").foregroundStyle(.secondary)
                        }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.timerOrange)

                    if pomodoroMode { CycleDots(pomodoro: pomodoro) }
                }

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

            HStack(spacing: 12) {
                // Cancel: stops everything and goes back to the start
                roundButton("xmark", fill: Color.white.opacity(0.18), tint: .white, size: 44) {
                    pomodoro.reset()
                }
                .help("Cancel")

                if pomodoroMode {
                    roundButton("forward.end.fill", fill: Color.white.opacity(0.18), tint: .white, size: 44) {
                        pomodoro.skip()
                    }
                    .help("Next phase")
                }

                roundButton(
                    pomodoro.runState == .running ? "pause.fill" : "play.fill",
                    fill: Color.timerOrange.opacity(0.3), tint: Color.timerOrange, size: 44
                ) {
                    pomodoro.toggle()
                }
                .help(pomodoro.runState == .running ? "Pause" : "Resume")
            }
        }
    }

    /// "Focus · Reply to emails" in Pomodoro mode, just the phase otherwise.
    private var headline: String {
        let name = task.trimmingCharacters(in: .whitespaces)
        if pomodoroMode && pomodoro.phase == .work && !name.isEmpty { return name }
        return pomodoro.phase.title
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

/// One dot per focus session of the round: filled = done, half = the one in progress, empty = to come.
struct CycleDots: View {
    @ObservedObject var pomodoro: PomodoroManager

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<pomodoro.cycleTotal, id: \.self) { index in
                let done = index < pomodoro.cycleDone
                let current = index == pomodoro.cycleDone && pomodoro.phase == .work && pomodoro.isActive
                Circle()
                    .fill(done ? Color.timerOrange : Color.white.opacity(0.2))
                    .overlay {
                        if current {
                            // Left half filled: the session being worked on
                            Rectangle()
                                .fill(Color.timerOrange)
                                .frame(width: 4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .clipShape(Circle())
                    .frame(width: 8, height: 8)
            }
        }
        .help("Focus sessions before the long break")
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
