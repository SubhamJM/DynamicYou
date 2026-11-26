import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

Scope {
    id: root

    signal shouldReFocus()
    signal unlocked()
    signal failed()

    property string currentText: ""
    property bool unlockInProgress: false
    property bool showFailure: false
    property bool fingerprintsConfigured: false
    readonly property string username: Quickshell.env("USER") || "kuro"

    function clearText(): void {
        root.currentText = "";
    }

    function resetClearTimer(): void {
        passwordClearTimer.restart();
    }

    function reset(): void {
        root.clearText();
        root.showFailure = false;
        root.unlockInProgress = false;
        stopFingerPam();
        if (LockConfig.locked) Qt.callLater(root.tryFingerUnlock);
    }

    Timer {
        id: passwordClearTimer
        interval: 10000
        onTriggered: root.clearText()
    }

    onCurrentTextChanged: {
        if (currentText.length > 0) showFailure = false;
        passwordClearTimer.restart();
    }

    function tryUnlock(): void {
        if (root.unlockInProgress) return;
        root.unlockInProgress = true;
        pamTimeoutTimer.restart();
        pam.start();
    }

    Timer {
        id: pamTimeoutTimer
        interval: 10000
        onTriggered: {
            if (root.unlockInProgress) {
                console.warn("[IrisLockContext] PAM timeout");
                root.unlockInProgress = false;
                root.showFailure = true;
                root.failed();
            }
        }
    }

    function tryFingerUnlock(): void {
        if (!LockConfig.locked || !root.fingerprintsConfigured || fingerPam.active) return;
        fingerprintRetryTimer.stop();
        if (!fingerPam.start()) fingerprintRetryTimer.restart();
    }

    function stopFingerPam(): void {
        fingerprintRetryTimer.stop();
        if (fingerPam.active) fingerPam.abort();
    }

    Timer {
        id: fingerprintRetryTimer
        interval: 800
        repeat: false
        onTriggered: root.tryFingerUnlock()
    }

    Process {
        id: fingerprintCheckProc
        running: true
        command: ["bash", "-c", "command -v fprintd-list >/dev/null && fprintd-list \"$(whoami)\" 2>/dev/null || exit 1"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.fingerprintsConfigured = /(^|\n)\s*-\s+#\d+:/.test(text);
                if (root.fingerprintsConfigured && LockConfig.locked) Qt.callLater(root.tryFingerUnlock);
            }
        }
        onExited: (exitCode) => {
            if (exitCode !== 0) root.fingerprintsConfigured = false;
        }
    }

    PamContext {
        id: pam
        config: "login"
        user: root.username

        onPamMessage: {
            if (this.responseRequired) {
                this.respond(root.currentText);
            }
        }

        onCompleted: result => {
            pamTimeoutTimer.stop();
            if (result === PamResult.Success) {
                root.unlockInProgress = false;
                stopFingerPam();
                root.unlocked();
            } else {
                root.clearText();
                root.unlockInProgress = false;
                root.showFailure = true;
                root.failed();
                root.shouldReFocus();
            }
        }

        onError: {
            pamTimeoutTimer.stop();
            root.clearText();
            root.unlockInProgress = false;
            root.showFailure = true;
            root.failed();
        }
    }

    PamContext {
        id: fingerPam
        configDirectory: Quickshell.shellPath("modules/common/panels/lock/pam")
        config: "fprintd.conf"
        user: root.username

        onCompleted: result => {
            if (result === PamResult.Success) {
                fingerprintRetryTimer.stop();
                root.unlocked();
            } else if (LockConfig.locked && root.fingerprintsConfigured) {
                fingerprintRetryTimer.restart();
            }
        }
    }
}
