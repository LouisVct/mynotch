//
//  AgentOverlayView.swift
//  boringNotch
//
//  Pills shown under the closed notch: Pomodoro countdown, running AI agents,
//  agent alert banner and the expandable session list.
//

import Defaults
import SwiftUI

struct AgentOverlayView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @ObservedObject var agents = AgentSessionManager.shared
    @ObservedObject var pomodoro = PomodoroManager.shared

    var body: some View {
        VStack(spacing: 6) {
            if let alert = coordinator.agentAlert {
                AgentAlertBanner(alert: alert) { coordinator.dismissAgentAlert() }
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if pomodoro.isActive || !agents.sessions.isEmpty {
                HStack(spacing: 6) {
                    if pomodoro.isActive {
                        PomodoroChip(pomodoro: pomodoro)
                    }
                    if !agents.sessions.isEmpty {
                        AgentChip(agents: agents)
                    }
                }
                .transition(.opacity)
            }

            if agents.isListExpanded && !agents.sessions.isEmpty {
                AgentSessionListView(agents: agents)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.top, vm.effectiveClosedNotchHeight + 10)
        .animation(.smooth, value: coordinator.agentAlert)
    }
}

private struct PomodoroChip: View {
    @ObservedObject var pomodoro: PomodoroManager

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: pomodoro.phase == .work ? "timer" : "cup.and.saucer.fill")
                .foregroundStyle(pomodoro.phase == .work ? Color.red : Color.green)
            if pomodoro.runState == .running, let end = pomodoro.endDate {
                Text(timerInterval: Date()...max(end, Date().addingTimeInterval(1)), countsDown: true)
                    .monospacedDigit()
            } else {
                Text(Duration.seconds(pomodoro.remainingWhenPaused).formatted(.time(pattern: .minuteSecond)))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.white)
        .chipBackground()
        .onTapGesture { pomodoro.toggle() }
        .contextMenu { PomodoroMenuItems(pomodoro: pomodoro) }
    }
}

private struct AgentChip: View {
    @ObservedObject var agents: AgentSessionManager

    private var needsInput: Bool { agents.sessions.contains { $0.state == .needsInput } }

    var body: some View {
        HStack(spacing: 6) {
            if needsInput {
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
            } else if agents.workingCount > 0 {
                ProgressView().controlSize(.mini).scaleEffect(0.8)
            } else {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }

            if agents.sessions.count > 1 {
                Text("\(agents.sessions.count) agents")
            } else if let session = agents.sessions.first {
                Text(session.name)
            }

            if let since = agents.earliestWorkStart, !needsInput {
                Text(since, style: .timer).monospacedDigit().foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.white)
        .chipBackground()
        .onTapGesture {
            withAnimation(.smooth) { agents.isListExpanded.toggle() }
        }
    }
}

private struct AgentSessionListView: View {
    @ObservedObject var agents: AgentSessionManager

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(agents.sessions) { session in
                HStack(spacing: 8) {
                    switch session.state {
                    case .working: ProgressView().controlSize(.mini).scaleEffect(0.8)
                    case .needsInput: Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                    case .done: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Text(session.name).font(.system(size: 11, weight: .semibold))
                        if !session.project.isEmpty {
                            Text(session.project).font(.system(size: 10)).foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    Spacer(minLength: 8)
                    if session.state == .working {
                        Text(session.workingSince, style: .timer)
                            .monospacedDigit().font(.system(size: 10)).foregroundStyle(.white.opacity(0.6))
                    }
                    if session.terminalBundleID != nil {
                        Button {
                            AgentTerminal.activate(bundleID: session.terminalBundleID)
                        } label: {
                            Image(systemName: "terminal")
                        }
                        .buttonStyle(.plain)
                        .help("Go to terminal")
                    }
                    Button {
                        agents.end(id: session.id)
                    } label: {
                        Image(systemName: "xmark").font(.system(size: 9))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
        .foregroundStyle(.white)
        .padding(10)
        .frame(width: 280)
        .background(.black, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.12)))
        .shadow(color: .black.opacity(0.5), radius: 8, y: 2)
    }
}

private extension View {
    func chipBackground() -> some View {
        self
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.black, in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.12)))
            .contentShape(Capsule())
    }
}

/// Context menu shared by the header button and the pill under the closed notch.
struct PomodoroMenuItems: View {
    @ObservedObject var pomodoro: PomodoroManager

    private let focusPresets = [15, 20, 25, 30, 45, 50, 60, 90]
    private let breakPresets = [3, 5, 10, 15]

    var body: some View {
        Button(pomodoro.runState == .running ? "Pause" : pomodoro.runState == .paused ? "Resume" : "Start") {
            pomodoro.toggle()
        }
        Menu("Focus duration (\(Defaults[.pomodoroWorkMinutes]) min)") {
            ForEach(focusPresets, id: \.self) { minutes in
                Button("\(minutes) min") { pomodoro.setFocusMinutes(minutes) }
            }
            Divider()
            Button("Custom…") {
                pomodoro.promptCustomMinutes(title: "Focus duration", current: Defaults[.pomodoroWorkMinutes]) {
                    pomodoro.setFocusMinutes($0)
                }
            }
        }
        Menu("Break duration (\(Defaults[.pomodoroShortBreakMinutes]) min)") {
            ForEach(breakPresets, id: \.self) { minutes in
                Button("\(minutes) min") { pomodoro.setShortBreakMinutes(minutes) }
            }
            Divider()
            Button("Custom…") {
                pomodoro.promptCustomMinutes(title: "Break duration", current: Defaults[.pomodoroShortBreakMinutes]) {
                    pomodoro.setShortBreakMinutes($0)
                }
            }
        }
        Divider()
        Button("Skip phase") { pomodoro.skip() }
        Button("Reset") { pomodoro.reset() }
    }
}
