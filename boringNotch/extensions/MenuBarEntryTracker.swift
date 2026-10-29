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

    /// True when the cursor reached the notch horizontally (from its left or right side)
    /// instead of coming down from below.
    @MainActor
    func enteredFromSide(vm: BoringViewModel) -> Bool {
        guard let previous = samples.last(where: { !vm.isMouseHovering(position: $0.point) }),
              let screen = NSScreen.screens.first(where: { NSMouseInRect(previous.point, $0.frame, false) })
        else { return false }
        // Same vertical band as the closed notch: the cursor slid in sideways
        return previous.point.y >= screen.frame.maxY - vm.closedNotchSize.height
    }

    /// True when the last position before the cursor reached the notch was in the
    /// menu bar strip beside it (i.e. it travelled along the menu bar).
    @MainActor
    func enteredFromMenuBar(vm: BoringViewModel) -> Bool {
        guard let previous = samples.last(where: { !vm.isMouseHovering(position: $0.point) }),
              let screen = NSScreen.screens.first(where: { NSMouseInRect(previous.point, $0.frame, false) })
        else { return false }

        let menuBarHeight = max(
            screen.frame.maxY - screen.visibleFrame.maxY,
            vm.closedNotchSize.height
        )
        return previous.point.y >= screen.frame.maxY - menuBarHeight
    }
}
