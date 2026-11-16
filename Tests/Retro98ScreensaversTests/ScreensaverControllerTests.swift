import Testing
import AppKit
@testable import Retro98Screensavers
import Retro98Settings

@MainActor
@Test func controllerStartsNotShowing() {
    let ctrl = ScreensaverController(choices: { .standard }, window: ScreensaverWindow())
    #expect(!ctrl.isShowing)
}

@MainActor
@Test func controllerDoesNotShowWhenKindIsNone() {
    let choices = Choices.standard.with(screensaver: .none).with(screensaverTimeout: 0)
    let ctrl = ScreensaverController(choices: { choices }, window: ScreensaverWindow())
    ctrl.presentsWindows = false
    ctrl.overrideIdleSeconds = 999
    ctrl.fireIdleCheckForTesting()
    #expect(!ctrl.isShowing)
}

@MainActor
@Test func controllerShowsWhenIdleExceedsTimeout() {
    let choices = Choices.standard.with(screensaver: .pipes).with(screensaverTimeout: 0)
    let ctrl = ScreensaverController(choices: { choices }, window: ScreensaverWindow())
    ctrl.presentsWindows = false
    ctrl.overrideIdleSeconds = 999
    ctrl.fireIdleCheckForTesting()
    #expect(ctrl.isShowing)
}

@MainActor
@Test func controllerDismisses() {
    let choices = Choices.standard.with(screensaver: .pipes).with(screensaverTimeout: 0)
    let ctrl = ScreensaverController(choices: { choices }, window: ScreensaverWindow())
    ctrl.presentsWindows = false
    ctrl.overrideIdleSeconds = 999
    ctrl.fireIdleCheckForTesting()
    ctrl.dismissForTesting()
    #expect(!ctrl.isShowing)
}

@MainActor
@Test func controllerDoesNotShowTwice() {
    let choices = Choices.standard.with(screensaver: .pipes).with(screensaverTimeout: 0)
    let ctrl = ScreensaverController(choices: { choices }, window: ScreensaverWindow())
    ctrl.presentsWindows = false
    ctrl.overrideIdleSeconds = 999
    ctrl.fireIdleCheckForTesting()
    ctrl.fireIdleCheckForTesting()
    #expect(ctrl.isShowing)
    #expect(ctrl.showCount == 1)
}
