import QtQuick

// Drop inside a Label/Rectangle/Item: fades and slides its parent in whenever
// the parent becomes visible. Do not place directly inside a Layout.
Item {
    id: root
    property int order: 0
    property real distance: 16
    property int duration: 520
    readonly property Item target: parent

    width: 0
    height: 0

    Translate { id: shift; y: root.distance }

    Timer {
        id: delay
        interval: 60 + root.order * 70
        onTriggered: anim.restart()
    }

    ParallelAnimation {
        id: anim
        NumberAnimation { target: root.target; property: "opacity"; to: 1; duration: root.duration; easing.type: Easing.OutCubic }
        NumberAnimation { target: shift; property: "y"; to: 0; duration: root.duration; easing.type: Easing.OutCubic }
    }

    function reset() {
        anim.stop()
        delay.stop()
        if (root.target)
            root.target.opacity = 0
        shift.y = root.distance
    }

    onVisibleChanged: {
        reset()
        if (visible)
            delay.start()
    }

    Component.onCompleted: {
        if (root.target)
            root.target.transform = shift
        reset()
        if (visible)
            delay.start()
    }
}
