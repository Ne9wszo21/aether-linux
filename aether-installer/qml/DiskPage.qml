import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import AetherInstaller

PageBase {
    id: page
    pageIndex: 3
    title: "Where should Aether go?"
    subtitle: "Erase a drive, install alongside Windows or another Linux, or partition it yourself."

    readonly property string none: "Choose a partition…"
    readonly property var modes: [
        { id: "erase", title: "Erase drive", sub: "Wipe it and use Btrfs" },
        { id: "alongside", title: "Install alongside", sub: "Keep Windows or other Linux" },
        { id: "manual", title: "Manual", sub: "Pick your own partitions" }
    ]

    function syncSelection() {
        if (Setup.installMode === "manual")
            return
        var list = DiskScanner.devices
        for (var i = 0; i < list.length; ++i)
            if (list[i].path === Setup.selectedDisk)
                return
        Setup.selectDisk("", "")
    }

    readonly property bool anyUsable: {
        var l = DiskScanner.devices
        for (var i = 0; i < l.length; ++i)
            if (Setup.installMode === "alongside" ? l[i].alongsideOk : l[i].enoughSpace)
                return true
        return false
    }

    function enoughOf(path) {
        var list = DiskScanner.partitions
        for (var i = 0; i < list.length; ++i)
            if (list[i].path === path)
                return list[i].enough
        return true
    }

    function partOptions(kind) {
        var out = [none]
        var list = DiskScanner.partitions
        for (var i = 0; i < list.length; ++i) {
            var p = list[i]
            if (kind === "root" && (p.mounted || p.isEsp))
                continue
            if (kind === "esp" && !p.isEsp && p.fstype !== "vfat")
                continue
            out.push(p.text)
        }
        return out
    }

    function textFor(path) {
        var list = DiskScanner.partitions
        for (var i = 0; i < list.length; ++i)
            if (list[i].path === path)
                return list[i].text
        return none
    }

    function pathOf(text) {
        return text === none ? "" : text.split("  ·  ")[0]
    }

    Connections {
        target: DiskScanner
        function onDevicesChanged() { page.syncSelection() }
    }

    onActiveChanged: if (active && DiskScanner.devices.length === 0 && !DiskScanner.busy) DiskScanner.refresh()
    Component.onCompleted: DiskScanner.refresh()

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // install mode picker
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Repeater {
                model: page.modes
                delegate: Rectangle {
                    id: modeCard
                    required property var modelData
                    readonly property bool on: Setup.installMode === modelData.id
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 62
                    radius: Theme.shapeL
                    color: on ? Theme.secondaryContainer : (modeMouse.containsMouse ? Theme.surfaceVariant : Theme.surfaceRaised)
                    border.width: on ? 2 : 1
                    border.color: on ? Theme.primary : Theme.outline
                    Behavior on color { ColorAnimation { duration: Theme.durFast } }
                    Behavior on border.color { ColorAnimation { duration: Theme.durFast } }
                    Entrance { order: 3 }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 16
                        anchors.rightMargin: 12
                        spacing: 2
                        Label {
                            width: parent.width
                            text: modeCard.modelData.title
                            color: modeCard.on ? Theme.primary : Theme.text
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }
                        Label {
                            width: parent.width
                            text: modeCard.modelData.sub
                            color: Theme.mutedText
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: modeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Setup.setInstallMode(modeCard.modelData.id)
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Label {
                Layout.fillWidth: true
                text: DiskScanner.status
                color: Theme.mutedText
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            AetherButton {
                text: DiskScanner.busy ? "Scanning…" : "Refresh drives"
                primary: false
                enabled: !DiskScanner.busy
                implicitHeight: 38
                onClicked: DiskScanner.refresh()
            }
        }

        // indeterminate scan bar
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 3
            clip: true
            Rectangle { anchors.fill: parent; radius: 1.5; color: Theme.outline }
            Rectangle {
                id: sweeper
                width: parent.width * 0.3
                height: parent.height
                radius: 1.5
                color: Theme.primary
                opacity: DiskScanner.busy ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 200 } }
                NumberAnimation on x {
                    from: -sweeper.width
                    to: sweeper.parent.width
                    duration: 1000
                    loops: Animation.Infinite
                    running: DiskScanner.busy
                }
            }
        }

        Label {
            visible: DiskScanner.error.length > 0
            Layout.fillWidth: true
            text: DiskScanner.error
            color: Theme.error
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }

        Label {
            id: diskHint
            Layout.fillWidth: true
            Layout.preferredHeight: Setup.showDiskError ? implicitHeight : 0
            visible: Layout.preferredHeight > 0.5
            text: Setup.installMode === "manual"
                ? (Setup.selectedRoot !== "" && !Setup.rootEnough
                    ? "Insufficient space: the root partition needs at least 8 GB."
                    : "Choose a root partition and an EFI partition to continue.")
                : (!page.anyUsable && DiskScanner.devices.length > 0
                    ? "Insufficient space: no drive has at least 8 GB available."
                    : "Select a drive to continue.")
            color: Theme.error
            font.pixelSize: 12
            Behavior on Layout.preferredHeight { NumberAnimation { duration: Theme.durMedium; easing.type: Easing.OutCubic } }
        }

        Label {
            Layout.fillWidth: true
            visible: Setup.installMode !== "manual" && !DiskScanner.busy
                && DiskScanner.devices.length > 0 && !page.anyUsable && !Setup.showDiskError
            text: "Insufficient space: no drive has at least 8 GB available for this mode."
            color: Theme.error
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }

        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 140
            radius: 20
            clip: true
            visible: Setup.installMode !== "manual"

            ListView {
                id: diskList
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10
                clip: true
                model: DiskScanner.devices
                ScrollBar.vertical: ScrollBar {}
                delegate: DiskCard {
                    width: ListView.view.width
                }
                add: Transition {
                    NumberAnimation { property: "scale"; from: 0.96; to: 1.0; duration: 260; easing.type: Easing.OutCubic }
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - 60
                spacing: 10
                visible: diskList.count === 0 && !DiskScanner.busy && DiskScanner.error.length === 0
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 300 } }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 54
                    Layout.preferredHeight: 34
                    radius: 8
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.outlineStrong
                    Rectangle {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.margins: 7
                        width: 6; height: 6; radius: 3
                        color: Theme.primary
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: parent.visible
                            NumberAnimation { to: 0.2; duration: 900 }
                            NumberAnimation { to: 1.0; duration: 900 }
                        }
                    }
                }
                Label {
                    Layout.fillWidth: true
                    text: "No drives to show yet.\nSelect Refresh drives to scan."
                    color: Theme.mutedText
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }
        }

        // manual partition pickers
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 140
            radius: 20
            visible: Setup.installMode === "manual"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 12

                AetherCombo {
                    Layout.fillWidth: true
                    label: "Root partition (formatted as Btrfs)"
                    options: page.partOptions("root")
                    value: page.textFor(Setup.selectedRoot)
                    onPicked: function (v) { Setup.selectRoot(page.pathOf(v), page.enoughOf(page.pathOf(v))) }
                }

                AetherCombo {
                    Layout.fillWidth: true
                    label: "EFI system partition"
                    options: page.partOptions("esp")
                    value: page.textFor(Setup.selectedEsp)
                    onPicked: function (v) { Setup.selectEsp(page.pathOf(v)) }
                }

                Label {
                    Layout.fillWidth: true
                    visible: Setup.selectedRoot !== "" && !Setup.rootEnough
                    text: "Insufficient space: the root partition needs at least 8 GB."
                    color: Theme.error
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    CheckBox {
                        text: "Format the EFI partition (only for a new, empty one)"
                        checked: Setup.formatEsp
                        onToggled: Setup.formatEsp = checked
                    }
                    Item { Layout.fillWidth: true }
                    AetherButton {
                        visible: DiskScanner.hasPartitioner
                        text: "Open partition editor"
                        kind: "tonal"
                        onClicked: DiskScanner.openPartitioner()
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }

        InfoBanner {
            Layout.fillWidth: true
            tone: Setup.installMode === "erase" ? Theme.warning : Theme.primary
            text: Setup.installMode === "erase"
                ? "Everything on the chosen drive is erased after you confirm on the summary page, including Windows or other systems on it."
                : (Setup.installMode === "alongside"
                    ? "Uses unallocated space only; existing partitions are untouched. To make room, shrink your Windows or Linux partition first and turn off Windows Fast Startup. Needs 20 GB free on a GPT disk."
                    : "Create your partitions first (GParted or cfdisk), then press Refresh drives. The root partition is formatted as Btrfs; the EFI partition is kept and shared with other systems.")
        }
    }
}
