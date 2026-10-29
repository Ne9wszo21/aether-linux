import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import AetherInstaller

ColumnLayout {
    id: root
    property alias label: caption.text
    property alias text: field.text
    property alias placeholderText: field.placeholderText
    property bool password: false
    property bool last: false
    property string error: ""
    property bool touched: false
    readonly property bool showError: error.length > 0 && (touched || Setup.showErrors)
    property bool reveal: false

    signal edited(string text)
    signal submitted()
    signal keyTyped(string key)

    spacing: 4

    Rectangle {
        id: box
        Layout.fillWidth: true
        Layout.topMargin: 8
        Layout.preferredHeight: 52
        radius: Theme.shapeXS
        color: "transparent"
        border.width: field.activeFocus || root.showError ? 2 : 1
        border.color: root.showError ? Theme.error : (field.activeFocus ? Theme.primary : (hover.hovered ? Theme.text : Theme.outlineStrong))
        Behavior on border.color { ColorAnimation { duration: Theme.durFast } }
        transform: Translate { id: shake }

        HoverHandler { id: hover }

        TextField {
            id: field
            anchors.fill: parent
            leftPadding: 16
            rightPadding: root.password ? 66 : 16
            color: Theme.text
            placeholderTextColor: box.floated ? Theme.subtleText : "transparent"
            selectionColor: Theme.primary
            selectedTextColor: Theme.textOnPrimary
            font.pixelSize: 16
            verticalAlignment: TextInput.AlignVCenter
            echoMode: root.password && !root.reveal ? TextInput.Password : TextInput.Normal
            background: null
            onTextEdited: root.edited(text)
            onEditingFinished: root.touched = true
            onAccepted: {
                if (root.last) {
                    root.submitted()
                } else {
                    var n = field.nextItemInFocusChain(true)
                    if (n)
                        n.forceActiveFocus()
                }
            }
            Keys.onPressed: function (event) { root.keyTyped(event.text) }
        }

        readonly property bool floated: field.activeFocus || field.text.length > 0

        // floating label that notches the outline
        Rectangle {
            x: 12
            y: box.floated ? -height / 2 : (box.height - height) / 2
            width: caption.implicitWidth + 8
            height: caption.implicitHeight
            color: box.floated ? Theme.surface : "transparent"
            Behavior on y { NumberAnimation { duration: Theme.durMedium; easing.type: Easing.OutCubic } }
            Label {
                id: caption
                anchors.centerIn: parent
                font.pixelSize: box.floated ? 12 : 16
                color: root.showError ? Theme.error : (field.activeFocus ? Theme.primary : Theme.mutedText)
                Behavior on font.pixelSize { NumberAnimation { duration: Theme.durMedium; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: Theme.durFast } }
            }
        }

        Label {
            visible: root.password
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: root.reveal ? "Hide" : "Show"
            color: showMouse.containsMouse ? Theme.primaryHover : Theme.primary
            font.pixelSize: 12
            font.weight: Font.Medium
            MouseArea {
                id: showMouse
                anchors.fill: parent
                anchors.margins: -8
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.reveal = !root.reveal
            }
        }
    }

    Label {
        Layout.preferredHeight: 14
        Layout.leftMargin: 16
        Layout.fillWidth: true
        text: root.error
        color: Theme.error
        font.pixelSize: 11
        elide: Text.ElideRight
        opacity: root.showError ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: Theme.durMedium } }
    }

    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: shake; property: "x"; to: -8; duration: 50 }
        NumberAnimation { target: shake; property: "x"; to: 8; duration: 70 }
        NumberAnimation { target: shake; property: "x"; to: -5; duration: 60 }
        NumberAnimation { target: shake; property: "x"; to: 5; duration: 60 }
        NumberAnimation { target: shake; property: "x"; to: 0; duration: 50 }
    }

    Connections {
        target: Setup
        function onValidationFailed() {
            if (root.error.length > 0)
                shakeAnim.restart()
        }
    }
}
