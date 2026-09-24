import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.Commons
import qs.Services
import qs.Widgets

RowLayout {
    id: root

    property string tab: "recent"

    readonly property bool loopAll: MusicService.player?.loopState === MprisLoopState.Playlist
    readonly property bool loopOne: MusicService.player?.loopState === MprisLoopState.Track

    readonly property bool searching: MusicService.query.trim() !== ""

    readonly property var libraryRows: {
        if (searching)
            return MusicService.results;
        return tab === "liked" ? MusicService.likedRows : MusicHistoryService.top(60);
    }

    signal dismissed

    function focusSearch() {
        focusDelay.restart();
    }

    spacing: Style.panelPadding

    Timer {
        id: focusDelay
        interval: Style.durShort2
        onTriggered: field.take()
    }

    ColumnLayout {
        Layout.preferredWidth: Style.musicPaneWidth
        Layout.minimumWidth: Style.musicPaneWidth
        Layout.maximumWidth: Style.musicPaneWidth
        Layout.fillHeight: true
        spacing: Style.spacing

        TextField {
            id: field
            icon: Icons.search
            placeholder: MusicService.text("search_placeholder")
            text: MusicService.query
            onEdited: value => MusicService.query = value
            onAccepted: {
                MusicService.playTop();
                root.dismissed();
            }
        }

        Tabs {
            Layout.fillWidth: true
            visible: !root.searching
            current: root.tab
            onSelected: key => root.tab = key

            model: [
                {
                    key: "liked",
                    label: MusicService.text("liked"),
                    icon: Icons.liked
                },
                {
                    key: "recent",
                    label: MusicService.text("recent"),
                    icon: Icons.uptime
                }
            ]
        }

        EmptyState {
            Layout.fillHeight: true
            visible: root.libraryRows.length === 0
            icon: {
                if (root.searching)
                    return Icons.emptySearch;
                if (root.tab !== "liked")
                    return Icons.emptyMusic;
                if (MusicService.likedLoading)
                    return Icons.hourglassTop;
                return MusicService.likedSignedIn ? Icons.like : Icons.linkOff;
            }

            title: {
                if (root.searching)
                    return MusicService.text(MusicService.searching ? "searching" : "no_results");
                if (root.tab !== "liked")
                    return MusicService.text("no_recent");
                if (MusicService.likedLoading)
                    return MusicService.text("loading_liked");
                return MusicService.text(MusicService.likedSignedIn ? "no_liked" : "not_signed_in");
            }

            supporting: {
                if (root.searching)
                    return MusicService.searching ? "" : MusicService.text("no_results_help");
                if (root.tab !== "liked")
                    return MusicService.text("no_recent_help");
                if (MusicService.likedLoading)
                    return "";
                return MusicService.text(MusicService.likedSignedIn ? "no_liked_help" : "not_signed_in_help");
            }
        }

        TrackList {
            visible: root.libraryRows.length > 0
            model: root.libraryRows

            onActivated: entry => {
                if (entry.videoId)
                    MusicService.playNow(entry.videoId);
                else
                    MusicService.query = [entry.artist, entry.title].filter(part => part !== "").join(" ");
            }

            onQueued: entry => MusicService.queue(entry.videoId)
        }
    }

    Divider {
        vertical: true
    }

    ColumnLayout {
        id: stage

        Layout.fillWidth: true
        Layout.minimumWidth: Style.musicPaneWidth
        Layout.fillHeight: true
        spacing: Style.spacing

        EmptyState {
            Layout.fillHeight: true
            visible: !MusicService.hasPlayer
            icon: Icons.emptyMusic
            title: MusicService.text("nothing_playing")
            supporting: MusicService.text("nothing_playing_help")
        }

        Item {
            id: artArea

            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: MusicService.hasPlayer

            Artwork {
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height)
                height: width
                rounding: Style.radiusL
                source: MusicService.art
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: MusicService.hasPlayer
            spacing: Style.spacing

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Label {
                    Layout.fillWidth: true
                    text: MusicService.title || MusicService.text("unknown_track")
                    role: "titleLarge"
                }

                Label {
                    Layout.fillWidth: true
                    text: MusicService.artist || MusicService.text("unknown_artist")
                    role: "bodyLarge"
                    color: Theme.inkSurfaceVariant
                }
            }

            IconButton {
                visible: MusicService.online
                icon: MusicService.liked ? Icons.liked : Icons.like
                variant: "toggle"
                selected: MusicService.liked
                compact: true
                description: MusicService.text(MusicService.liked ? "unlike" : "like")
                onClicked: MusicService.toggleLike()
            }

            IconButton {
                visible: MusicService.player?.canRaise ?? false
                icon: Icons.openExternal
                compact: true
                description: MusicService.text("open_player")
                onClicked: MusicService.raise()
            }
        }

        Slider {
            Layout.fillWidth: true
            visible: MusicService.hasPlayer && MusicService.length > 0
            trackHeight: Style.spacing * 2
            enabled: MusicService.canSeek
            value: MusicService.progress
            description: MusicService.text("now_playing")
            live: false
            onCommitted: fraction => MusicService.seekTo(fraction)
        }

        RowLayout {
            Layout.fillWidth: true
            visible: MusicService.hasPlayer && MusicService.length > 0

            Label {
                text: MusicService.clock(MusicService.position)
                role: "labelSmall"
                color: Theme.inkSurfaceVariant
            }

            Item {
                Layout.fillWidth: true
            }

            Label {
                text: MusicService.clock(MusicService.length)
                role: "labelSmall"
                color: Theme.inkSurfaceVariant
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: MusicService.hasPlayer
            spacing: 0

            IconButton {
                visible: MusicService.shuffleSupported
                icon: Icons.shuffle
                variant: "toggle"
                compact: true
                selected: MusicService.player?.shuffle ?? false
                description: MusicService.text("shuffle")
                onClicked: MusicService.toggleShuffle()
            }

            Item {
                Layout.fillWidth: true
            }

            IconButton {
                icon: Icons.skipPrevious
                enabled: MusicService.canPrevious
                description: MusicService.text("previous")
                onClicked: MusicService.previous()
            }

            IconButton {
                icon: MusicService.playing ? Icons.pausePlayback : Icons.play
                variant: "filled"
                enabled: MusicService.player?.canTogglePlaying ?? false
                description: MusicService.text(MusicService.playing ? "pause" : "play")
                onClicked: MusicService.playPause()
            }

            IconButton {
                icon: Icons.skipNext
                enabled: MusicService.canNext
                description: MusicService.text("next")
                onClicked: MusicService.next()
            }

            Item {
                Layout.fillWidth: true
            }

            IconButton {
                visible: MusicService.loopSupported
                icon: root.loopOne ? Icons.repeatOne : Icons.repeatAll
                variant: "toggle"
                compact: true
                selected: root.loopAll || root.loopOne
                description: MusicService.text(root.loopOne ? "repeat_one" : "repeat")
                onClicked: MusicService.cycleLoop()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: MusicService.hasPlayer && MusicService.volumeSupported
            spacing: Style.buttonGap

            MaterialIcon {
                text: MusicService.player?.volume > 0.5 ? Icons.volumeHigh : MusicService.player?.volume > 0 ? Icons.volumeMedium : Icons.volumeMuted
                color: Theme.inkSurfaceVariant
            }

            Slider {
                Layout.fillWidth: true
                trackHeight: Style.spacing * 2
                value: MusicService.player?.volume ?? 0
                description: MusicService.text("volume")
                onMoved: value => MusicService.setVolume(value)
            }
        }

        Flow {
            Layout.fillWidth: true
            visible: MusicService.players.length > 1
            spacing: Style.spacing

            Repeater {
                model: MusicService.players

                Chip {
                    required property var modelData

                    text: modelData.identity || modelData.dbusName
                    selected: MusicService.player === modelData
                    onClicked: MusicService.preferred = modelData.dbusName
                }
            }
        }
    }

    Divider {
        vertical: true
    }

    ColumnLayout {
        Layout.preferredWidth: Style.musicPaneWidth
        Layout.minimumWidth: Style.musicPaneWidth
        Layout.maximumWidth: Style.musicPaneWidth
        Layout.fillHeight: true
        spacing: Style.spacing

        Label {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.tabHeight
            Layout.leftMargin: Style.spacing
            text: MusicService.text("up_next")
            role: "titleSmall"
            color: Theme.primary
        }

        EmptyState {
            Layout.fillHeight: true
            visible: MusicService.upNext.length === 0
            icon: Icons.emptyQueue
            title: MusicService.text("no_queue")
            supporting: MusicService.text("no_queue_help")
        }

        TrackList {
            visible: MusicService.upNext.length > 0
            model: MusicService.upNext
            follow: MusicService.queueIndex
            queueable: false

            onActivated: entry => MusicService.playQueued(entry)
        }
    }

    component TrackList: ListView {
        id: list

        property bool queueable: true
        property int follow: -1

        signal activated(var entry)
        signal queued(var entry)

        Layout.fillWidth: true
        Layout.fillHeight: true

        clip: true
        spacing: Style.listGap
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: follow
        highlightMoveDuration: Style.durMedium1
        Controls.ScrollBar.vertical: ListScrollBar {}

        onFollowChanged: if (follow >= 0)
            positionViewAtIndex(follow, ListView.Contain)

        delegate: ListRow {
            id: trackRow

            required property var modelData
            required property int index

            width: list.width
            first: index === 0
            last: index === list.count - 1
            artwork: modelData.art
            icon: Icons.musicNote
            headline: modelData.title
            supporting: [modelData.artist, modelData.duration].filter(part => part !== "").join(" · ")
            selected: modelData.current === true

            onClicked: list.activated(modelData)

            IconButton {
                visible: list.queueable && trackRow.modelData.videoId !== ""
                icon: Icons.queue
                compact: true
                description: MusicService.text("add_to_queue")
                onClicked: list.queued(trackRow.modelData)
            }
        }
    }
}
