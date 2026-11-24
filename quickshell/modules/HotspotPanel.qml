import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../"

ColumnLayout {
    id: panel
    required property var hotspot
    spacing: 8

    readonly property string networkName: nameField.text.trim()
    readonly property bool validPassword: /^[ -~]{8,63}$/.test(passwordField.text) || /^[0-9a-fA-F]{64}$/.test(passwordField.text)
    readonly property bool validCredentials: networkName !== "" && validPassword
    readonly property bool edited: networkName !== hotspot.ssid || passwordField.text !== hotspot.password
    readonly property bool editable: hotspot.ready && !hotspot.busy

    function credentials() {
        return { ssid: networkName, password: passwordField.text };
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 62
        radius: 12
        color: Theme.surfaceHigh

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: 10
                color: panel.hotspot.active ? Theme.primaryContainer : Theme.surfaceHighest

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "wifi_tethering"
                    iconSize: 19
                    color: panel.hotspot.active ? Theme.fgPrimaryContainer : Theme.subtext
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: "Personal Hotspot"
                    color: Theme.text
                    font.family: Theme.fontFamilyBody
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.fillWidth: true
                    text: {
                        if (panel.hotspot.busy) return "Updating hotspot…";
                        if (!panel.hotspot.ready) return panel.hotspot.statusError ? "Unavailable" : "Checking status…";
                        if (!panel.hotspot.active) return "Off";
                        const count = panel.hotspot.clients;
                        return count === null ? "Broadcasting" : count + (count === 1 ? " device connected" : " devices connected");
                    }
                    color: Theme.subtext
                    font.family: Theme.fontFamilyBody
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }

            ConnectivityToggle {
                powered: panel.hotspot.active
                enabled: panel.editable && (panel.hotspot.active || (panel.validCredentials && panel.hotspot.sharingAvailable))
                Accessible.name: "Personal Hotspot"
                onClicked: {
                    if (panel.hotspot.active) panel.hotspot.request("stop");
                    else panel.hotspot.request("start", panel.credentials());
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: fields.implicitHeight + 24
        radius: 12
        color: Theme.surfaceHigh

        ColumnLayout {
            id: fields
            anchors.fill: parent
            anchors.topMargin: 12
            anchors.bottomMargin: 12
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 6

            FieldLabel { text: "Network name" }
            SettingsField {
                id: nameField
                text: panel.hotspot.ssid
                placeholderText: "Hotspot name"
                Accessible.name: "Network name"
            }

            FieldLabel {
                Layout.topMargin: 4
                text: "Password"
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                SettingsField {
                    id: passwordField
                    text: panel.hotspot.password
                    echoMode: reveal.checked ? TextInput.Normal : TextInput.Password
                    placeholderText: "8–63 characters"
                    Accessible.name: "Hotspot password"
                }

                Button {
                    id: reveal
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    padding: 0
                    checkable: true
                    enabled: panel.editable
                    hoverEnabled: true
                    Accessible.name: checked ? "Hide password" : "Show password"
                    ToolTip.visible: hovered
                    ToolTip.text: Accessible.name
                    background: Rectangle {
                        radius: 8
                        color: reveal.hovered || reveal.checked ? Theme.surfaceHighest : Theme.bg
                    }
                    contentItem: Item {
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: reveal.checked ? "visibility_off" : "visibility"
                            iconSize: 15
                            color: Theme.subtext
                        }
                    }
                }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        visible: text !== ""
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        text: {
            if (panel.hotspot.statusError) return panel.hotspot.statusError;
            if (panel.hotspot.feedback) return panel.hotspot.feedback;
            if (!panel.hotspot.sharingAvailable) return "Install dnsmasq to share your connection.";
            if (passwordField.text !== "" && !panel.validPassword) return "Use 8–63 printable ASCII characters or 64 hex digits.";
            return "";
        }
        color: panel.hotspot.statusError || panel.hotspot.operationFailed ? Theme.error : Theme.subtext
        font.family: Theme.fontFamilyBody
        font.pixelSize: 11
    }

    Button {
        id: saveButton
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        padding: 0
        text: "Save Settings"
        enabled: panel.editable && panel.edited && panel.validCredentials
        background: Rectangle {
            radius: 8
            color: saveButton.enabled ? Theme.accent : Theme.surfaceHigh
        }
        contentItem: Text {
            text: saveButton.text
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: saveButton.enabled ? Theme.fgPrimary : Theme.subtext
            font.family: Theme.fontFamilyBody
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }
        onClicked: panel.hotspot.request("set-config", panel.credentials())
    }

    component FieldLabel: Text {
        color: Theme.subtext
        font.family: Theme.fontFamilyBody
        font.pixelSize: 11
        font.weight: Font.DemiBold
    }

    component SettingsField: TextField {
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        readOnly: !panel.editable
        selectByMouse: true
        leftPadding: 10
        rightPadding: 10
        font.family: Theme.fontFamilyBody
        font.pixelSize: 12
        color: Theme.text
        placeholderTextColor: Theme.subtext
        selectionColor: Theme.accent
        selectedTextColor: Theme.fgPrimary
        onTextEdited: panel.hotspot.feedback = ""
        background: Rectangle {
            radius: 8
            color: parent.activeFocus ? Theme.surfaceHighest : Theme.bg
        }
    }
}
