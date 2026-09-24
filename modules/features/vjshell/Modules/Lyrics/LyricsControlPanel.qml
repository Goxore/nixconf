import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services
import qs.Widgets

Panel {
    id: root

    property string artistInput: ""
    property string titleInput: ""

    readonly property string status: MusicLyricsService.fetchStatus
    readonly property bool hasTrack: MusicLyricsService.currentArtist !== "" || MusicLyricsService.currentTitle !== ""
    readonly property bool dirty: artistInput !== MusicLyricsService.effectiveArtist || titleInput !== MusicLyricsService.effectiveTitle
    readonly property var providers: [
        {
            key: "musixmatch",
            label: "Musixmatch"
        },
        {
            key: "lrclib",
            label: "LRCLIB"
        }
    ]

    function labelOf(key) {
        return providers.find(provider => provider.key === key)?.label ?? key;
    }

    function resetInputs() {
        artistInput = MusicLyricsService.effectiveArtist;
        titleInput = MusicLyricsService.effectiveTitle;
    }

    name: "lyricsControl"
    title: "Lyrics"

    onOpenedChanged: if (opened)
        resetInputs()

    Connections {
        target: MusicLyricsService

        function onTrackKeyChanged() {
            root.resetInputs();
        }
    }

    ListGroup {
        ListRow {
            Layout.fillWidth: true
            interactive: false
            artwork: MusicService.art
            icon: Icons.musicNote
            headline: root.hasTrack ? MusicLyricsService.currentTitle : "Nothing playing"
            supporting: {
                if (!root.hasTrack)
                    return "Play a song to see lyrics";
                switch (root.status) {
                case "fetching":
                    return "Looking up lyrics";
                case "found":
                    return "Lyrics from " + root.labelOf(MusicLyricsService.activeProvider);
                default:
                    return MusicLyricsService.currentArtist;
                }
            }

            Spinner {
                visible: root.status === "fetching"
                Layout.rightMargin: Style.buttonGap
            }

            MaterialIcon {
                visible: root.status === "found"
                Layout.rightMargin: Style.buttonGap
                text: Icons.checkCircle
                fill: 1
                color: Theme.success
            }
        }
    }

    Notice {
        visible: root.hasTrack && (root.status === "notfound" || root.status === "error")
        tone: root.status === "error" ? "error" : "warning"
        icon: root.status === "error" ? Icons.error : Icons.help
        text: root.status === "error" ? "Lyrics could not be fetched. Check your connection." : "No lyrics for this name. Try another artist or title below."
    }

    Section {
        title: "Source"

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.buttonGap

            Repeater {
                model: root.providers

                Chip {
                    required property var modelData

                    text: modelData.label
                    selected: MusicLyricsService.provider === modelData.key
                    enabled: root.hasTrack
                    onClicked: MusicLyricsService.setProvider(modelData.key)
                }
            }
        }

        Label {
            Layout.fillWidth: true
            visible: MusicLyricsService.activeProvider !== "" && MusicLyricsService.activeProvider !== MusicLyricsService.provider
            text: "Showing " + root.labelOf(MusicLyricsService.activeProvider) + " because " + root.labelOf(MusicLyricsService.provider) + " had none"
            role: "bodySmall"
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            color: Theme.inkSurfaceVariant
        }
    }

    Section {
        title: "Search as"

        TextField {
            variant: "field"
            label: "Artist"
            text: root.artistInput
            enabled: root.hasTrack
            onEdited: value => root.artistInput = value
            onAccepted: search.clicked()
        }

        TextField {
            Layout.topMargin: Style.spacing
            variant: "field"
            label: "Title"
            text: root.titleInput
            enabled: root.hasTrack
            onEdited: value => root.titleInput = value
            onAccepted: search.clicked()
        }

        RowLayout {
            Layout.alignment: Qt.AlignRight
            Layout.topMargin: Style.buttonGap
            spacing: Style.buttonGap

            Button {
                visible: MusicLyricsService.override !== null
                text: "Use original"
                variant: "text"
                onClicked: {
                    MusicLyricsService.clearOverride();
                    root.resetInputs();
                }
            }

            Button {
                id: search

                text: "Search"
                variant: "filled"
                enabled: root.hasTrack && root.dirty && root.artistInput !== "" && root.titleInput !== ""
                onClicked: if (enabled)
                    MusicLyricsService.setOverride(root.artistInput, root.titleInput)
            }
        }
    }

    Section {
        title: "On screen"

        Label {
            Layout.fillWidth: true
            text: "While this panel is open, drag the lyrics to move them. Use the corner handles to resize or rotate."
            role: "bodyMedium"
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            color: Theme.inkSurfaceVariant
        }

        Button {
            Layout.topMargin: Style.buttonGap
            icon: Icons.reset
            text: "Reset position"
            variant: "tonal"
            onClicked: MusicLyricsService.requestLayoutReset()
        }
    }
}
