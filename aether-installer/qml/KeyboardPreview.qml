import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import AetherInstaller

// On-screen keyboard that lights up the key you press.
Item {
    id: root
    property string layoutName: "English (US)"
    property string lastKey: ""

    readonly property var rows: {
        if (layoutName === "German")
            return ["qwertzuiop", "asdfghjkl", "yxcvbnm"]
        if (layoutName === "French")
            return ["azertyuiop", "qsdfghjklm", "wxcvbn"]
        return ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
    }

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    function press(key) {
        root.lastKey = ""
        root.lastKey = key.toLowerCase()
        clearTimer.restart()
    }

    Timer { id: clearTimer; interval: 170; onTriggered: root.lastKey = "" }

    ColumnLayout {
        id: col
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6

        Repeater {
            model: root.rows
            delegate: RowLayout {
                id: keyRow
                required property string modelData
                Layout.alignment: Qt.AlignHCenter
                spacing: 6

                Repeater {
                    model: keyRow.modelData.split("")
                    delegate: Rectangle {
                        id: key
                        required property string modelData
                        readonly property bool lit: root.lastKey === modelData
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        radius: 9
                        color: lit ? Theme.primary : Theme.surfaceRaised
                        border.width: 1
                        border.color: lit ? Theme.primary : Theme.outline
                        scale: lit ? 1.14 : 1.0
                        Behavior on color { ColorAnimation { duration: 180 } }
                        Behavior on border.color { ColorAnimation { duration: 180 } }
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                        Label {
                            anchors.centerIn: parent
                            text: key.modelData.toUpperCase()
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: key.lit ? Theme.textOnPrimary : Theme.mutedText
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 250
            Layout.preferredHeight: 34
            radius: 9
            readonly property bool lit: root.lastKey === " "
            color: lit ? Theme.primary : Theme.surfaceRaised
            border.width: 1
            border.color: lit ? Theme.primary : Theme.outline
            Behavior on color { ColorAnimation { duration: 180 } }
            Behavior on border.color { ColorAnimation { duration: 180 } }
        }
    }
}
