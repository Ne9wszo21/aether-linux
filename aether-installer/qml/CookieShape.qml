import QtQuick
import QtQuick.Shapes

// Scalloped / burst shape (Material 3 Expressive style) that turns slowly.
// width sets the overall size; the outline always fits inside it.
Item {
    id: root
    property color color: "#6BD7E5"
    property int sides: 9
    property real base: 0.93       // inner radius (relative)
    property real amp: 0.14        // lobe depth (relative)
    property real power: 1.0       // >1 = sharper points, <1 = rounder
    property int spinDuration: 120000
    property bool clockwise: true

    width: 300
    height: width

    readonly property int unit: 640
    readonly property var outline: {
        var pts = []
        var c = unit / 2
        var rMax = base + amp
        var n = 270
        for (var i = 0; i < n; ++i) {
            var t = (i / n) * Math.PI * 2
            var k = Math.pow((1 + Math.cos(sides * t)) / 2, power)
            var r = c * (base + amp * k) / rMax
            pts.push(Qt.point(c + r * Math.cos(t), c + r * Math.sin(t)))
        }
        pts.push(pts[0])
        return pts
    }

    RotationAnimator on rotation {
        from: root.clockwise ? 0 : 360
        to: root.clockwise ? 360 : 0
        duration: root.spinDuration
        loops: Animation.Infinite
        running: root.visible
    }

    Shape {
        width: root.unit
        height: root.unit
        transformOrigin: Item.TopLeft
        scale: root.width / root.unit
        layer.enabled: true
        layer.samples: 4
        layer.smooth: true

        ShapePath {
            fillColor: root.color
            strokeColor: "transparent"
            strokeWidth: 0
            startX: root.outline[0].x
            startY: root.outline[0].y
            PathPolyline { path: root.outline }
        }
    }
}
