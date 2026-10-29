import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import AetherInstaller

PageBase {
    pageIndex: 0
    showHeader: false

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width, 560)
        spacing: 14

        AnimatedLogo {
            Layout.alignment: Qt.AlignHCenter
            size: 112
            Layout.preferredWidth: 112
            Layout.preferredHeight: 112
        }

        Item { Layout.preferredHeight: 6 }

        Label {
            Layout.fillWidth: true
            text: "A calmer way to begin."
            color: Theme.text
            font.pixelSize: 32
            font.weight: Font.Normal
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            Entrance { order: 1 }
        }

        Label {
            Layout.fillWidth: true
            text: "Welcome to Aether Linux. This installer will guide you through setting up your system."
            color: Theme.mutedText
            font.pixelSize: 15
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            Entrance { order: 2 }
        }

        InfoBanner {
            Layout.fillWidth: true
            Layout.topMargin: 8
            text: "Installs Aether onto the drive you choose. You will review everything before any disk is touched."
            Entrance { order: 4 }
        }
    }
}
