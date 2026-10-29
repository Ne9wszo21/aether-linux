import QtQuick
import AetherInstaller

// Lightweight animated "globe": orbiting dots and a spinning meridian.
Item {
    id: root
    implicitWidth: 240
    implicitHeight: 240

    Repeater {
        model: 3
        delegate: Item {
            id: orbit
            required property int index
            anchors.centerIn: parent
            width: root.width * (0.52 + index * 0.24)
            height: width

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Theme.outline
            }

            Item {
                anchors.fill: parent
                RotationAnimator on rotation {
                    from: orbit.index % 2 === 0 ? 0 : 360
                    to: orbit.index % 2 === 0 ? 360 : 0
                    duration: 12000 + orbit.index * 7000
                    loops: Animation.Infinite
                    running: root.visible
                }
                Rectangle {
                    width: 9 - orbit.index * 2
                    height: width
                    radius: width / 2
                    color: Theme.primary
                    x: parent.width / 2 - width / 2
                    y: -height / 2
                }
            }
        }
    }

    Rectangle {
        id: core
        anchors.centerIn: parent
        width: root.width * 0.40
        height: width
        radius: width / 2
        color: Theme.surfaceRaised
        border.width: 1
        border.color: Qt.rgba(0.42, 0.84, 0.90, 0.5)
        clip: true

        Rectangle {
            anchors.centerIn: parent
            width: parent.width
            height: 1
            color: Qt.rgba(0.42, 0.84, 0.90, 0.3)
        }

        Rectangle {
            id: meridian
            anchors.centerIn: parent
            height: parent.height
            width: parent.width * 0.9
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(0.42, 0.84, 0.90, 0.45)
            SequentialAnimation on width {
                loops: Animation.Infinite
                running: root.visible
                NumberAnimation { to: core.width * 0.12; duration: 2600; easing.type: Easing.InOutSine }
                NumberAnimation { to: core.width * 0.9; duration: 2600; easing.type: Easing.InOutSine }
            }
        }
    }
}
