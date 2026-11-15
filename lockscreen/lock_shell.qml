import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtMultimedia
import "./shim"

ShellRoot {
    id: shellRoot

    property string themesDir: Quickshell.shellDir + "/themes"
    property string activeTheme: {
        var envTheme = Quickshell.env("QS_THEME");
        if (envTheme && envTheme.trim() !== "") return envTheme.trim();
        return "dog-samurai";
    }
    readonly property string themePath: shellRoot.themesDir + "/" + shellRoot.activeTheme

    readonly property var sddm: sddmShim.sddm
    readonly property var config: sddmShim.config
    readonly property var userModel: sddmShim.userModel
    readonly property var sessionModel: sddmShim.sessionModel
    readonly property var keyboard: sddmShim.keyboard

    readonly property bool isTesting: Quickshell.env("QS_TESTING") === "1"
    property bool authenticated: false
    property bool sessionLocked: true
    property bool unlocking: false

    SddmShim {
        id: sddmShim
        themePath: shellRoot.themePath
    }

    // Persist theme selection
    Process {
        id: themeWriter
        running: false
        property string targetTheme: ""
        command: ["bash", "-c", "mkdir -p ~/.config/qylock && echo '" + targetTheme + "' > ~/.config/qylock/theme"]
    }

    function switchTheme(newThemeId) {
        if (!newThemeId || shellRoot.activeTheme === newThemeId) return;
        shellRoot.activeTheme = newThemeId;
        themeWriter.targetTheme = newThemeId;
        themeWriter.running = true;
    }

    Connections {
        target: sddmShim.sddm
        function onLoginSucceeded() {
            shellRoot.authenticated = true;
            shellRoot.unlocking = true;

            // Hyprland session lock fix
            Quickshell.execDetached(["hyprctl", "keyword", "misc:allow_session_lock_restore", "1"]);
            Quickshell.execDetached(["loginctl", "unlock-session"]);

            // Step 1: release Wayland session lock after smooth fade animation
            unlockTimer.start();
        }
    }

    // Gracefully unlock ext-session-lock-v1 after smooth 400ms fade-out
    Timer {
        id: unlockTimer
        interval: 420
        onTriggered: {
            shellRoot.sessionLocked = false;
            exitTimer.start();
        }
    }

    // Cleanly terminate quickshell lock process after compositor receives unlock
    Timer {
        id: exitTimer
        interval: 200
        onTriggered: {
            Quickshell.execDetached(["kill", "-9", Quickshell.processId.toString()]);
        }
    }

    Component {
        id: themeComponent
        Loader {
            id: mainLoader
            anchors.fill: parent
            source: "file://" + shellRoot.themePath + "/Main.qml"
            
            onLoaded: {
                if (item) item.forceActiveFocus();
            }
            onStatusChanged: {
                if (status === Loader.Error) {
                    console.error("FAILED to load lockscreen theme:", source);
                }
            }
        }
    }

    // Wayland ext-session-lock-v1 protocol handler
    Loader {
        id: waylandLoader
        active: !shellRoot.isTesting
        sourceComponent: Component {
            WlSessionLock {
                id: lock
                locked: shellRoot.sessionLocked
                surface: Component {
                    WlSessionLockSurface {
                        id: lockSurface
                        color: "transparent"
                        
                        // Absorb unhandled gestures
                        PinchHandler { target: null }
                        WheelHandler { target: null }
                        
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.AllButtons
                            hoverEnabled: true
                            onWheel: (wheel) => { wheel.accepted = true }
                        }

                        // Smoothly animated container on unlock
                        Item {
                            id: lockContent
                            anchors.fill: parent
                            transformOrigin: Item.Center
                            opacity: shellRoot.unlocking ? 0.0 : 1.0
                            scale: shellRoot.unlocking ? 1.05 : 1.0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 400
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 400
                                    easing.type: Easing.OutCubic
                                }
                            }

                            // Loaded Theme Background & SDDM UI
                            Loader {
                                id: themeLoader
                                anchors.fill: parent
                                sourceComponent: themeComponent
                            }

                            // In-Lockscreen Theme Switcher Overlay
                            LockscreenSwitcherOverlay {
                                id: inLockSwitcher
                                anchors.fill: parent
                                currentTheme: shellRoot.activeTheme
                                themesDir: shellRoot.themesDir
                                onThemeSelected: (themeId) => {
                                    shellRoot.switchTheme(themeId);
                                }
                                onRequestFocusBack: {
                                    if (themeLoader.item) {
                                        themeLoader.item.forceActiveFocus();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Windowed Test Mode (QS_TESTING=1)
    Loader {
        id: testLoader
        active: shellRoot.isTesting
        sourceComponent: Component {
            Variants {
                model: Quickshell.screens
                delegate: Window {
                    id: testWindow
                    required property var modelData
                    width: 1280
                    height: 720
                    visible: true
                    visibility: Window.Windowed
                    flags: Qt.FramelessWindowHint
                    color: "transparent"

                    onClosing: (close) => {
                        close.accepted = true;
                        Quickshell.execDetached(["kill", "-9", Quickshell.processId.toString()]);
                    }

                    Item {
                        id: testContent
                        anchors.fill: parent
                        transformOrigin: Item.Center
                        opacity: shellRoot.unlocking ? 0.0 : 1.0
                        scale: shellRoot.unlocking ? 1.05 : 1.0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 400
                                easing.type: Easing.OutCubic
                            }
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: 400
                                easing.type: Easing.OutCubic
                            }
                        }

                        Loader {
                            id: testThemeLoader
                            anchors.fill: parent
                            sourceComponent: themeComponent
                        }

                        LockscreenSwitcherOverlay {
                            id: testLockSwitcher
                            anchors.fill: parent
                            currentTheme: shellRoot.activeTheme
                            themesDir: shellRoot.themesDir
                            onThemeSelected: (themeId) => {
                                shellRoot.switchTheme(themeId);
                            }
                            onRequestFocusBack: {
                                if (testThemeLoader.item) {
                                    testThemeLoader.item.forceActiveFocus();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
