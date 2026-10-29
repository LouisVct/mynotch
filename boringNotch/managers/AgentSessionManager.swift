//
//  AgentSessionManager.swift
//  boringNotch
//
//  Tracks AI coding agent sessions (Claude Code, ...) reported through mynotch://agent links.
//

import AppKit
import SwiftUI

struct AgentSession: Identifiable, Equatable {
    enum State { case working, needsInput, done }

    let id: String
    var name: String
    var project: String
    var state: State
    var workingSince: Date
    var updatedAt: Date
    var terminalBundleID: String?
}

enum AgentTerminal {
    /// Brings the app that hosts the agent (terminal, editor...) to the front.
    @MainActor
    static func activate(bundleID: String?) {
        guard let bundleID, !bundleID.isEmpty else { return }
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
            running.activate()
        } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }
}

@MainActor
final class AgentSessionManager: ObservableObject {
    static let shared = AgentSessionManager()

    @Published private(set) var sessions: [AgentSession] = []
    @Published var isListExpanded = false

    private var pruneTask: Task<Void, Never>?

    private init() {}

    var workingCount: Int { sessions.filter { $0.state == .working }.count }
    var earliestWorkStart: Date? { sessions.filter { $0.state == .working }.map(\.workingSince).min() }

    func update(
        id: String, name: String, project: String, state: AgentSession.State, terminalBundleID: String?
    ) {
        let now = Date()
        withAnimation(.smooth) {
            if let index = sessions.firstIndex(where: { $0.id == id }) {
                if state == .working && sessions[index].state != .working {
                    sessions[index].workingSince = now
                }
                sessions[index].state = state
                sessions[index].updatedAt = now
                if !name.isEmpty { sessions[index].name = name }
                if !project.isEmpty { sessions[index].project = project }
                if let terminalBundleID { sessions[index].terminalBundleID = terminalBundleID }
            } else {
                sessions.append(
                    AgentSession(
                        id: id, name: name, project: project, state: state,
                        workingSince: now, updatedAt: now, terminalBundleID: terminalBundleID))
            }
        }
        startPruning()

        // Like a Live Activity, a finished session fades out by itself
        if state == .done {
            let marker = now
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(15))
                await MainActor.run {
                    guard let self,
                          let current = self.sessions.first(where: { $0.id == id }),
                          current.state == .done, current.updatedAt == marker else { return }
                    self.end(id: id)
                }
            }
        }
    }

    func end(id: String) {
        withAnimation(.smooth) {
            sessions.removeAll { $0.id == id }
            if sessions.isEmpty { isListExpanded = false }
        }
    }

    private func startPruning() {
        guard pruneTask == nil else { return }
        pruneTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard let self else { return }
                self.prune()
                if self.sessions.isEmpty {
                    self.pruneTask = nil
                    return
                }
            }
        }
    }

    /// Drops sessions that stopped reporting (crashed terminal, missed SessionEnd).
    private func prune() {
        let now = Date()
        withAnimation(.smooth) {
            sessions.removeAll { session in
                let idle = now.timeIntervalSince(session.updatedAt)
                switch session.state {
                case .working: return idle > 3 * 3600
                case .needsInput: return idle > 6 * 3600
                case .done: return idle > 30 * 60
                }
            }
            if sessions.isEmpty { isListExpanded = false }
        }
    }
}
