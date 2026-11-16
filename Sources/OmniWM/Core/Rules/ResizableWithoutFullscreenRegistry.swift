// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import AppKit
import Foundation

/// Apps whose ordinary document windows opt out of native fullscreen, so the green button only zooms.
/// The generic heuristic floats such windows because the same AX shape also describes settings panes
/// (System Settings) and hotkey windows (iTerm2), so tiling them is limited to apps known to use it for
/// plain resizable windows.
enum ResizableWithoutFullscreenRegistry {
    static let bundleIds: Set<String> = [
        "com.apple.activitymonitor",
        "com.unity3d.unityeditor5.x"
    ]

    static func decision(
        for facts: AXWindowFacts,
        windowServer: WindowServerInfo?,
        bundleIds: Set<String>
    ) -> Bool {
        guard facts.attributeFetchSucceeded,
              facts.role == (kAXWindowRole as String),
              facts.subrole == (kAXStandardWindowSubrole as String),
              let windowServer,
              windowServer.level == 0,
              !windowServer.hasParentWindow,
              let bundleId = facts.bundleId?.lowercased(),
              bundleIds.contains(bundleId)
        else {
            return false
        }

        // An enabled zoom button is AppKit's signal that the window is user-resizable; fixed-size
        // windows (About boxes, alerts) disable it and keep floating.
        return !facts.hasFullscreenButton
            && facts.hasCloseButton
            && facts.hasZoomButton
            && facts.zoomButtonEnabled == true
            && facts.isModal != true
    }
}
