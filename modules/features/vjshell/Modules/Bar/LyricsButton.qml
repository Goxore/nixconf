import qs.Commons
import qs.Services
import qs.Widgets

BarButton {
    readonly property bool open: PanelService.isOpen("lyricsControl", screenName)
    readonly property string status: MusicLyricsService.fetchStatus
    readonly property bool missing: status === "notfound" || status === "error"

    visible: MusicLyricsService.visible

    icon: status === "fetching" ? Icons.hourglassTop : missing ? Icons.help : Icons.lyrics
    iconColor: missing ? Theme.warning : open || status === "found" ? Theme.primary : Theme.inkSurfaceVariant
    iconFill: open || status === "found" ? 1 : 0
    tooltip: MusicLyricsService.currentTitle ? "Lyrics for " + MusicLyricsService.currentTitle : "Lyrics"

    onClicked: PanelService.toggle("lyricsControl", screenName)
}
