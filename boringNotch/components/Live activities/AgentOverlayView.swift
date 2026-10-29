//
//  AgentOverlayView.swift
//  boringNotch
//
//  Live activities for AI agents and the Pomodoro timer:
//  - badge / timer shown inside the closed notch (left / right of the camera cutout)
//  - banners and session list shown under the notch
//

import Defaults
import SwiftUI

// MARK: - Inside the closed notch

/// Status of the running agents, shown on the left of the notch when music isn't using that slot.
struct AgentBadge: View {
    @ObservedObject var agents = AgentSessionManager.shared

    private var needsInput: Bool { agents.sessions.contains { $0.state == .needsInput } }

    var body: some View {
        HStack(spacing: 2) {
            if needsInput {
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
            } else if agents.workingCount > 0 {
                ProgressView().controlSize(.mini).scaleEffect(0.75)
            } else {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
            if agents.sessions.count > 1 {
                Text("\(agents.sessions.count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .font(.system(size: 13))
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.smooth) { agents.isListExpanded.toggle() }
        }
        .help("AI agents")
    }
}

/// Pomodoro countdown, shown on the right of the notch in place of the music visualizer.
struct PomodoroTimerLabel: View {
    @ObservedObject var pomodoro = PomodoroManager.shared

    var body: some View {
        Group {
            if pomodoro.runState == .running, let end = pomodoro.endDate {
                Text(timerInterval: Date()...max(end, Date().addingTimeInterval(1)), countsDown: true, showsHours: false)
            } else {
                Text(Duration.seconds(pomodoro.remainingWhenPaused).formatted(.time(pattern: .minuteSecond)))
                    .opacity(0.6)
            }
        }
        .monospacedDigit()
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .foregroundStyle(pomodoro.phase == .work ? Color.red : Color.green)
        .lineLimit(1)
        .contentShape(Rectangle())
        .contextMenu { PomodoroMenuItems(pomodoro: pomodoro) }
    }
}

// MARK: - Under the notch

struct AgentOverlayView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @ObservedObject var agents = AgentSessionManager.shared
    @ObservedObject var music = MusicManager.shared

    /// When music owns the left slot of the notch, agents get a small pill under it instead.
    private var musicUsesLeftSlot: Bool {
        (music.isPlaying || !music.isPlayerIdle) && coordinator.musicLiveActivityEnabled
    }

    var body: some View {
        VStack(spacing: 6) {
            ForEach(coordinator.agentAlerts) { alert in
                AgentAlertBanner(
                    alert: alert,
                    onOpen: { coordinator.openAgentAlert(alert) },
                    onDismiss: { coordinator.dismissAgentAlert(alert.id) }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if coordinator.agentAlerts.isEmpty && musicUsesLeftSlot && !agents.sessions.isEmpty {
                AgentPill(agents: agents)
                    .transition(.opacity)
            }

            if agents.isListExpanded && !agents.sessions.isEmpty {
                AgentSessionListView(agents: agents)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.top, vm.effectiveClosedNotchHeight + 10)
        .animation(.smooth, value: coordinator.agentAlerts)
        .animation(.smooth, value: agents.sessions)
    }
}

private struct AgentPill: View {
    @ObservedObject var agents: AgentSessionManager

    var body: some View {
        HStack(spacing: 6) {
            AgentBadge(agents: agents)
            Text(agents.sessions.count > 1 ? "\(agents.sessions.count) agents" : (agents.sessions.first?.name ?? ""))
            if let since = agents.earliestWorkStart {
                Text(since, style: .timer).monospacedDigit().foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.black, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.12)))
        .contentShape(Capsule())
        .onTapGesture {
            withAnimation(.smooth) { agents.isListExpanded.toggle() }
        }
    }
}

private struct AgentSessionListView: View {
    @ObservedObject var agents: AgentSessionManager

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
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
                    Button {
                        agents.end(id: session.id)
                    } label: {
                        Image(systemName: "xmark").font(.system(size: 9)).padding(4)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.vertical, 3)
                .contentShape(Rectangle())
                // Tap a row to jump to the window hosting that session
                .onTapGesture { AgentTerminal.activate(bundleID: session.terminalBundleID) }
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

// MARK: - Pomodoro menu

/// Context menu shared by the header button and the timer in the notch.
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
