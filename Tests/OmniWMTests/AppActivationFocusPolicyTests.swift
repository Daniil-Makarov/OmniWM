// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 OmniNull — https://github.com/OmniNull/OmniWM

import Foundation
@testable import OmniWM
import XCTest

@MainActor
final class AppActivationFocusPolicyTests: XCTestCase {
    func testExternalActivationOnInactiveWorkspaceSwitchesWorkspaceByDefault() async throws {
        let fixture = try await Fixture()
        defer { fixture.stop() }

        await fixture.activateBackgroundApp()

        XCTAssertEqual(fixture.controller.activeWorkspace()?.id, fixture.backgroundWorkspaceId)
        XCTAssertEqual(fixture.controller.workspaceManager.selectedManagedToken, fixture.backgroundToken)
    }

    func testExternalActivationOnInactiveWorkspaceKeepsWorkspaceWhenNotFollowing() async throws {
        let fixture = try await Fixture()
        defer { fixture.stop() }
        fixture.controller.settings.focus.followsAppActivation = false

        await fixture.activateBackgroundApp()

        XCTAssertEqual(fixture.controller.activeWorkspace()?.id, fixture.visibleWorkspaceId)
        XCTAssertEqual(fixture.controller.workspaceManager.selectedManagedToken, fixture.visibleToken)
        XCTAssertFalse(fixture.focusRequests.values.isEmpty)
        XCTAssertEqual(Set(fixture.focusRequests.values), [fixture.visibleToken])
    }

    func testFollowsAppActivationDefaultsToTrueWhenMissingAndRoundTrips() throws {
        let canonical = try XCTUnwrap(String(data: SettingsTOMLCodec.encode(.defaults()), encoding: .utf8))
        XCTAssertTrue(canonical.contains("followsAppActivation = true"))

        let missing = canonical.replacingOccurrences(of: "followsAppActivation = true\n", with: "")
        XCTAssertTrue(try SettingsTOMLCodec.decode(Data(missing.utf8)).focus.followsAppActivation)

        var export = SettingsExport.defaults()
        export.focus.followsAppActivation = false
        XCTAssertFalse(try SettingsTOMLCodec.decode(SettingsTOMLCodec.encode(export)).focus.followsAppActivation)
    }
}

@MainActor
private struct Fixture {
    let controller: WMController
    let visibleWorkspaceId: WorkspaceDescriptor.ID
    let backgroundWorkspaceId: WorkspaceDescriptor.ID
    let visibleToken = WindowToken(pid: 520_101, windowId: 520_102)
    let backgroundToken = WindowToken(pid: 520_111, windowId: 520_112)
    let focusRequests = FocusRequestRecorder()

    init() async throws {
        let focusRequests = focusRequests
        controller = WindowAdmissionTestSupport.controller(
            prefix: "OmniWMAppActivationFocusPolicyTests",
            windowFocusOperations: WindowFocusOperations(
                activateApp: { _ in },
                focusSpecificWindow: { pid, windowId, _ in
                    focusRequests.values.append(WindowToken(pid: pid, windowId: Int(windowId)))
                },
                raiseWindow: { _ in }
            )
        )
        let manager = controller.workspaceManager
        visibleWorkspaceId = try XCTUnwrap(manager.workspaceId(for: "1", createIfMissing: true))
        backgroundWorkspaceId = try XCTUnwrap(manager.workspaceId(for: "2", createIfMissing: true))
        _ = manager.focusWorkspace(id: visibleWorkspaceId)
        _ = WindowAdmissionTestSupport.track(visibleToken, in: visibleWorkspaceId, controller: controller)
        _ = WindowAdmissionTestSupport.track(backgroundToken, in: backgroundWorkspaceId, controller: controller)
        XCTAssertTrue(manager.confirmManagedFocus(
            visibleToken,
            in: visibleWorkspaceId,
            activateWorkspaceOnMonitor: false
        ))
        controller.motionPolicy.animationsEnabled = false
        controller.niriLayoutHandler.enableNiriLayout()
        await WindowAdmissionTestSupport.drainLayoutRefreshes(controller)
        controller.layoutRefreshController.layoutState.hasCompletedInitialRefresh = true
        XCTAssertEqual(manager.selectedManagedToken, visibleToken)
        XCTAssertEqual(controller.activeWorkspace()?.id, visibleWorkspaceId)
    }

    func activateBackgroundApp() async {
        let backgroundToken = backgroundToken
        controller.factResolver.factProvider = { pid in
            guard pid == backgroundToken.pid else { return nil }
            return FocusedWindowFact(
                axRef: WindowAdmissionTestSupport.axRef(for: backgroundToken),
                isFullscreen: false,
                isSystemModalSurface: false
            )
        }
        controller.axEventHandler.frontmostApplicationPIDProvider = { backgroundToken.pid }
        controller.eventIntake.open(sink: controller.eventInterpreter)
        controller.hasStartedServices = true
        controller.axEventHandler.handleAppActivation(pid: backgroundToken.pid)
        controller.eventIntake.drainNow()
        controller.eventIntake.drainNow()
        await WindowAdmissionTestSupport.drainLayoutRefreshes(controller)
    }

    func stop() {
        controller.hasStartedServices = false
        controller.factResolver.stop()
        controller.eventIntake.close()
        controller.deadlineWheel.stop()
        controller.layoutRefreshController.resetState()
    }
}

@MainActor
private final class FocusRequestRecorder {
    var values: [WindowToken] = []
}
