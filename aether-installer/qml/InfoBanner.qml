import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import AetherInstaller

Rectangle {
    id: root
    property string text
    property color tone: Theme.primary

    implicitHeight: row.implicitHeight + 24
    radius: Theme.shapeM
    color: Theme.surfaceRaised
    border.color: Theme.outline

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
            Layout.alignment: Qt.AlignTop
            radius: 11
            color: Qt.rgba(root.tone.r, root.tone.g, root.tone.b, 0.14)
            border.color: Qt.rgba(root.tone.r, root.tone.g, root.tone.b, 0.55)
            Label {
                anchors.centerIn: parent
                text: "i"
                color: root.tone
                font.pixelSize: 12
                font.weight: Font.Bold
            }
        }

        Label {
            Layout.fillWidth: true
            text: root.text
            color: Theme.mutedText
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }
    }
}
