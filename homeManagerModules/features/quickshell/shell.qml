import QtQuick 2.15
import QtQuick.Layouts 1.15
import Quickshell
import QtQuick.Effects
import Quickshell.Services.Mpris
import "./modules"
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

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            mask: Region {
                item: rect
            }
            Rectangle {
                id: rect

                anchors.centerIn: parent
                width: 0
                height: 0
            }

            width: 1200
            height: 200
            anchors.top: true
            exclusiveZone: 0
            color: "#00000000"

            Rectangle {
                anchors.fill: parent
                color: "#00000000"
                opacity: MusicLyricsService.visible === false || MusicLyricsService.currentLyricIndex === -1 || MusicLyricsService.parsedSyncedLyrics.length === 0 ? 0 : 1

                ListView {
                    id: lyricsView

                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 200

                    spacing: 2

                    model: MusicLyricsService.parsedSyncedLyrics
                    clip: true
                    currentIndex: MusicLyricsService.currentLyricIndex
                    preferredHighlightBegin: height / 2
                    preferredHighlightEnd: height / 2
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    highlightMoveDuration: 400

                    delegate: Text {
                        text: modelData.text
                        font.pixelSize: 26
                        height: 29
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        width: lyricsView.width

                        property int offset: index - lyricsView.currentIndex

                        color: {
                            if (offset === 0)
                                return "white";
                            if (offset === 1)
                                return "#CCCCCC";
                            if (offset === 2)
                                return "#888888";
                            return "transparent";
                        }

                        font.bold: offset === 0

                        opacity: {
                            if (offset === 0)
                                return 1.0;
                            if (offset === 1)
                                return 0.7;
                            if (offset === 2)
                                return 0.4;
                            return 0.0;
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 400
                            }
                        }
                    }

                    onCurrentIndexChanged: {
                        if (lyricsView.contentY <= 0 || lyricsView.currentIndex >= lyricsView.count - 3) {
                            lyricsView.contentY = lyricsView.indexAt(currentIndex).y;
                        } else {
                            var currentLyricItem = lyricsView.itemAt(lyricsView.indexAt(currentIndex).y);
                            if (currentLyricItem) {
                                lyricsView.contentY = currentLyricItem.y - lyricsView.height / 2 + currentLyricItem.height / 2;
                            }
                        }
                    }

                    Behavior on contentY {
                        NumberAnimation {
                            duration: 300
                            easing.type: Easing.InOutQuad
                        }
                    }
                }
            }
        }
    }
}
