import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import AetherInstaller

// Shared page chrome: slide/fade between pages, plus a staggered header.
Item {
    id: root
    property int pageIndex: -1
    property string title
    property string subtitle
    property string eyebrow: "STEP " + (pageIndex + 1) + " OF " + Setup.pageNames.length
    property bool showHeader: true
    default property alias content: body.data
    readonly property bool active: Setup.currentPage === pageIndex

    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    opacity: active ? 1.0 : 0.0
    visible: opacity > 0.01
    x: active ? 0 : (Setup.currentPage > pageIndex ? -48 : 48)
    Behavior on opacity { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
    Behavior on x { NumberAnimation { duration: 460; easing.type: Easing.OutCubic } }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 56
        anchors.rightMargin: 56
        anchors.topMargin: 40
        anchors.bottomMargin: 8
        spacing: 0

        Label {
            visible: root.showHeader
            text: root.eyebrow
            color: Theme.primary
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 1.8
            Entrance { order: 0 }
        }

        Label {
            visible: root.showHeader
            Layout.topMargin: 6
            text: root.title
            color: Theme.text
            font.pixelSize: 28
            font.weight: Font.Normal
            Entrance { order: 1 }
        }

        Label {
            visible: root.showHeader
            Layout.topMargin: 8
            Layout.bottomMargin: 22
            Layout.fillWidth: true
            text: root.subtitle
            color: Theme.mutedText
            font.pixelSize: 14
            wrapMode: Text.WordWrap
            Entrance { order: 2 }
        }

        Item {
            id: body
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
