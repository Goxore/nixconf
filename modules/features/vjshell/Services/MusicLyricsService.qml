pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets

Singleton {
    id: root

    readonly property string defaultProvider: "musixmatch"
    readonly property var providerNames: ["musixmatch", "lrclib"]

    property bool visible: false
    property var overrides: ({})
    property var providerChoices: ({})

    property string fetchStatus: "idle"
    property string fetchedArtist: ""
    property string fetchedTitle: ""
    property string activeProvider: ""
    property string syncedLyrics: ""
    property bool lyricsFetched: false

    property int generation: 0
    property var lrclibCall: null

    readonly property string currentArtist: MusicService.artist
    readonly property string currentTitle: MusicService.title
    readonly property bool hasTrack: currentArtist !== "" || currentTitle !== ""
    readonly property string trackKey: currentArtist + "\u0000" + currentTitle

    readonly property var override: hasTrack ? overrides[trackKey] ?? null : null
    readonly property string effectiveArtist: override ? override.artist : currentArtist
    readonly property string effectiveTitle: override ? override.title : currentTitle
    readonly property string provider: providerChoices[trackKey] || defaultProvider

    readonly property var parsedSyncedLyrics: parse(syncedLyrics)
    readonly property bool lyricsMatchCurrentTrack: lyricsFetched && fetchedArtist === effectiveArtist && fetchedTitle === effectiveTitle
    readonly property int currentLyricIndex: {
        if (!MusicService.player || parsedSyncedLyrics.length === 0)
            return -1;
        const index = parsedSyncedLyrics.findIndex(line => line.time > MusicService.position);
        return index === -1 ? parsedSyncedLyrics.length - 1 : index - 1;
    }
    readonly property bool shouldShowLyrics: visible && MusicService.playing && lyricsMatchCurrentTrack && parsedSyncedLyrics.length > 0 && currentLyricIndex !== -1

    signal resetLayoutRequested

    function requestLayoutReset() {
        resetLayoutRequested();
    }

    function timeToSeconds(stamp) {
        if (!stamp)
            return 0;
        const [minutes, seconds] = stamp.split(":");
        return (parseInt(minutes, 10) || 0) * 60 + (parseFloat(seconds.replace(",", ".")) || 0);
    }

    function parse(raw) {
        if (!raw)
            return [];
        const lineStamp = /\[(\d+:\d{2}(?:[.,]\d+)?)\]/g;
        const lines = [];
        for (const line of raw.split(/\r?\n/).map(text => text.trim()).filter(text => text !== "")) {
            const times = (line.match(lineStamp) || []).map(stamp => timeToSeconds(stamp.slice(1, -1)));
            const body = line.replace(lineStamp, "");
            const wordStamp = /<(\d+:\d{2}(?:[.,]\d+)?)>([^<]*)/g;
            const words = [];
            for (let match = wordStamp.exec(body); match !== null; match = wordStamp.exec(body))
                if (match[2].trim() !== "")
                    words.push({
                        time: timeToSeconds(match[1]),
                        text: match[2].trim()
                    });
            const text = body.replace(/<\d+:\d{2}(?:[.,]\d+)?>/g, "").replace(/\s+/g, " ").trim();
            for (const time of times)
                lines.push({
                    time: time,
                    text: text,
                    words: words
                });
        }
        return lines.sort((a, b) => a.time - b.time);
    }

    function buildUrl(artist, title) {
        return "https://lrclib.net/api/get?artist_name=" + encodeURIComponent(artist || "") + "&track_name=" + encodeURIComponent(title || "");
    }

    function remember(store, value) {
        const next = Object.assign({}, store);
        if (value === undefined)
            delete next[trackKey];
        else
            next[trackKey] = value;
        return next;
    }

    function setProvider(name) {
        if (!hasTrack)
            return;
        providerChoices = remember(providerChoices, name === defaultProvider ? undefined : name);
        saved.writeAdapter();
        refetch();
    }

    function setOverride(artist, title) {
        if (!hasTrack)
            return;
        overrides = remember(overrides, {
            artist: artist,
            title: title
        });
        saved.writeAdapter();
        refetch();
    }

    function clearOverride() {
        if (!(trackKey in overrides))
            return;
        overrides = remember(overrides, undefined);
        saved.writeAdapter();
        refetch();
    }

    function refetch() {
        lyricsFetched = false;
        fetch();
    }

    function stopFetching() {
        generation++;
        musixmatch.request = null;
        HttpService.cancel(lrclibCall);
        lrclibCall = null;
    }

    function fetch() {
        stopFetching();
        if (!visible || !effectiveArtist || !effectiveTitle) {
            fetchStatus = "idle";
            return;
        }
        const cached = LyricsCacheService.lyricsFor(effectiveArtist, effectiveTitle, provider);
        if (cached !== "") {
            apply(effectiveArtist, effectiveTitle, cached, provider);
            return;
        }
        fetchStatus = "fetching";
        fetchFrom(provider, {
            artist: effectiveArtist,
            title: effectiveTitle,
            fallback: true,
            generation: generation
        });
    }

    function fetchFrom(source, context) {
        if (source === "lrclib") {
            lrclibCall = HttpService.send("GET", buildUrl(context.artist, context.title), null, (status, body) => {
                let lyrics = "";
                try {
                    lyrics = HttpService.ok(status) ? JSON.parse(body).syncedLyrics || "" : "";
                } catch (error) {}
                root.received("lrclib", context, lyrics);
            });
            return;
        }
        musixmatch.request = {
            command: ["syncedlyrics", context.artist + " " + context.title, "-p", "musixmatch", "--synced-only", "--enhanced", "-o", "/dev/null"],
            context: context
        };
    }

    function received(source, context, lyrics) {
        if (context.generation !== generation)
            return;
        if (lyrics !== "") {
            LyricsCacheService.storeLyrics(context.artist, context.title, source, lyrics);
            apply(context.artist, context.title, lyrics, source);
            return;
        }
        if (context.fallback) {
            fetchFrom(providerNames.find(name => name !== source), Object.assign({}, context, {
                fallback: false
            }));
            return;
        }
        fetchStatus = "notfound";
    }

    function apply(artist, title, lyrics, source) {
        fetchedArtist = artist;
        fetchedTitle = title;
        activeProvider = source;
        lyricsFetched = true;
        fetchStatus = "found";
        syncedLyrics = lyrics;
    }

    onTrackKeyChanged: Qt.callLater(refetch)
    onVisibleChanged: if (!visible || !lyricsMatchCurrentTrack)
        fetch()

    Connections {
        target: MusicService

        function onPlayingChanged() {
            if (MusicService.playing && root.visible && !root.lyricsMatchCurrentTrack)
                root.fetch();
        }
    }

    RequestProcess {
        id: musixmatch

        timeout: 30000
        onFinished: (code, output, context) => root.received("musixmatch", context, code === 0 && /\[\d+:\d{2}/.test(output) ? output : "")
    }

    FileView {
        id: saved

        path: Paths.state("vjshell-lyrics.json")
        watchChanges: false
        printErrors: false
        onLoaded: {
            root.overrides = adapter.overrides || ({});
            root.providerChoices = adapter.providers || ({});
        }

        JsonAdapter {
            property var overrides: root.overrides
            property var providers: root.providerChoices
        }
    }

    IpcHandler {
        target: "musicLyricsService"

        function setVisible(value: bool): void {
            root.visible = value;
        }
        function getVisible(): bool {
            return root.visible;
        }
        function toggle(): void {
            root.visible = !root.visible;
        }
    }
}
