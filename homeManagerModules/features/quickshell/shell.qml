import QtQuick 2.15
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import QtQuick.Effects
import "./services"

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

                    // Workspaces section
                    ColumnLayout {
                        id: workspacesColumn
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 10

                        Repeater {
                            model: Hyprland.workspaces
                            delegate: Rectangle {
                                implicitHeight: 22
                                implicitWidth: 22
                                radius: 6
                                color: modelData.focused ? "#7daea3" : (modelData.active ? "#7daea3" : "#343434")

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.verticalCenter: parent.verticalCenter
                                    radius: 100
                                    color: modelData.focused ? "#282828" : modelData.urgent ? "#fb4934" : "#d8dee9"

                                    implicitHeight: 10
                                    implicitWidth: 10
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: modelData.activate()
                                    hoverEnabled: true
                                    onEntered: parent.opacity = 0.9
                                    onExited: parent.opacity = 1.0
                                }
                            }
                        }
                    }

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

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: LayoutService.currentLayout

                        color: "#fbf1c7"
                    }

                    Text {
                        readonly property var source: Pipewire.defaultAudioSource

                        anchors.horizontalCenter: parent.horizontalCenter

                        PwObjectTracker {
                            objects: [Pipewire.defaultAudioSource]
                        }

                        Component.onCompleted: {
                            console.log("ASD");
                            console.log(JSON.stringify(Hyprland, null, 2));
                        }

                        color: Pipewire.defaultAudioSource?.audio.muted ? "#fb4934" : "#b8bb26"
                        text: Pipewire.defaultAudioSource?.audio.muted ? "" : ""
                    }

                    ColumnLayout {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 10

                        Repeater {
                            id: root
                            model: SystemTray.items

                            delegate: Rectangle {
                                implicitHeight: 16
                                implicitWidth: 16
                                color: "#00000000"

                                Image {
                                    source: modelData.icon
                                    anchors.fill: parent
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: event => {
                                        if (event.button === Qt.LeftButton) {
                                            console.log(modelData.title);
                                            modelData.activate();
                                        } else {
                                            modelData.secondaryActivate();
                                        }
                                        modelData.display(this, 0, 0);
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 0

                        Text {
                            id: clockHours
                            font.pixelSize: 14
                            color: "#fbf1c7"
                            text: Qt.formatTime(new Date(), "hh")
                            font.weight: 900
                        }

                        Text {
                            id: clockMinutes
                            font.pixelSize: 14
                            text: Qt.formatTime(new Date(), "mm")
                            font.weight: 900
                            color: "#fbf1c7"
                        }

                        Timer {
                            interval: 10000
                            running: true
                            repeat: true
                            onTriggered: {
                                let now = new Date();
                                clockHours.text = Qt.formatTime(now, "hh");
                                clockMinutes.text = Qt.formatTime(now, "mm");
                            }
                        }
                    }
                }
            }
        }
    }
}
