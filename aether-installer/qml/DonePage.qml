import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import AetherInstaller

PageBase {
    pageIndex: 7
    showHeader: false

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width, 520)
        spacing: 14

        Item {
            id: burst
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 150
            Layout.preferredHeight: 150
            property real sweep: 0
            property real reveal: 0
            property real t: 0

            function play() {
                sweep = 0; reveal = 0; t = 0
                seq.restart()
            }
            onVisibleChanged: if (visible) play()

            SequentialAnimation {
                id: seq
                NumberAnimation { target: burst; property: "sweep"; to: 360; duration: 700; easing.type: Easing.InOutCubic }
                ParallelAnimation {
                    NumberAnimation { target: burst; property: "reveal"; to: 1; duration: 380; easing.type: Easing.OutCubic }
                    NumberAnimation { target: burst; property: "t"; to: 1; duration: 900; easing.type: Easing.OutCubic }
                }
            }

            Shape {
                anchors.fill: parent
                layer.enabled: true
                layer.samples: 4
                ShapePath {
                    strokeColor: Theme.primary
                    strokeWidth: 4
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: 75; centerY: 75
                        radiusX: 62; radiusY: 62
                        startAngle: -90
                        sweepAngle: burst.sweep
                    }
                }
            }

            Item {
                width: burst.reveal * 150
                height: 150
                clip: true
                Shape {
                    width: 150
                    height: 150
                    layer.enabled: true
                    layer.samples: 4
                    ShapePath {
                        strokeColor: Theme.primary
                        strokeWidth: 6
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin
                        startX: 48; startY: 78
                        PathLine { x: 68; y: 98 }
                        PathLine { x: 104; y: 54 }
                    }
                }
            }

            Repeater {
                model: 14
                delegate: Rectangle {
                    id: spark
                    required property int index
                    readonly property real angle: index * 2 * Math.PI / 14
                    readonly property real dist: 66 + burst.t * (28 + (index % 3) * 14)
                    width: 5 - (index % 3)
                    height: width
                    radius: width / 2
                    color: index % 2 === 0 ? Theme.primary : "#FFFFFF"
                    x: 75 + Math.cos(angle) * dist - width / 2
                    y: 75 + Math.sin(angle) * dist - height / 2
                    opacity: burst.t > 0 ? 1.0 - burst.t : 0.0
                }
            }
        }

        Label {
            Layout.fillWidth: true
            text: SystemInstaller.dryRun ? "Dry run complete" : "Aether is installed"
            color: Theme.text
            font.pixelSize: 32
            font.weight: Font.Normal
            horizontalAlignment: Text.AlignHCenter
            Entrance { order: 4 }
        }

        Label {
            Layout.fillWidth: true
            text: SystemInstaller.dryRun
                ? "Every step ran in preview. Nothing was written to disk."
                : "Remove the installation media, then restart to boot into your new system."
            color: Theme.mutedText
            font.pixelSize: 15
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            Entrance { order: 5 }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 14
            spacing: 12
            AetherButton {
                text: "Start over"
                kind: "tonal"
                visible: SystemInstaller.dryRun
                onClicked: { SystemInstaller.reset(); Setup.reset() }
            }
            AetherButton {
                text: "Close"
                primary: SystemInstaller.dryRun
                onClicked: Qt.quit()
            }
            AetherButton {
                text: "Restart now"
                visible: !SystemInstaller.dryRun
                onClicked: SystemInstaller.reboot()
            }
        }
    }
}
