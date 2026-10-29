import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import AetherInstaller

Rectangle {
    id: root
    color: "#000000"

    readonly property int rowHeight: 52
    readonly property int rowStep: 56
    readonly property int shownStep: Math.min(Setup.currentPage, Setup.lastStep)

    Rectangle {
        anchors.right: parent.right
        width: 1
        height: parent.height
        color: Theme.outline
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 22
        spacing: 24

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            AnimatedLogo {
                size: 38
                loop: false
                glow: false
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
            }

            ColumnLayout {
                spacing: 2
                Label {
                    text: "Aether Linux"
                    color: Theme.text
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                }
                Label {
                    text: "AETHER INSTALLER"
                    color: Theme.mutedText
                    font.pixelSize: 10
                    font.letterSpacing: 1.5
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.outline
        }

        Item {
            id: steps
            Layout.fillWidth: true
            Layout.preferredHeight: Setup.pageNames.length * root.rowStep

            // sliding highlight
            Rectangle {
                width: parent.width
                height: root.rowHeight
                radius: height / 2
                y: root.shownStep * root.rowStep
                color: Theme.secondaryContainer
                Behavior on y { NumberAnimation { duration: 460; easing.type: Easing.OutBack; easing.overshoot: 0.7 } }
            }

            Repeater {
                model: Setup.pageNames
                delegate: Item {
                    id: step
                    required property int index
                    required property string modelData
                    readonly property bool isCurrent: root.shownStep === index && Setup.currentPage <= Setup.lastStep
                    readonly property bool isDone: Setup.currentPage > index
                    readonly property bool reachable: index <= Setup.maxVisited && Setup.currentPage < Setup.installPage

                    y: index * root.rowStep
                    width: steps.width
                    height: root.rowHeight

                    // connector to next step
                    Rectangle {
                        visible: step.index < Setup.lastStep
                        x: 24
                        y: 42
                        width: 2
                        height: 24
                        radius: 1
                        color: step.isDone ? Theme.primary : Theme.outline
                        Behavior on color { ColorAnimation { duration: 360 } }
                    }

                    Rectangle {
                        id: hoverBg
                        anchors.fill: parent
                        radius: height / 2
                        color: Theme.text
                        opacity: mouse.containsMouse && step.reachable && !step.isCurrent ? Theme.stateHover : 0.0
                        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                    }

                    // pulsing ring on the active step
                    Rectangle {
                        id: ring
                        x: 12
                        y: 13
                        width: 26
                        height: 26
                        radius: 13
                        color: "transparent"
                        border.width: 2
                        border.color: Theme.primary
                        opacity: 0.0
                        SequentialAnimation {
                            running: step.isCurrent
                            loops: Animation.Infinite
                            onRunningChanged: if (!running) { ring.opacity = 0; ring.scale = 1 }
                            ParallelAnimation {
                                NumberAnimation { target: ring; property: "scale"; from: 1.0; to: 1.7; duration: 1500; easing.type: Easing.OutCubic }
                                NumberAnimation { target: ring; property: "opacity"; from: 0.55; to: 0.0; duration: 1500; easing.type: Easing.OutCubic }
                            }
                            PauseAnimation { duration: 300 }
                        }
                    }

                    Rectangle {
                        id: dot
                        x: 12
                        y: 13
                        width: 26
                        height: 26
                        radius: 13
                        color: step.isCurrent ? Theme.primary : (step.isDone ? Qt.rgba(0.42, 0.84, 0.90, 0.14) : "transparent")
                        border.width: step.isCurrent ? 0 : 1
                        border.color: step.isDone ? Theme.primary : Theme.outlineStrong
                        Behavior on color { ColorAnimation { duration: 260 } }
                        Behavior on border.color { ColorAnimation { duration: 260 } }

                        Label {
                            anchors.centerIn: parent
                            text: step.isDone ? "✓" : (step.index + 1)
                            color: step.isCurrent ? Theme.textOnPrimary : (step.isDone ? Theme.primary : Theme.mutedText)
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }

                        SequentialAnimation {
                            id: pop
                            NumberAnimation { target: dot; property: "scale"; to: 1.25; duration: 140; easing.type: Easing.OutCubic }
                            NumberAnimation { target: dot; property: "scale"; to: 1.0; duration: 260; easing.type: Easing.OutBack }
                        }
                    }

                    onIsCurrentChanged: if (isCurrent) pop.restart()

                    Label {
                        x: 52
                        anchors.verticalCenter: parent.verticalCenter
                        text: step.modelData
                        font.pixelSize: 14
                        font.weight: step.isCurrent ? Font.Medium : Font.Normal
                        color: step.isCurrent ? Theme.text : (step.reachable ? Theme.mutedText : Theme.subtleText)
                        Behavior on color { ColorAnimation { duration: 260 } }
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: step.reachable
                        cursorShape: step.reachable ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: Setup.go(step.index)
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        Label {
            text: "fast. clean. yours."
            color: Theme.mutedText
            font.pixelSize: 12
        }
        Label {
            text: "Version 0.3"
            color: Theme.subtleText
            font.pixelSize: 11
        }
        Label {
            visible: SystemInstaller.dryRun
            text: "DRY RUN · nothing is written"
            color: Theme.warning
            font.pixelSize: 10
            font.letterSpacing: 1
        }
    }
}
