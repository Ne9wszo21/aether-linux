import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import AetherInstaller

ColumnLayout {
    id: root
    property string label
    property var options: []
    property string value
    signal picked(string value)

    spacing: 0

    ComboBox {
        id: combo
        Layout.fillWidth: true
        Layout.topMargin: 8
        implicitHeight: 52
        hoverEnabled: true
        font.pixelSize: 14
        model: root.options
        currentIndex: Math.max(0, root.options.indexOf(root.value))
        onActivated: root.picked(currentText)

        contentItem: Text {
            leftPadding: 16
            rightPadding: 40
            text: combo.displayText
            font: combo.font
            color: Theme.text
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        indicator: Text {
            x: combo.width - width - 14
            y: (combo.height - height) / 2
            text: "▾"
            color: Theme.primary
            font.pixelSize: 14
            rotation: combo.popup.visible ? 180 : 0
            Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }

        background: Rectangle {
            radius: Theme.shapeXS
            color: "transparent"
            border.width: (combo.popup.visible || combo.activeFocus) ? 2 : 1
            border.color: (combo.popup.visible || combo.activeFocus) ? Theme.primary
                : (combo.hovered ? Theme.text : Theme.outlineStrong)
            Behavior on border.color { ColorAnimation { duration: Theme.durFast } }

            Rectangle {
                x: 12
                y: -height / 2
                width: comboLabel.implicitWidth + 8
                height: comboLabel.implicitHeight
                color: Theme.surface
                Label {
                    id: comboLabel
                    anchors.centerIn: parent
                    text: root.label
                    font.pixelSize: 12
                    color: (combo.activeFocus || combo.popup.visible) ? Theme.primary : Theme.mutedText
                    Behavior on color { ColorAnimation { duration: Theme.durFast } }
                }
            }
        }

        delegate: ItemDelegate {
            id: dlg
            required property var modelData
            required property int index
            width: combo.width - 12
            implicitHeight: 48
            highlighted: combo.highlightedIndex === index
            contentItem: Text {
                leftPadding: 8
                text: dlg.modelData
                color: dlg.highlighted ? Theme.primary : Theme.text
                font.weight: combo.currentIndex === dlg.index ? Font.DemiBold : Font.Normal
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            background: Rectangle {
                radius: 0
                color: dlg.highlighted ? Theme.secondaryContainer : "transparent"
            }
        }

        popup: Popup {
            y: combo.height + 6
            width: combo.width
            padding: 6
            implicitHeight: Math.min(contentItem.implicitHeight + 12, 300)
            enter: Transition {
                NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 150 }
                NumberAnimation { property: "scale"; from: 0.96; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
            }
            exit: Transition {
                NumberAnimation { property: "opacity"; to: 0.0; duration: 100 }
            }
            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: combo.popup.visible ? combo.delegateModel : null
                currentIndex: combo.highlightedIndex
                ScrollIndicator.vertical: ScrollIndicator {}
            }
            background: Rectangle {
                radius: Theme.shapeXS
                color: Theme.surfaceRaised
                border.color: Theme.outline
            }
        }
    }
}
