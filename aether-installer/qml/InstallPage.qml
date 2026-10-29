import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import AetherInstaller

PageBase {
    id: page
    pageIndex: 6
    showHeader: false

    property bool showLog: false
    readonly property real shown: ring.value
    readonly property var phases: [
        { label: "Disk", at: 0.06 },
        { label: "Copy", at: 0.20 },
        { label: "Update", at: 0.64 },
        { label: "Setup", at: 0.85 },
        { label: "Boot", at: 0.96 }
    ]

    property string shownStage: ""
    readonly property string wantedStage: SystemInstaller.failed ? SystemInstaller.error
        : (SystemInstaller.stage.length ? SystemInstaller.stage : "Getting ready…")
    onWantedStageChanged: stageFade.restart()

    SequentialAnimation {
        id: stageFade
        NumberAnimation { target: stageLabel; property: "opacity"; to: 0; duration: 140 }
        ScriptAction { script: page.shownStage = page.wantedStage }
        NumberAnimation { target: stageLabel; property: "opacity"; to: 1; duration: 260; easing.type: Easing.OutCubic }
    }

    function begin() {
        SystemInstaller.start(Setup.installConfig())
    }

    onActiveChanged: {
        if (active) {
            page.shownStage = page.wantedStage
            intro.restart()
        }
        if (active && !SystemInstaller.running && !SystemInstaller.finished && !SystemInstaller.failed)
            begin()
    }

    Connections {
        target: SystemInstaller
        function onStateChanged() {
            if (SystemInstaller.failed)
                page.showLog = true
            if (SystemInstaller.finished && page.active)
                doneTimer.restart()
        }
    }

    Timer {
        id: doneTimer
        interval: 1200
        onTriggered: Setup.complete()
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width, 560)
        spacing: 12

        Item {
            id: ring
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 176
            Layout.preferredHeight: 176
            property real value: SystemInstaller.progress
            Behavior on value { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

            NumberAnimation {
                id: intro
                target: ring
                property: "scale"
                from: 0.8; to: 1.0
                duration: 700
                easing.type: Easing.OutBack
                easing.overshoot: 1.2
            }

            // soft ripples that radiate out while the install is running
            Repeater {
                model: 2
                delegate: Rectangle {
                    id: ripple
                    required property int index
                    anchors.centerIn: parent
                    width: 160; height: 160; radius: 80
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.primary
                    opacity: 0.0
                    z: -1
                    SequentialAnimation {
                        running: SystemInstaller.running && page.active
                        loops: Animation.Infinite
                        onRunningChanged: if (!running) { ripple.opacity = 0; ripple.scale = 1 }
                        PauseAnimation { duration: ripple.index * 1400 }
                        ParallelAnimation {
                            NumberAnimation { target: ripple; property: "scale"; from: 1.0; to: 1.45; duration: 2800; easing.type: Easing.OutCubic }
                            NumberAnimation { target: ripple; property: "opacity"; from: 0.35; to: 0.0; duration: 2800; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }

            Shape {
                anchors.fill: parent
                layer.enabled: true
                layer.samples: 4
                ShapePath {
                    strokeColor: Theme.outline
                    strokeWidth: 4
                    fillColor: "transparent"
                    PathAngleArc { centerX: 88; centerY: 88; radiusX: 80; radiusY: 80; startAngle: 0; sweepAngle: 359.9 }
                }
                ShapePath {
                    strokeColor: SystemInstaller.failed ? Theme.error : Theme.primary
                    strokeWidth: 4
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: 88; centerY: 88; radiusX: 80; radiusY: 80
                        startAngle: -90
                        sweepAngle: Math.min(359.9, 360 * ring.value)
                    }
                }
            }

            // small dot circling the ring while work is in progress
            Item {
                anchors.fill: parent
                visible: SystemInstaller.running
                RotationAnimator on rotation {
                    from: 0; to: 360; duration: 3200
                    loops: Animation.Infinite
                    running: SystemInstaller.running
                }
                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: Theme.text
                    opacity: 0.8
                    x: 88 - 4
                    y: 8 - 4
                }
            }

            AnimatedLogo {
                anchors.centerIn: parent
                size: 64
                loop: true
                glow: SystemInstaller.running
                width: 64
                height: 64
            }
        }

        Label {
            Layout.fillWidth: true
            Layout.topMargin: 6
            text: SystemInstaller.failed ? "Installation stopped"
                : (SystemInstaller.finished ? "All done" : Math.round(page.shown * 100) + "%")
            color: SystemInstaller.failed ? Theme.error : Theme.text
            font.pixelSize: 30
            font.weight: Font.Normal
            horizontalAlignment: Text.AlignHCenter
            Entrance { order: 1 }
        }

        Label {
            id: stageLabel
            Layout.fillWidth: true
            text: page.shownStage
            color: SystemInstaller.failed ? Theme.error : Theme.mutedText
            font.pixelSize: 14
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 6
            Layout.preferredWidth: chips.implicitWidth
            Layout.preferredHeight: chips.implicitHeight
            Entrance { order: 3 }
            Row {
                id: chips
                spacing: 8
                Repeater {
                    model: page.phases
                    delegate: Rectangle {
                        id: chip
                        required property var modelData
                        readonly property bool reached: SystemInstaller.progress >= modelData.at
                        width: chipLabel.implicitWidth + 24
                        height: 32
                        radius: Theme.shapeS
                        color: reached ? Qt.rgba(0.42, 0.84, 0.90, 0.10) : Theme.surfaceRaised
                        border.color: reached ? Qt.rgba(0.42, 0.84, 0.90, 0.5) : Theme.outline
                        Behavior on color { ColorAnimation { duration: Theme.durMedium } }
                        Behavior on border.color { ColorAnimation { duration: Theme.durMedium } }
                        Label {
                            id: chipLabel
                            anchors.centerIn: parent
                            text: (chip.reached ? "✓  " : "") + chip.modelData.label
                            color: chip.reached ? Theme.primary : Theme.mutedText
                            font.pixelSize: 12
                        }
                    }
                }
            }
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            text: page.showLog ? "Hide details" : "Show details"
            color: detailsMouse.containsMouse ? Theme.primaryHover : Theme.primary
            font.pixelSize: 12
            font.weight: Font.DemiBold
            MouseArea {
                id: detailsMouse
                anchors.fill: parent
                anchors.margins: -8
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: page.showLog = !page.showLog
            }
        }

        Card {
            Layout.fillWidth: true
            Layout.preferredHeight: page.showLog ? 170 : 0
            visible: Layout.preferredHeight > 1
            radius: 16
            clip: true
            Behavior on Layout.preferredHeight { NumberAnimation { duration: Theme.durSlow; easing.type: Easing.OutCubic } }

            ScrollView {
                anchors.fill: parent
                anchors.margins: 10
                TextArea {
                    readOnly: true
                    text: SystemInstaller.log
                    color: Theme.mutedText
                    font.family: "monospace"
                    font.pixelSize: 11
                    wrapMode: TextEdit.Wrap
                    background: null
                    onTextChanged: cursorPosition = length
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 6
            spacing: 12
            visible: SystemInstaller.failed

            AetherButton {
                text: "Back to summary"
                kind: "text"
                onClicked: { SystemInstaller.reset(); Setup.currentPage = 5 }
            }
            AetherButton {
                text: "Try again"
                onClicked: { SystemInstaller.reset(); page.showLog = false; page.begin() }
            }
        }

        Label {
            Layout.fillWidth: true
            visible: SystemInstaller.running
            text: "Please keep this computer on and don't close the window."
            color: Theme.subtleText
            font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
