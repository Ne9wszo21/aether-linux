import QtQuick
import QtQuick.Shapes

Shape {
    id: root
    property color color: "#6BD7E5"
    property real strength: 0.16
    property real diameter: 600

    width: diameter
    height: diameter

    ShapePath {
        strokeWidth: -1
        strokeColor: "transparent"
        fillGradient: RadialGradient {
            centerX: root.diameter / 2
            centerY: root.diameter / 2
            centerRadius: root.diameter / 2
            focalX: root.diameter / 2
            focalY: root.diameter / 2
            GradientStop { position: 0.0; color: Qt.rgba(root.color.r, root.color.g, root.color.b, root.strength) }
            GradientStop { position: 1.0; color: Qt.rgba(root.color.r, root.color.g, root.color.b, 0.0) }
        }
        startX: 0; startY: 0
        PathLine { x: root.diameter; y: 0 }
        PathLine { x: root.diameter; y: root.diameter }
        PathLine { x: 0; y: root.diameter }
        PathLine { x: 0; y: 0 }
    }
}
