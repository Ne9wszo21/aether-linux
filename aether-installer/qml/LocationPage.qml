import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import AetherInstaller

PageBase {
    pageIndex: 1
    title: "Where are you?"
    subtitle: "Choose your region and time zone preferences."

    RowLayout {
        anchors.fill: parent
        spacing: 24

        Card {
            Layout.fillWidth: true
            Layout.preferredHeight: 330
            Layout.alignment: Qt.AlignTop
            Entrance { order: 3 }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 26
                spacing: 16

                AetherCombo {
                    Layout.fillWidth: true
                    label: "Region"
                    options: Setup.regionOptions
                    value: Setup.selectedRegion
                    onPicked: function (v) { Setup.pickRegion(v) }
                }

                AetherCombo {
                    Layout.fillWidth: true
                    label: "Time zone"
                    options: Setup.timeZoneOptions
                    value: Setup.selectedTimeZone
                    onPicked: function (v) { Setup.selectedTimeZone = v }
                }

                Rectangle {
                    Layout.preferredHeight: 30
                    Layout.preferredWidth: offsetLabel.implicitWidth + 28
                    radius: 15
                    color: Qt.rgba(0.42, 0.84, 0.90, 0.10)
                    border.color: Qt.rgba(0.42, 0.84, 0.90, 0.4)
                    Label {
                        id: offsetLabel
                        anchors.centerIn: parent
                        text: Setup.zoneOffsets[Setup.selectedTimeZone]
                        color: Theme.primary
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                }

                Item { Layout.fillHeight: true }

                Label {
                    Layout.fillWidth: true
                    text: "These settings are applied to the new system during installation."
                    color: Theme.subtleText
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }
            }
        }

        OrbitGlobe {
            Layout.preferredWidth: 250
            Layout.preferredHeight: 250
            Layout.alignment: Qt.AlignTop
            Entrance { order: 4; distance: 0 }
        }
    }
}
