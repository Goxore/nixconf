pragma Singleton
import QtQuick 2.15
import Quickshell.Services.Mpris
import Quickshell
import Quickshell.Io

Singleton {
    id: musicLyricsService
    readonly property list<MprisPlayer> players: Mpris.players.values
    readonly property MprisPlayer player: players[0] ?? null

    property string currentArtist: player ? player.trackArtist : ""
    property string currentTitle: player ? player.trackTitle : ""
    property string currentAlbum: player ? player.trackAlbum : ""

    property string syncedLyrics: ""
    property string plainLyrics: ""

    property bool visible: false

    property var parsedSyncedLyrics: {
        if (syncedLyrics === "" || syncedLyrics === null) {
            return [];
        }

        let raw = syncedLyrics || "";
        let rawLines = raw.split(/\r?\n/).map(s => s.trim()).filter(s => s.length > 0);

        let perLine = rawLines.map(line => {
            let matches = line.match(/\[(\d+:\d{2}(?:[.,]\d+)?)\]/g) || [];
            let times = matches.map(m => m.replace(/[\[\]]/g, ''));
            let text = line.replace(/\[(\d+:\d{2}(?:[.,]\d+)?)\]/g, '').trim();
            return times.map(t => ({
                        time: musicLyricsService.timeToSeconds(t),
                        text: text
                    }));
        });

        let flat = perLine.reduce((acc, cur) => acc.concat(cur), []);
        flat.sort((a, b) => a.time - b.time);

        return flat;
    }

    property int currentLyricIndex: {
        const index = parsedSyncedLyrics.findIndex(item => item.time > musicLyricsService.player.position);
        return index === -1 ? -1 : index - 1;
    }

    property string previousLine: (currentLyricIndex > 0) ? parsedSyncedLyrics[currentLyricIndex - 1].text : ""

    property string currentLine: (currentLyricIndex >= 0) ? parsedSyncedLyrics[currentLyricIndex].text : ""

    property string nextLine: (currentLyricIndex >= 0 && currentLyricIndex < parsedSyncedLyrics.length - 1) ? parsedSyncedLyrics[currentLyricIndex + 1].text : ""

    function buildUrl(artist, title, album) {
        let a = artist ? encodeURIComponent(artist).replace(/%20/g, "_") : "";
        let t = title ? encodeURIComponent(title).replace(/%20/g, "_") : "";
        let al = album ? encodeURIComponent(album).replace(/%20/g, "_") : "";
        return "https://lrclib.net/api/get?artist_name=" + a + "&track_name=" + t
    }

    function fetchLyricsForCurrentTrack() {
        if (!visible)
            return;

        let artist = currentArtist;
        let title = currentTitle;
        let album = currentAlbum;

        if (!artist || !title) {
            return;
        }

        let url = buildUrl(artist, title, album);
        console.log(url);

        let xhr = new XMLHttpRequest();
        xhr.open("GET", url);
        xhr.onreadystatechange = function () {
            if (xhr.status !== 200)
                return;

            let json = JSON.parse(xhr.responseText);
            musicLyricsService.syncedLyrics = json.syncedLyrics;
            musicLyricsService.plainLyrics = json.plainLyrics;

            console.log(xhr.responseText);
        };

        xhr.onerror = function () {
        // lyrics = "Network error while fetching lyrics.";
        };
        xhr.send();
    }

    function timeToSeconds(ts) {
        if (!ts)
            return 0;
        var parts = ts.split(':');
        var minutes = parseInt(parts[0], 10) || 0;
        var seconds = parseFloat(parts[1].replace(',', '.')) || 0;
        return minutes * 60 + seconds;
    }

    Connections {
        target: musicLyricsService.player
        function onTrackArtistChanged(arg) {
            console.log("Track artist changed:", musicLyricsService.player.trackArtist);
            musicLyricsService.fetchLyricsForCurrentTrack();
        }
        function onTrackTitleChanged(arg) {
            console.log("Track changed:", musicLyricsService.player.trackTitle);
            musicLyricsService.fetchLyricsForCurrentTrack();
        }
    }

    IpcHandler {
        target: "musicLyricsService"

        function setVisible(value: bool): void {
            musicLyricsService.visible = value;
        }
        function getVisible(): bool {
            return musicLyricsService.visible;
        }
    }

    onVisibleChanged: {
        console.log("set visible");
        if (visible) {
            fetchLyricsForCurrentTrack();
        }
    }

    Timer {
        running: musicLyricsService.player.playbackState == MprisPlaybackState.Playing
        interval: 200
        repeat: true
        onTriggered: {
            musicLyricsService.player.positionChanged();
        }
    }
}
