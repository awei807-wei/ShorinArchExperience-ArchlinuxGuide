import QtQuick
import Quickshell
import "."

ShellRoot {
    id: testRoot

    property int failureCount: 0
    property int submitCount: 0
    property int editedCount: 0
    property int escapeCount: 0

    function expect(condition, label) {
        if (condition)
            return
        failureCount += 1
        console.error("[LockscreenAuthLayoutCheck] failed: " + label)
    }

    function expectEqual(actual, expected, label) {
        expect(actual === expected,
               label + ": expected=" + expected + " actual=" + actual)
    }

    function expectNear(actual, expected, label) {
        expect(Math.abs(actual - expected) < 0.01,
               label + ": expected=" + expected + " actual=" + actual)
    }

    function runChecks() {
        const initialHeight = auth.height
        const field = auth.credentialFieldItem
        const submit = auth.submitButtonItem
        const input = auth.passwordInputItem
        const submitOrigin = submit.mapToItem(field, 0, 0)
        const inputOrigin = input.mapToItem(field, 0, 0)

        expectEqual(auth.width, auth.credentialWidth,
                    "authentication width")
        expectEqual(field.height, auth.credentialHeight,
                    "credential field height")
        expect(field.radius > 0, "credential field has rounded corners")
        expect(submit.radius > 0, "embedded submit has rounded corners")
        expect(submitOrigin.x >= 0 && submitOrigin.y >= 0,
               "embedded submit starts inside credential field")
        expect(submitOrigin.x + submit.width <= field.width,
               "embedded submit stays within credential field width")
        expect(submitOrigin.y + submit.height <= field.height,
               "embedded submit stays within credential field height")
        expect(inputOrigin.x + input.width <= submitOrigin.x,
               "password input does not overlap embedded submit")

        auth.clearPassword()
        auth.pamActive = false
        auth.focusPasswordField()
        expect(input.focus, "password input requests initial focus")
        expect(auth.placeholderItem.visible,
               "placeholder remains visible for focused empty input")

        auth.passwordText = "secret"
        expect(!auth.placeholderItem.visible,
               "placeholder hides after password input")
        auth.clearPassword()

        auth.pamActive = true
        expect(!input.enabled, "PAM busy disables password input")
        expect(!submit.enabled, "PAM busy disables embedded submit")
        expect(!auth.placeholderItem.visible,
               "PAM busy hides password placeholder")
        expectNear(auth.height, initialHeight,
                   "PAM busy preserves authentication height")

        auth.pamActive = false
        auth.authFailed = true
        auth.authStatusText = "密码错误"
        auth.triggerErrorWobble()
        expectNear(auth.statusSlotItem.height, auth.statusSlotHeight,
                   "status slot keeps fixed height")
        expectNear(auth.height, initialHeight,
                   "error state preserves authentication height")

        auth.authFailed = false
        auth.authStatusText = ""
        expectNear(auth.statusSlotItem.height, auth.statusSlotHeight,
                   "empty status keeps reserved height")
        expectNear(auth.height, initialHeight,
                   "empty status preserves authentication height")

        expectEqual(submitCount, 0,
                    "no submit side effect on construction")
        expectEqual(editedCount, 0,
                    "no edit side effect on construction")
        expectEqual(escapeCount, 0,
                    "no escape side effect on construction")

        if (failureCount === 0) {
            console.log("[LockscreenAuthLayoutCheck] PASS")
            Qt.exit(0)
        } else {
            console.error("[LockscreenAuthLayoutCheck] FAIL count="
                          + failureCount)
            Qt.exit(1)
        }
    }

    LockscreenAuth {
        id: auth

        username: "shiyi"
        reducedMotion: true
        onSubmitRequested: testRoot.submitCount += 1
        onPasswordEdited: testRoot.editedCount += 1
        onEscapeRequested: testRoot.escapeCount += 1
    }

    Timer {
        interval: 0
        running: true
        onTriggered: Qt.callLater(testRoot.runChecks)
    }
}
