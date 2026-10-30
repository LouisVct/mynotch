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

    /// Focus sessions per round (a long break follows the last one).
    var cycleTotal: Int { max(1, Defaults[.pomodoroCyclesBeforeLongBreak]) }

    /// Focus sessions done in the current round; the whole round counts as done during the long break.
    var cycleDone: Int { phase == .longBreak ? cycleTotal : completedWorkSessions % cycleTotal }

    /// Length of the phase currently selected (focus or break).
    var currentPhaseDuration: TimeInterval { duration(for: phase) }

    /// When the running phase started, for progress bars.
    var phaseStartDate: Date? { endDate?.addingTimeInterval(-currentPhaseDuration) }

    /// Starts a focus phase with the given length in one step (quick presets).
    func startFocus(minutes: Int) {
        finishTask?.cancel()
        runState = .idle
        phase = .work
        Defaults[.pomodoroWorkMinutes] = min(max(1, minutes), 240)
        start()
    }

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

    /// Makes the notch open on the Timer panel. The tap itself still opens the notch.
    static func selectTimerPanel() {
        BoringViewCoordinator.shared.currentView = .timer
    }

    // MARK: - Durations

    /// Sets the focus duration. If a focus phase is in progress it restarts with the new length.
    func setFocusMinutes(_ minutes: Int) {
        let clamped = min(max(1, minutes), 240)
        Defaults[.pomodoroWorkMinutes] = clamped
        guard phase == .work else { return }
        switch runState {
        case .idle: break
        case .running: begin(after: duration(for: .work))
        case .paused: remainingWhenPaused = duration(for: .work)
        }
        objectWillChange.send()
    }

    func setShortBreakMinutes(_ minutes: Int) {
        Defaults[.pomodoroShortBreakMinutes] = min(max(1, minutes), 120)
        objectWillChange.send()
    }

    func promptCustomMinutes(title: String, current: Int, onSet: @escaping (Int) -> Void) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = "Minutes (1 to 240)"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 120, height: 24))
        field.stringValue = "\(current)"
        alert.accessoryView = field
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn, let value = Int(field.stringValue.trimmingCharacters(in: .whitespaces)) {
            onSet(value)
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
        let message: String
        if finished == .work {
            message = Defaults[.pomodoroBreaks] ? "Focus done. \(phase.title) next." : "Timer done."
        } else {
            message = "Break over. Back to focus."
        }
        BoringViewCoordinator.shared.showAgentAlert(
            name: "Pomodoro", message: message, kind: .done, force: true)
    }

    private func advance() {
        finishTask?.cancel()
        withAnimation(.smooth) {
            if phase == .work && !Defaults[.pomodoroBreaks] {
                // Plain timer: nothing follows the countdown
                runState = .idle
                endDate = nil
                return
            }
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
        if runState == .idle && Defaults[.pomodoroAutoStartNext] && Defaults[.pomodoroBreaks] { start() }
    }
}
