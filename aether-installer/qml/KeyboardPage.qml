import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import AetherInstaller

PageBase {
    pageIndex: 2
    title: "Your keyboard"
    subtitle: "Choose a keyboard layout and test typing."

    Card {
        anchors.fill: parent
        Entrance { order: 3 }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 26
            spacing: 14

            AetherCombo {
                Layout.fillWidth: true
                label: "Keyboard layout"
                options: Setup.keyboardOptions
                value: Setup.selectedKeyboard
                onPicked: function (v) { Setup.selectedKeyboard = v }
            }

            AetherField {
                Layout.fillWidth: true
                label: "Test your typing"
                placeholderText: "Type a few characters here…"
                text: Setup.keyboardTestText
                onEdited: function (t) { Setup.keyboardTestText = t }
                onKeyTyped: function (k) { preview.press(k) }
            }

            KeyboardPreview {
                id: preview
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                layoutName: Setup.selectedKeyboard
            }

            Item { Layout.fillHeight: true }

            Label {
                Layout.fillWidth: true
                text: "This layout becomes the console keyboard layout on the installed system."
                color: Theme.subtleText
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }
        }
    }
}
