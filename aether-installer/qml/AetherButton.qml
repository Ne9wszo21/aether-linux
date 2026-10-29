import QtQuick
import QtQuick.Controls
import AetherInstaller

// Material 3 button. kind: "filled" | "tonal" | "outlined" | "text".
// `primary: false` (older callers) maps to "outlined".
Button {
    id: control
    property bool primary: true
    property string kind: primary ? "filled" : "outlined"
    readonly property color fg: kind === "filled" ? Theme.textOnPrimary
        : (kind === "tonal" ? Theme.text : Theme.primary)

    hoverEnabled: true
    implicitHeight: 40
    implicitWidth: Math.max(64, contentItem.implicitWidth + 48)
    font.pixelSize: 14
    font.weight: Font.Medium
    font.letterSpacing: 0.1
    opacity: enabled ? 1.0 : 0.38

    background: Rectangle {
        radius: height / 2
        color: control.kind === "filled" ? Theme.primary
            : (control.kind === "tonal" ? Theme.secondaryContainer : "transparent")
        border.width: control.kind === "outlined" ? 1 : 0
        border.color: Theme.outlineStrong

        // state layer
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: control.fg
            opacity: control.down ? Theme.statePressed
                : (control.hovered ? Theme.stateHover : (control.visualFocus ? Theme.stateFocus : 0.0))
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
        }

        // focus indicator
        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            radius: height / 2
            color: "transparent"
            border.width: 2
            border.color: Theme.primary
            opacity: control.visualFocus ? 0.8 : 0.0
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
        }
    }

    contentItem: Label {
        text: control.text
        font: control.font
        color: control.fg
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
