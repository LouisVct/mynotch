//
//  MenuBarEntryTracker.swift
//  boringNotch
//
//  Remembers where the cursor was just before it entered the notch, so the
//  notch can tell a pointer that slid along the menu bar from a deliberate one.
//

import AppKit

final class MenuBarEntryTracker {
    static let shared = MenuBarEntryTracker()

    private struct Sample {
        let point: NSPoint
        let date: Date
    }

    private var samples: [Sample] = []
    private var globalMonitor: Any?
    private var localMonitor: Any?

    private init() {}

    func start() {
        guard globalMonitor == nil else { return }
        let handler: (NSEvent) -> Void = { [weak self] _ in self?.record(NSEvent.mouseLocation) }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved, handler: handler)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { event in
            handler(event)
            return event
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        samples.removeAll()
    }

    private func record(_ point: NSPoint) {
        let now = Date()
        samples.append(Sample(point: point, date: now))
        samples.removeAll { now.timeIntervalSince($0.date) > 1 }
    }

    /// True when the cursor slid along the menu bar for a moment right before reaching the notch.
    /// A cursor coming up from below (or diagonally) only crosses the menu bar strip at the very end,
    /// so it doesn't count.
    @MainActor
    func enteredFromMenuBar(vm: BoringViewModel) -> Bool {
        let now = Date()
        // Positions of the last 0.4 s that were outside the notch
        let recent = samples.filter { now.timeIntervalSince($0.date) <= 0.4 && !vm.isMouseHovering(position: $0.point) }
        guard let first = recent.first, let last = recent.last,
              let screen = NSScreen.screens.first(where: { NSMouseInRect(last.point, $0.frame, false) })
        else { return false }

        let menuBarHeight = max(
            screen.frame.maxY - screen.visibleFrame.maxY,
            vm.closedNotchSize.height
        )
        let bandBottom = screen.frame.maxY - menuBarHeight
        let allInMenuBar = recent.allSatisfy { $0.point.y >= bandBottom }
        // It has to have spent a little time there, not just passed through
        return allInMenuBar && last.date.timeIntervalSince(first.date) >= 0.1
    }
}
