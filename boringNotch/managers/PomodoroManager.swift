//
//  PomodoroManager.swift
//  boringNotch
//
//  Pomodoro timer: work / short break / long break cycles.
//

import AppKit
import Defaults
import SwiftUI

@MainActor
final class PomodoroManager: ObservableObject {
    static let shared = PomodoroManager()

    enum Phase {
        case work, shortBreak, longBreak

        var title: String {
            switch self {
            case .work: return "Focus"
            case .shortBreak: return "Short break"
            case .longBreak: return "Long break"
            }
        }
    }

    enum RunState { case idle, running, paused }

    @Published private(set) var phase: Phase = .work
    @Published private(set) var runState: RunState = .idle
    @Published private(set) var endDate: Date?
    @Published private(set) var remainingWhenPaused: TimeInterval = 0
    @Published private(set) var completedWorkSessions = 0

    private var finishTask: Task<Void, Never>?

    private init() {}

    var isActive: Bool { runState != .idle }

    private func duration(for phase: Phase) -> TimeInterval {
        let minutes: Int
        switch phase {
        case .work: minutes = Defaults[.pomodoroWorkMinutes]
        case .shortBreak: minutes = Defaults[.pomodoroShortBreakMinutes]
        case .longBreak: minutes = Defaults[.pomodoroLongBreakMinutes]
        }
        return TimeInterval(max(1, minutes) * 60)
    }

    // MARK: - Controls

    func toggle() {
        switch runState {
        case .idle: start()
        case .running: pause()
        case .paused: resume()
        }
    }

    func start() {
        begin(after: duration(for: phase))
    }

    func pause() {
        guard runState == .running, let endDate else { return }
        remainingWhenPaused = max(0, endDate.timeIntervalSinceNow)
        self.endDate = nil
        finishTask?.cancel()
        withAnimation(.smooth) { runState = .paused }
    }

    func resume() {
        guard runState == .paused else { return }
        begin(after: remainingWhenPaused)
    }

    func skip() {
        advance()
    }

    func reset() {
        finishTask?.cancel()
        withAnimation(.smooth) {
            phase = .work
            runState = .idle
            endDate = nil
            completedWorkSessions = 0
        }
    }

    // MARK: - Internals

    private func begin(after interval: TimeInterval) {
        endDate = Date().addingTimeInterval(interval)
        withAnimation(.smooth) { runState = .running }

        finishTask?.cancel()
        finishTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(interval))
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.phaseFinished() }
        }
    }

    private func phaseFinished() {
        let finished = phase
        advance()

        if Defaults[.pomodoroSound] {
            NSSound(named: "Glass")?.play()
        }
        let message = finished == .work
            ? "Focus done. \(phase.title) next."
            : "Break over. Back to focus."
        BoringViewCoordinator.shared.showAgentAlert(
            name: "Pomodoro", message: message, kind: .done, force: true)
    }

    private func advance() {
        finishTask?.cancel()
        withAnimation(.smooth) {
            if phase == .work {
                completedWorkSessions += 1
                let cycles = max(1, Defaults[.pomodoroCyclesBeforeLongBreak])
                phase = completedWorkSessions % cycles == 0 ? .longBreak : .shortBreak
            } else {
                phase = .work
            }
            runState = .idle
            endDate = nil
        }
        if Defaults[.pomodoroAutoStartNext] { start() }
    }
}
