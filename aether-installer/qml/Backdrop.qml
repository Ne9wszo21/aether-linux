import QtQuick
import AetherInstaller

// Slow drifting glows and twinkling stars behind the whole window.
Item {
    id: root

    property var stars: {
        var list = []
        for (var i = 0; i < 30; ++i)
            list.push({ fx: Math.random(), fy: Math.random(), size: 1 + Math.random() * 1.6,
                        dur: 2200 + Math.random() * 3800, wait: Math.random() * 3000 })
        return list
    }

    Rectangle { anchors.fill: parent; color: Theme.background }

    // How strongly the two cyan shapes show. 1.0 matches the wallpaper exactly;
    // lower keeps text and buttons readable where they sit on top.
    property real accentOpacity: 0.18

    // Wallpaper-style corner shapes, turning slowly.
    CookieShape {                       // slate burst, top-left
        width: root.width * 0.29
        x: root.width * 0.076 - width / 2
        y: root.height * 0.148 - height / 2
        color: "#29495D"
        sides: 8; base: 0.66; amp: 0.34; power: 2.0
        spinDuration: 150000
    }
    CookieShape {                       // teal scallop, top-right
        width: root.width * 0.42
        x: root.width * 0.94 - width / 2
        y: root.height * 0.04 - height / 2
        color: "#004F57"
        sides: 9; base: 0.93; amp: 0.14
        spinDuration: 120000
        clockwise: false
    }
    CookieShape {                       // cyan scallop, bottom-left
        width: root.width * 0.45
        x: root.width * 0.01 - width / 2
        y: root.height * 0.99 - height / 2
        color: Theme.primary
        opacity: root.accentOpacity
        sides: 9; base: 0.93; amp: 0.14
        spinDuration: 135000
    }
    Rectangle {                         // big cyan circle, bottom-right (breathes slowly)
        width: root.width * 0.51
        height: width
        radius: width / 2
        x: root.width * 1.03 - width / 2
        y: root.height * 0.98 - height / 2
        color: Theme.primary
        opacity: root.accentOpacity
        SequentialAnimation on scale {
            loops: Animation.Infinite
            NumberAnimation { to: 1.05; duration: 9000; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 9000; easing.type: Easing.InOutSine }
        }
    }

    GlowOrb {
        id: orbA
        diameter: Math.max(root.width, root.height) * 0.9
        strength: 0.16
        x: root.width * 0.35
        y: -diameter * 0.45
        SequentialAnimation on x {
            loops: Animation.Infinite
            NumberAnimation { to: root.width * 0.55; duration: 16000; easing.type: Easing.InOutSine }
            NumberAnimation { to: root.width * 0.25; duration: 16000; easing.type: Easing.InOutSine }
        }
    }

    GlowOrb {
        diameter: Math.max(root.width, root.height) * 0.7
        strength: 0.10
        color: "#4A8FFF"
        x: -diameter * 0.35
        y: root.height * 0.55
        SequentialAnimation on y {
            loops: Animation.Infinite
            NumberAnimation { to: root.height * 0.35; duration: 20000; easing.type: Easing.InOutSine }
            NumberAnimation { to: root.height * 0.65; duration: 20000; easing.type: Easing.InOutSine }
        }
    }

    Repeater {
        model: root.stars
        delegate: Rectangle {
            id: star
            required property var modelData
            x: modelData.fx * root.width
            y: modelData.fy * root.height
            width: modelData.size
            height: modelData.size
            radius: width / 2
            color: Theme.primary
            opacity: 0.0
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                PauseAnimation { duration: star.modelData.wait }
                NumberAnimation { to: 0.55; duration: star.modelData.dur; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.0; duration: star.modelData.dur; easing.type: Easing.InOutSine }
            }
        }
    }
}
