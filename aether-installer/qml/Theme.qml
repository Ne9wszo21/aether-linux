pragma Singleton
import QtQuick

QtObject {
    // Aether palette: pure black with a cyan accent.
    readonly property color background: "#000000"
    readonly property color surface: "#070A0B"
    readonly property color surfaceRaised: "#0C1113"
    readonly property color surfaceVariant: "#131B1E"
    readonly property color primary: "#6BD7E5"
    readonly property color primaryHover: "#8DE4ED"
    readonly property color primaryPressed: "#4FBAC8"
    readonly property color secondary: "#6BD7E5"
    readonly property color textOnPrimary: "#071012"
    readonly property color text: "#FFFFFF"
    readonly property color mutedText: "#AAB4B7"
    readonly property color subtleText: "#6B7679"
    readonly property color outline: "#262D30"
    readonly property color outlineStrong: "#3E484B"
    readonly property color error: "#FF8A80"
    readonly property color warning: "#FFD180"
    readonly property color success: "#7CE8B0"

    // Material 3 tonal container, derived from the existing primary (no new hue).
    readonly property color secondaryContainer: Qt.rgba(0.42, 0.84, 0.90, 0.16)

    // M3 shape scale
    readonly property int shapeXS: 4
    readonly property int shapeS: 8
    readonly property int shapeM: 12
    readonly property int shapeL: 16
    readonly property int shapeXL: 28
    readonly property int radiusSmall: 12
    readonly property int radiusMedium: 16
    readonly property int radiusLarge: 28

    // M3 state layer opacities
    readonly property real stateHover: 0.08
    readonly property real stateFocus: 0.10
    readonly property real statePressed: 0.10

    readonly property int durFast: 140
    readonly property int durMedium: 260
    readonly property int durSlow: 460
}
