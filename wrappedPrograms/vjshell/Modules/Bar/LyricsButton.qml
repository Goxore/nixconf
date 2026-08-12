import QtQuick
import qs.Commons
import qs.Services
import qs.Widgets

BarButton {
    id: root

    visible: MusicLyricsService.visible

    icon: {
        switch (MusicLyricsService.fetchStatus) {
        case "fetching":
            return Icons.hourglassTop;
        case "found":
            return Icons.checkCircle;
        case "notfound":
        case "error":
            return Icons.help;
        default:
            return Icons.musicNote;
        }
    }

    iconColor: {
        switch (MusicLyricsService.fetchStatus) {
        case "found":
            return Theme.active;
        case "notfound":
        case "error":
            return Theme.urgent;
        default:
            return PanelService.isOpen("lyricsControl") ? Theme.accent : Theme.text;
        }
    }

    iconFill: PanelService.isOpen("lyricsControl") ? 1 : 0

    tooltip: MusicLyricsService.currentTitle ? "Lyrics: " + MusicLyricsService.currentTitle : "Lyrics"

    onClicked: PanelService.toggle("lyricsControl")
}
