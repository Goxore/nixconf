import QtQuick 2.15
import QtQuick.Layouts 1.15
import Quickshell
import QtQuick.Effects
import "./modules"

ShellRoot {
    readonly property int panelWidth: 50

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            aboveWindows: false
            width: panelWidth + 30
            height: 190
            anchors.top: true
            anchors.left: true
            anchors.bottom: true
            exclusiveZone: panelWidth
            color: "#00000000"

            RectangularShadow {
                anchors.fill: myRectangle
                radius: myRectangle.radius
                blur: 30
                spread: 10
                opacity: 0.8
                color: "#000000"
            }

            Rectangle {
                id: myRectangle
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                width: panelWidth
                color: "#222222"

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10
                    anchors.bottomMargin: 10

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "󱄅"
                        font.pixelSize: 29
                        color: "#7daea3"
                    }

                    Workspaces {}

                    // current playing
                    // Text {
                    //     readonly property list<MprisPlayer> players: Mpris.players.values
                    //     readonly property MprisPlayer active: players[0] ?? null
                    //     text: active ? (active.trackTitle || "No Title") : "No Player"
                    //     font.pixelSize: 20
                    //     color: "red"
                    // }

                    Item {
                        Layout.fillHeight: true
                    }



                    KeyboardLayout {}
                    MicMuted {}
                    SysTray {}
                    Clock {}
                }
            }
        }
    }
}
