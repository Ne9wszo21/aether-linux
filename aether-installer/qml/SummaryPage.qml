import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import AetherInstaller

PageBase {
    id: page
    pageIndex: 5
    title: "Ready when you are"
    subtitle: "Review everything. Nothing is written to disk until you confirm below and press Install."

    readonly property var rows: [
        { label: "Region", value: Setup.selectedRegion, page: 1 },
        { label: "Time zone", value: Setup.selectedTimeZone, page: 1 },
        { label: "Keyboard", value: Setup.selectedKeyboard, page: 2 },
        { label: "Install mode", value: Setup.modeLabel, page: 3 },
        { label: "Drive", value: Setup.driveSummary, page: 3 },
        { label: "Full name", value: Setup.fullName.length ? Setup.fullName : "Not set", page: 4 },
        { label: "Username", value: Setup.username.length ? Setup.username : "Not set", page: 4 },
        { label: "Computer name", value: Setup.hostname, page: 4 },
        { label: "Password", value: Setup.password.length ? "Set (hidden)" : "Not set", page: 4 }
    ]

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 120
            clip: true
            Entrance { order: 3 }

            ListView {
                id: list
                anchors.fill: parent
                anchors.margins: 14
                clip: true
                model: page.rows
                ScrollBar.vertical: ScrollBar {}
                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: 40

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 1
                        color: Theme.outline
                        opacity: row.index < list.count - 1 ? 0.7 : 0
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 16
                        Label {
                            Layout.preferredWidth: 140
                            text: row.modelData.label
                            color: Theme.mutedText
                            font.pixelSize: 13
                        }
                        Label {
                            Layout.fillWidth: true
                            text: row.modelData.value
                            color: row.modelData.value.indexOf("Not ") === 0 ? Theme.warning : Theme.text
                            font.pixelSize: 14
                            elide: Text.ElideRight
                        }
                        Label {
                            text: "Edit"
                            color: edit.containsMouse ? Theme.primaryHover : Theme.primary
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            MouseArea {
                                id: edit
                                anchors.fill: parent
                                anchors.margins: -8
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Setup.go(row.modelData.page)
                            }
                        }
                    }
                }
            }
        }

        Card {
            id: confirmCard
            Layout.fillWidth: true
            Layout.preferredHeight: confirmRow.implicitHeight + 24
            radius: 18
            color: Theme.surfaceRaised
            border.color: Setup.confirmErase ? Theme.primary
                : (Setup.showConfirmError ? Theme.error : Theme.outline)
            Behavior on border.color { ColorAnimation { duration: Theme.durMedium } }
            Entrance { order: 4 }

            RowLayout {
                id: confirmRow
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                CheckBox {
                    checked: Setup.confirmErase
                    onToggled: Setup.confirmErase = checked
                }

                Label {
                    Layout.fillWidth: true
                    text: Setup.confirmText
                    color: Theme.text
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }
            }
        }

        InfoBanner {
            Layout.fillWidth: true
            tone: SystemInstaller.dryRun ? Theme.warning : Theme.primary
            text: SystemInstaller.dryRun
                ? "Dry run: commands are shown but nothing is written to disk."
                : "Needs an internet connection. The install takes a few minutes and cannot be paused."
        }
    }
}
