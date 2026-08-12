import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services
import qs.Widgets

Panel {
    id: root

    panelName: "lyricsControl"
    title: "Lyrics"
    icon: Icons.musicNote

    property string artistInput: MusicLyricsService.effectiveArtist
    property string titleInput: MusicLyricsService.effectiveTitle

    readonly property bool hasTrack: MusicLyricsService.currentArtist !== "" || MusicLyricsService.currentTitle !== ""
    readonly property bool dirty: artistInput !== MusicLyricsService.effectiveArtist || titleInput !== MusicLyricsService.effectiveTitle

    onOpenedChanged: if (opened) {
        artistInput = MusicLyricsService.effectiveArtist;
        titleInput = MusicLyricsService.effectiveTitle;
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing

        MaterialIcon {
            text: {
                if (!root.hasTrack)
                    return Icons.musicNote;
                switch (MusicLyricsService.fetchStatus) {
                case "fetching":
                    return Icons.hourglassTop;
                case "found":
                    return Icons.checkCircle;
                case "error":
                    return Icons.error;
                case "notfound":
                    return Icons.help;
                default:
                    return Icons.musicNote;
                }
            }
            font.pixelSize: Style.iconSizeXl
            color: {
                switch (MusicLyricsService.fetchStatus) {
                case "found":
                    return Theme.active;
                case "notfound":
                case "error":
                    return Theme.urgent;
                default:
                    return Theme.textDim;
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: root.hasTrack ? MusicLyricsService.currentTitle : "Nothing playing"
                elide: Text.ElideRight
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSize
                font.weight: Font.Bold
                color: Theme.textBright
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: MusicLyricsService.currentArtist
                elide: Text.ElideRight
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSizeSmall
                color: Theme.textDim
            }
        }
    }

    Text {
        Layout.fillWidth: true
        visible: root.hasTrack
        wrapMode: Text.WordWrap
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSizeSmall
        color: Theme.textDim
        text: {
            switch (MusicLyricsService.fetchStatus) {
            case "fetching":
                return "Looking up lyrics...";
            case "found":
                return "Lyrics found";
            case "notfound":
                return "No lyrics found for this track name — try overriding it below";
            case "error":
                return "Network error while fetching lyrics";
            default:
                return "";
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: Style.dividerWidth
        color: Theme.surfaceHigh
    }

    Text {
        Layout.fillWidth: true
        text: "Override name used for lookup"
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSizeSmall
        font.weight: Font.Bold
        color: Theme.text
    }

    LyricsField {
        Layout.fillWidth: true
        label: "Artist"
        text: root.artistInput
        onTextEdited: value => root.artistInput = value
    }

    LyricsField {
        Layout.fillWidth: true
        label: "Title"
        text: root.titleInput
        onTextEdited: value => root.titleInput = value
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing

        PanelButton {
            icon: Icons.check
            text: "Apply"
            accent: true
            enabled: root.hasTrack && root.dirty && root.artistInput !== "" && root.titleInput !== ""
            onClicked: MusicLyricsService.setOverride(root.artistInput, root.titleInput)
        }

        PanelButton {
            icon: Icons.remove
            text: "Clear override"
            visible: MusicLyricsService.override !== null
            onClicked: {
                MusicLyricsService.clearOverride();
                root.artistInput = MusicLyricsService.effectiveArtist;
                root.titleInput = MusicLyricsService.effectiveTitle;
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: Style.dividerWidth
        color: Theme.surfaceHigh
    }

    PanelButton {
        Layout.fillWidth: true
        icon: Icons.reset
        text: "Reset lyrics position"
        onClicked: MusicLyricsService.requestLayoutReset()
    }

    Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: "While this panel is open, drag the on-screen lyrics to move them, and use the corner handles to resize or rotate."
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSizeSmall
        color: Theme.textDim
    }

    component LyricsField: ColumnLayout {
        id: field

        required property string label
        property string text: ""

        signal textEdited(string value)

        onTextChanged: if (input.text !== text)
            input.text = text

        spacing: 2

        Text {
            text: field.label
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
            color: Theme.textDim
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Style.rowHeightS
            radius: Style.radiusS
            color: Theme.surfaceVariant
            border.width: input.activeFocus ? Style.borderWidth : 0
            border.color: Theme.accent

            TextInput {
                id: input

                anchors.fill: parent
                anchors.leftMargin: Style.spacing
                anchors.rightMargin: Style.spacing
                verticalAlignment: TextInput.AlignVCenter
                clip: true

                text: field.text
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSize
                color: Theme.text
                selectionColor: Theme.accent
                selectedTextColor: Theme.surface

                onTextEdited: field.textEdited(text)
            }

            TapHandler {
                onTapped: input.forceActiveFocus()
            }
        }
    }
}
