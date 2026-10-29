import QtQuick
import AetherInstaller

// The Aether mark from PNG assets. The small triangle is its own image so it
// can lift out and re-enter from below.
Item {
    id: root
    property real size: 96
    property bool loop: true
    property bool glow: true
    property color color: "#FFFFFF"   // kept for compatibility; the PNG is already white
    property real entry: 0.88

    implicitWidth: size
    implicitHeight: size

    GlowOrb {
        visible: root.glow
        anchors.centerIn: parent
        diameter: root.size * 2.6
        strength: 0.22
        opacity: 0.0
        SequentialAnimation on opacity {
            loops: Animation.Infinite
            running: root.glow && root.visible
            NumberAnimation { to: 1.0; duration: 2400; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.45; duration: 2400; easing.type: Easing.InOutSine }
        }
    }

    Item {
        id: wrap
        width: root.size
        height: root.size
        anchors.centerIn: parent
        scale: root.entry
        transformOrigin: Item.Center
        opacity: 0

        Image {
            anchors.fill: parent
            source: "../assets/aether-mark-body.png"
            sourceSize.width: Math.ceil(root.size * 2)
            sourceSize.height: Math.ceil(root.size * 2)
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
        }

        Image {
            id: tri
            width: parent.width
            height: parent.height
            source: "../assets/aether-mark-tri.png"
            sourceSize.width: Math.ceil(root.size * 2)
            sourceSize.height: Math.ceil(root.size * 2)
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
        }
    }

    readonly property real liftDistance: root.size * 0.18

    ParallelAnimation {
        id: intro
        NumberAnimation { target: wrap; property: "opacity"; from: 0; to: 1; duration: 500; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "entry"; from: 0.88; to: 1.0; duration: 800; easing.type: Easing.OutBack }
    }

    SequentialAnimation {
        id: lift
        loops: root.loop ? Animation.Infinite : 1
        PauseAnimation { duration: root.loop ? 2200 : 1100 }
        ParallelAnimation {
            NumberAnimation { target: tri; property: "y"; to: -root.liftDistance; duration: 380; easing.type: Easing.InCubic }
            NumberAnimation { target: tri; property: "opacity"; to: 0; duration: 380 }
        }
        PropertyAction { target: tri; property: "y"; value: root.liftDistance }
        ParallelAnimation {
            NumberAnimation { target: tri; property: "y"; to: 0; duration: 560; easing.type: Easing.OutCubic }
            NumberAnimation { target: tri; property: "opacity"; to: 1; duration: 560 }
        }
    }

    function play() {
        tri.y = 0
        tri.opacity = 1
        intro.restart()
        lift.restart()
    }

    onVisibleChanged: if (visible) play()
    Component.onCompleted: if (visible) play()
}
