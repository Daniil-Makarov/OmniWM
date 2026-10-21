// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import CoreGraphics
@testable import OmniWM
import XCTest

@MainActor
final class NiriKeepViewportMinVisibleTests: XCTestCase {
    private struct Fixture {
        let engine: NiriLayoutEngine
        let workspaceId: WorkspaceDescriptor.ID
        let windows: [NiriWindow]
        let workingFrame = CGRect(x: 0, y: 0, width: 1728, height: 1060)
        var state: ViewportState

        var columns: [NiriContainer] {
            engine.columns(in: workspaceId)
        }

        var context: NiriInteractionContext {
            .init(
                workspaceId: workspaceId,
                motion: .disabled,
                workingFrame: workingFrame,
                gaps: 0,
                orientation: .horizontal
            )
        }

        var viewStart: CGFloat {
            state.columnX(at: state.activeColumnIndex, columns: columns, gap: 0) + state.viewOffset
        }

        init() {
            let engine = NiriLayoutEngine(visibleContainerCount: 2)
            engine.defaultContainerPrimarySpan = nil
            let workspaceId = WorkspaceDescriptor.ID()
            let windows = (1 ... 2).map {
                engine.addWindow(token: WindowToken(pid: 616, windowId: $0), to: workspaceId, afterSelection: nil)
            }
            for window in windows {
                window.constraints = WindowSizeConstraints(
                    minSize: CGSize(width: 875, height: 1),
                    maxSize: .zero,
                    isFixed: false
                )
            }
            for column in engine.columns(in: workspaceId) {
                column.width = .fixed(875)
            }
            let state = ViewportState(selectedNodeId: windows[0].id)
            _ = engine.calculateLayout(
                state: state,
                workspaceId: workspaceId,
                monitorFrame: workingFrame,
                gaps: (0, 0),
                orientation: .horizontal
            )
            self.engine = engine
            self.workspaceId = workspaceId
            self.windows = windows
            self.state = state
        }

        mutating func focusSecondColumn(minimumVisibleFraction: CGFloat, centerMode: CenterFocusedColumn = .never) {
            let columns = columns
            state.retargetColumn(to: 1, columns: columns, gap: 0, orientation: .horizontal)
            state.ensureContainerVisible(
                containerIndex: 1,
                containers: columns,
                context: context,
                animate: false,
                centerMode: centerMode,
                fromContainerIndex: 0,
                minimumVisibleFraction: minimumVisibleFraction
            )
        }
    }

    func testMostlyVisibleColumnKeepsViewportWhenThresholdIsMet() {
        var fixture = Fixture()
        XCTAssertEqual(fixture.columns.map(\.cachedWidth), [875, 875])
        XCTAssertEqual(fixture.viewStart, 0, accuracy: 0.001)

        fixture.focusSecondColumn(minimumVisibleFraction: 0.9)

        XCTAssertEqual(fixture.state.activeColumnIndex, 1)
        XCTAssertEqual(fixture.viewStart, 0, accuracy: 0.001)
    }

    func testDefaultThresholdStillScrollsPartlyHiddenColumnIntoView() {
        var fixture = Fixture()

        fixture.focusSecondColumn(minimumVisibleFraction: 1)

        XCTAssertEqual(fixture.viewStart, 22, accuracy: 0.001)
    }

    func testThresholdAboveVisibleFractionStillScrolls() {
        var fixture = Fixture()

        fixture.focusSecondColumn(minimumVisibleFraction: 0.99)

        XCTAssertEqual(fixture.viewStart, 22, accuracy: 0.001)
    }

    func testAlwaysCenterIgnoresThreshold() {
        var fixture = Fixture()

        fixture.focusSecondColumn(minimumVisibleFraction: 0.5, centerMode: .always)

        XCTAssertNotEqual(fixture.viewStart, 0, accuracy: 0.001)
    }

    func testFocusNavigationUsesEngineThresholdWhileOtherSelectionChangesStillFit() {
        var focused = Fixture()
        focused.engine.updateConfiguration(keepViewportMinVisible: 0.9)
        let context = focused.context
        focused.engine.ensureSelectionVisible(
            node: focused.windows[1],
            context: context,
            state: &focused.state,
            keepsMostlyVisibleViewport: true
        )
        XCTAssertEqual(focused.state.activeColumnIndex, 1)
        XCTAssertEqual(focused.viewStart, 0, accuracy: 0.001)

        var moved = Fixture()
        moved.engine.updateConfiguration(keepViewportMinVisible: 0.9)
        moved.engine.ensureSelectionVisible(node: moved.windows[1], context: moved.context, state: &moved.state)
        XCTAssertEqual(moved.viewStart, 22, accuracy: 0.001)
    }

    func testSettingDefaultsToFullVisibilityAndClampsDecodedValues() throws {
        let canonical = try XCTUnwrap(String(data: SettingsTOMLCodec.encode(.defaults()), encoding: .utf8))
        XCTAssertTrue(canonical.contains("keepViewportMinVisible = 1.0"))

        let missing = canonical.replacingOccurrences(of: "keepViewportMinVisible = 1.0\n", with: "")
        XCTAssertNil(try SettingsTOMLCodec.decode(Data(missing.utf8)).niri.keepViewportMinVisible)

        let settings = NiriSettings()
        var niri = SettingsExport.Niri.defaults()
        niri.keepViewportMinVisible = 1.7
        settings.apply(niri, baseline: .defaults())
        XCTAssertEqual(settings.keepViewportMinVisible, 1.0)
        niri.keepViewportMinVisible = 0.9
        settings.apply(niri, baseline: .defaults())
        XCTAssertEqual(settings.keepViewportMinVisible, 0.9)
        niri.keepViewportMinVisible = nil
        settings.apply(niri, baseline: .defaults())
        XCTAssertEqual(settings.keepViewportMinVisible, 1.0)
    }
}
