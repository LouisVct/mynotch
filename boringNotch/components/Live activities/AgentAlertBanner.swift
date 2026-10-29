//
//  AgentAlertBanner.swift
//  boringNotch
//
//  Banner shown under the notch when an AI coding agent (Claude Code, etc.)
//  asks for attention through a mynotch://agent link.
//

import SwiftUI

struct AgentAlert: Identifiable, Equatable {
    enum Kind { case needsInput, done }

    let id = UUID()
    let name: String
    let message: String
    let kind: Kind
    var terminalBundleID: String? = nil
    var sessionID: String? = nil
}

struct AgentAlertBanner: View {
    let alert: AgentAlert
    /// Tap on the banner: jump to the app hosting the agent and close the banner
    let onOpen: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: alert.kind == .needsInput ? "exclamationmark.bubble.fill" : "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(alert.kind == .needsInput ? Color.orange : Color.green)
            VStack(alignment: .leading, spacing: 1) {
                Text(alert.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                Text(alert.message)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: 260)
        .background(.black, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.12)))
        .shadow(color: .black.opacity(0.5), radius: 8, y: 2)
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
    }
}
