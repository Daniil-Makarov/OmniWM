// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import AppKit

@MainActor
extension NSMenu {
    /// Pops the menu up with its top-left corner at `location` (in `view`'s coordinates, or screen
    /// coordinates without a view), like a context menu.
    ///
    /// `popUp(positioning:at:in:)` treats the menu like a pop-up button's: when the pointer sits
    /// above the menu (on a bar button or workspace at the top of the screen), AppKit hides the first item behind
    /// a scroll-up arrow and slides the menu down once it is hovered. A context menu opens fully
    /// expanded at the point, so the menu is driven by a synthesized right-click in a helper panel
    /// that is never ordered on screen.
    func popUpAsContextMenu(at location: CGPoint, in view: NSView? = nil) {
        let screenPoint = if let view, let window = view.window {
            window.convertPoint(toScreen: view.convert(location, to: nil))
        } else {
            location
        }
        let panel = NSPanel(
            contentRect: NSRect(origin: screenPoint, size: CGSize(width: 1, height: 1)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = true
        defer { panel.close() }
        guard let helperView = panel.contentView,
              let event = NSEvent.mouseEvent(
                  with: .rightMouseDown,
                  location: panel.convertPoint(fromScreen: screenPoint),
                  modifierFlags: [],
                  timestamp: ProcessInfo.processInfo.systemUptime,
                  windowNumber: panel.windowNumber,
                  context: nil,
                  eventNumber: 0,
                  clickCount: 1,
                  pressure: 1
              )
        else {
            popUp(positioning: nil, at: location, in: view)
            return
        }
        NSMenu.popUpContextMenu(self, with: event, for: helperView)
    }
}
