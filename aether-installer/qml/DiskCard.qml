import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import AetherInstaller

Rectangle {
    id: card
    required property var modelData
    required property int index
    readonly property bool selected: Setup.selectedDisk === modelData.path
    readonly property bool alongside: Setup.installMode === "alongside"
    readonly property bool blocked: !modelData.enoughSpace || (alongside && !modelData.alongsideOk)

    implicitHeight: info.implicitHeight + 28
    radius: Theme.shapeL
    color: selected ? Theme.secondaryContainer : (mouse.containsMouse ? Theme.surfaceVariant : Theme.surfaceRaised)
    border.width: selected ? 2 : 1
    border.color: selected ? Theme.primary : (mouse.containsMouse ? Theme.outlineStrong : Theme.outline)
    Behavior on color { ColorAnimation { duration: Theme.durFast } }
    Behavior on border.color { ColorAnimation { duration: Theme.durFast } }

    opacity: blocked ? 0.55 : 1.0

    Entrance { order: card.index; distance: 20 }

    ColumnLayout {
        id: info
        anchors.fill: parent
        anchors.margins: 14
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // check badge
            Rectangle {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                radius: 11
                color: card.selected ? Theme.primary : "transparent"
                border.width: 1
                border.color: card.selected ? Theme.primary : Theme.outlineStrong
                Behavior on color { ColorAnimation { duration: Theme.durFast } }
                Label {
                    anchors.centerIn: parent
                    text: "✓"
                    color: Theme.textOnPrimary
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    scale: card.selected ? 1.0 : 0.0
                    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
                }
            }

            Label {
                text: card.modelData.path
                color: Theme.primary
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }
            Label {
                Layout.fillWidth: true
                text: card.modelData.sizeText
                color: Theme.text
                horizontalAlignment: Text.AlignRight
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
        }

        Label {
            Layout.fillWidth: true
            text: card.modelData.modelText + "  ·  " + card.modelData.transport
            color: Theme.mutedText
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: card.modelData.badges
                delegate: Rectangle {
                    id: badge
                    required property string modelData
                    implicitWidth: badgeLabel.implicitWidth + 16
                    implicitHeight: 24
                    radius: Theme.shapeS
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.outlineStrong
                    Label {
                        id: badgeLabel
                        anchors.centerIn: parent
                        text: badge.modelData
                        color: Theme.mutedText
                        font.pixelSize: 11
                    }
                }
            }
        }

        Label {
            Layout.fillWidth: true
            visible: card.modelData.otherOsText.length > 0
            text: (card.alongside ? "Other systems you can keep: " : "Will also be erased, may include: ") + card.modelData.otherOsText
            color: card.alongside ? Theme.success : Theme.warning
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }
        Label {
            Layout.fillWidth: true
            visible: !card.modelData.enoughSpace && !(card.alongside && card.modelData.isGpt)
            text: "Insufficient space: Aether needs at least 8 GB."
            color: Theme.error
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }
        Label {
            Layout.fillWidth: true
            visible: card.alongside
            text: card.modelData.alongsideNote
            color: card.modelData.alongsideOk ? Theme.mutedText : Theme.error
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }

        Label {
            Layout.fillWidth: true
            text: card.modelData.partitionText
            color: Theme.mutedText
            font.pixelSize: 11
            wrapMode: Text.WordWrap
        }
        Label {
            Layout.fillWidth: true
            text: card.modelData.mountText
            color: Theme.subtleText
            font.pixelSize: 11
            wrapMode: Text.WordWrap
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: card.blocked ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: if (!card.blocked) Setup.selectDisk(card.modelData.path, card.modelData.path + "  ·  " + card.modelData.sizeText)
    }
}
