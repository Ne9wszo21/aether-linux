import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import AetherInstaller

ApplicationWindow {
    id: window
    width: 1120
    height: 720
    minimumWidth: 900
    minimumHeight: 660
    visible: true
    title: "Aether Installer"
    color: Theme.background
    Material.theme: Material.Dark
    Material.accent: Theme.primary

    onClosing: function (close) { if (SystemInstaller.running) close.accepted = false }

    Shortcut { sequences: ["Alt+Right"]; onActivated: Setup.next() }
    Shortcut { sequences: ["Alt+Left"]; onActivated: Setup.back() }

    Backdrop { anchors.fill: parent }

    Item {
        id: shell
        anchors.fill: parent
        opacity: 0.0
        NumberAnimation on opacity { from: 0.0; to: 1.0; duration: 700; easing.type: Easing.OutCubic }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            Sidebar {
                Layout.preferredWidth: 264
                Layout.fillHeight: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                Item {
                    id: pageHost
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    WelcomePage {}
                    LocationPage {}
                    KeyboardPage {}
                    DiskPage {}
                    UserPage {}
                    SummaryPage {}
                    InstallPage {}
                    DonePage {}
                }

                // Footer: progress, step count, navigation
                Item {
                    id: footer
                    Layout.fillWidth: true
                    Layout.preferredHeight: 84
                    opacity: Setup.currentPage < Setup.installPage ? 1.0 : 0.0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 300 } }

                    Rectangle {
                        id: track
                        x: 56
                        width: parent.width - 112
                        height: 4
                        radius: 2
                        color: Theme.outline

                        Rectangle {
                            height: parent.height
                            radius: 2
                            color: Theme.primary
                            width: parent.width * (Setup.currentPage + 1) / Setup.pageNames.length
                            Behavior on width { NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 56
                        anchors.rightMargin: 56
                        anchors.topMargin: 6
                        spacing: 12

                        Label {
                            text: "Step " + (Math.min(Setup.currentPage, Setup.lastStep) + 1) + " of " + Setup.pageNames.length
                            color: Theme.mutedText
                            font.pixelSize: 12
                        }

                        Label {
                            text: "Alt + ← →"
                            color: Theme.subtleText
                            font.pixelSize: 11
                            font.letterSpacing: 0.5
                        }

                        Item { Layout.fillWidth: true }

                        AetherButton {
                            text: "Back"
                            kind: "text"
                            visible: Setup.currentPage > 0
                            onClicked: Setup.back()
                        }

                        AetherButton {
                            text: Setup.nextLabel
                            onClicked: Setup.next()
                        }
                    }
                }
            }
        }
    }
}
