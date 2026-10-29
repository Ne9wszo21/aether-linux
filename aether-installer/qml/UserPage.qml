import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import AetherInstaller

PageBase {
    pageIndex: 4
    title: "Create your account"
    subtitle: "Enter account details. They are checked locally and never shown in the summary."

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: formCard.implicitHeight + 8
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}

        Card {
            id: formCard
            width: flick.width
            implicitHeight: grid.implicitHeight + 52
            height: implicitHeight
            Entrance { order: 3 }

            GridLayout {
                id: grid
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 26
                columns: 2
                columnSpacing: 22
                rowSpacing: 4

                AetherField {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    label: "Full name"
                    placeholderText: "Your name"
                    text: Setup.fullName
                    error: Setup.errFullName
                    onEdited: function (t) { Setup.setFullName(t) }
                }
                AetherField {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    label: "Username"
                    placeholderText: "username"
                    text: Setup.username
                    error: Setup.errUsername
                    onEdited: function (t) { Setup.setUsername(t) }
                }
                AetherField {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    label: "Computer name"
                    placeholderText: "aether"
                    text: Setup.hostname
                    error: Setup.errHostname
                    onEdited: function (t) { Setup.hostname = t }
                }
                Item { Layout.fillWidth: true; Layout.preferredWidth: 1 }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    spacing: 0
                    AetherField {
                        Layout.fillWidth: true
                        label: "Password"
                        placeholderText: Setup.requireStrongPassword ? "8+ characters, strong" : "Any password"
                        password: true
                        text: Setup.password
                        error: Setup.errPassword
                        onEdited: function (t) { Setup.password = t }
                    }

                    // strength meter
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: -6
                        spacing: 6
                        opacity: Setup.passwordScore >= 0 ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: Theme.durMedium } }

                        Repeater {
                            model: 4
                            delegate: Rectangle {
                                id: seg
                                required property int index
                                readonly property int lit: Math.max(1, Setup.passwordScore)
                                Layout.fillWidth: true
                                Layout.preferredHeight: 4
                                radius: 2
                                color: Theme.outline
                                Rectangle {
                                    height: parent.height
                                    radius: 2
                                    width: seg.index < seg.lit ? parent.width : 0
                                    color: Setup.scoreColors[Math.max(0, Setup.passwordScore)]
                                    Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                                    Behavior on color { ColorAnimation { duration: 260 } }
                                }
                            }
                        }
                        Label {
                            text: Setup.passwordScore >= 0 ? Setup.scoreLabels[Setup.passwordScore] : ""
                            color: Setup.scoreColors[Math.max(0, Setup.passwordScore)]
                            font.pixelSize: 11
                            Layout.preferredWidth: 60
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }

                AetherField {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    label: "Confirm password"
                    placeholderText: "Repeat password"
                    password: true
                    last: true
                    text: Setup.passwordConfirm
                    error: Setup.errConfirm
                    onEdited: function (t) { Setup.passwordConfirm = t }
                    onSubmitted: Setup.next()
                }

                Switch {
                    Layout.columnSpan: 2
                    text: "Require a strong password (at least 8 characters)"
                    checked: Setup.requireStrongPassword
                    onToggled: Setup.requireStrongPassword = checked
                }

                Label {
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    text: "These details are used to create your account during installation. They are never shown in the summary."
                    color: Theme.subtleText
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
