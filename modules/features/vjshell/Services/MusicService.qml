pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Commons
import qs.Widgets

Singleton {
    id: root

    readonly property string endpoint: Quickshell.env("VJSHELL_YTMUSIC_API") || "http://127.0.0.1:26538"

    readonly property var words: copy.words

    property Copy copy: Copy {
        source: Quickshell.shellPath("Modules/Music/copy.json")
    }

    function text(key, values) {
        return copy.text(key, values);
    }

    readonly property list<MprisPlayer> players: Mpris.players.values

    property string preferred: ""

    readonly property MprisPlayer player: {
        const chosen = players.find(candidate => candidate.dbusName === preferred);
        if (chosen)
            return chosen;

        const loaded = candidate => (candidate.trackTitle || "") !== "";

        return players.find(candidate => candidate.playbackState === MprisPlaybackState.Playing) ?? players.find(candidate => candidate.playbackState === MprisPlaybackState.Paused && loaded(candidate)) ?? players.find(loaded) ?? players[0] ?? null;
    }

    readonly property bool hasPlayer: player !== null
    readonly property bool playing: player ? player.playbackState === MprisPlaybackState.Playing : false

    readonly property string title: player?.trackTitle || ""
    readonly property string artist: player?.trackArtist || ""
    readonly property string art: player?.trackArtUrl || ""

    readonly property real length: player?.lengthSupported ? player.length : 0
    readonly property real position: player?.positionSupported ? player.position : 0
    readonly property real progress: length > 0 ? Math.max(0, Math.min(1, position / length)) : 0

    readonly property bool canSeek: player?.canSeek ?? false
    readonly property bool canNext: player?.canGoNext ?? false
    readonly property bool canPrevious: player?.canGoPrevious ?? false
    readonly property bool volumeSupported: player?.volumeSupported ?? false
    readonly property bool shuffleSupported: player?.shuffleSupported ?? false
    readonly property bool loopSupported: player?.loopSupported ?? false

    readonly property bool active: PanelService.isOpen("music")

    function clock(seconds) {
        if (!isFinite(seconds) || seconds < 0)
            return "0:00";
        const total = Math.floor(seconds);
        const minutes = Math.floor(total / 60);
        const rest = total % 60;
        return minutes + ":" + (rest < 10 ? "0" : "") + rest;
    }

    function playPause() {
        if (player?.canTogglePlaying)
            player.togglePlaying();
    }

    function next() {
        if (canNext)
            player.next();
    }

    function previous() {
        if (canPrevious)
            player.previous();
    }

    function seekTo(fraction) {
        if (canSeek && length > 0)
            player.position = fraction * length;
    }

    function setVolume(value) {
        if (volumeSupported)
            player.volume = Math.max(0, Math.min(1, value));
    }

    function toggleShuffle() {
        if (shuffleSupported)
            player.shuffle = !player.shuffle;
    }

    function cycleLoop() {
        if (!loopSupported)
            return;
        switch (player.loopState) {
        case MprisLoopState.None:
            player.loopState = MprisLoopState.Playlist;
            break;
        case MprisLoopState.Playlist:
            player.loopState = MprisLoopState.Track;
            break;
        default:
            player.loopState = MprisLoopState.None;
        }
    }

    function raise() {
        if (player?.canRaise)
            player.raise();
    }

    readonly property string trackKey: artist + "␟" + title

    property string rememberedKey: ""

    function rememberCurrent() {
        const heardArtist = artist;
        const heardTitle = title;
        const heardArt = art;
        const heardKey = trackKey;

        if (heardTitle === "")
            return;

        rememberedKey = heardKey;

        request("GET", "/api/v1/song", null, (ok, body) => {
            let videoId = "";
            if (ok) {
                try {
                    const song = JSON.parse(body);
                    if ((song.title || "") === heardTitle)
                        videoId = song.videoId || "";
                } catch (error) {}
            }
            MusicHistoryService.record(heardArtist, heardTitle, videoId, heardArt);
        });
    }

    function watchListen() {
        if (playing && title !== "" && rememberedKey !== trackKey)
            listen.restart();
        else
            listen.stop();
    }

    onTrackKeyChanged: watchListen()
    onPlayingChanged: watchListen()

    Timer {
        id: listen
        interval: MusicHistoryService.listenMs
        onTriggered: root.rememberCurrent()
    }

    property bool online: false
    property string query: ""
    property var results: []
    property bool searching: false
    property string searchError: ""

    property int generation: 0

    function request(method, path, body, onDone) {
        HttpService.send(method, root.endpoint + path, body, (status, text) => {
            root.online = status !== 0;
            if (onDone)
                onDone(HttpService.ok(status), text);
        });
    }

    function runs(column) {
        const list = column?.musicResponsiveListItemFlexColumnRenderer?.text?.runs;
        return Array.isArray(list) ? list.map(run => run.text) : [];
    }

    function readItem(item) {
        if (!item)
            return null;

        const columns = item.flexColumns || [];
        const primary = runs(columns[0]);
        const secondary = runs(columns[1]);

        const videoId = item.overlay?.musicItemThumbnailOverlayRenderer?.content?.musicPlayButtonRenderer?.playNavigationEndpoint?.watchEndpoint?.videoId || item.playlistItemData?.videoId || "";

        if (videoId === "")
            return null;

        const detail = describe(secondary);
        const thumbs = item.thumbnail?.musicThumbnailRenderer?.thumbnail?.thumbnails || [];

        return {
            videoId: videoId,
            kind: detail.kind,
            title: primary.join("") || "",
            artist: detail.artist,
            album: detail.album,
            duration: detail.duration,
            art: thumbs.length > 0 ? thumbs[thumbs.length - 1].url : ""
        };
    }

    function describe(runTexts) {
        const parts = (runTexts || []).map(part => part.trim()).filter(part => part !== "" && part !== "•");

        const kinds = ["Song", "Video", "Album", "Artist", "Playlist", "Single", "EP", "Podcast", "Episode"];
        const kind = parts.length > 0 && kinds.indexOf(parts[0]) !== -1 ? parts.shift() : "";

        const isDuration = part => /^\d+:\d{2}(:\d{2})?$/.test(part);
        const isCount = part => /(plays|views|subscribers)$/.test(part);
        const isYear = part => /^\d{4}$/.test(part);

        const meta = parts.filter(part => !isDuration(part) && !isCount(part) && !isYear(part));

        return {
            kind: kind,
            artist: meta[0] || "",
            album: meta[1] || "",
            duration: parts.find(isDuration) || ""
        };
    }

    function collectRows(node, rows, depth) {
        if (!node || depth > 12)
            return;

        if (Array.isArray(node)) {
            for (const item of node)
                collectRows(item, rows, depth + 1);
            return;
        }

        if (typeof node !== "object")
            return;

        if (node.musicResponsiveListItemRenderer) {
            rows.push(node.musicResponsiveListItemRenderer);
            return;
        }

        for (const key in node)
            collectRows(node[key], rows, depth + 1);
    }

    function parseSearch(payload) {
        const tab = payload?.contents?.tabbedSearchResultsRenderer?.tabs?.[0]?.tabRenderer?.content;

        const found = [];
        const seen = {};

        const push = entry => {
            if (!entry || seen[entry.videoId])
                return;
            seen[entry.videoId] = true;
            found.push(entry);
        };

        const card = tab?.sectionListRenderer?.contents?.find(section => section.musicCardShelfRenderer)?.musicCardShelfRenderer;
        const cardVideo = card?.onTap?.watchEndpoint?.videoId || "";
        if (cardVideo !== "") {
            const thumbs = card.thumbnail?.musicThumbnailRenderer?.thumbnail?.thumbnails || [];
            const detail = describe((card.subtitle?.runs || []).map(run => run.text));
            push({
                videoId: cardVideo,
                kind: detail.kind,
                title: (card.title?.runs || []).map(run => run.text).join(""),
                artist: detail.artist,
                album: detail.album,
                duration: detail.duration,
                art: thumbs.length > 0 ? thumbs[thumbs.length - 1].url : ""
            });
        }

        const rows = [];
        collectRows(tab, rows, 0);
        for (const row of rows)
            push(readItem(row));

        return found;
    }

    function rank(list) {
        const scored = list.map((entry, index) => {
            const weight = MusicHistoryService.frecency(entry.artist, entry.title, entry.videoId);
            return {
                entry: entry,
                score: weight > 0 ? 3 + Math.log(1 + weight) * 2 - index : -index
            };
        });
        scored.sort((a, b) => b.score - a.score);
        return scored.map(row => row.entry);
    }

    function search() {
        const text = query.trim();
        generation++;
        const mine = generation;

        if (text === "") {
            results = MusicHistoryService.top(25);
            searching = false;
            searchError = "";
            return;
        }

        searching = true;
        searchError = "";

        request("POST", "/api/v1/search", {
            query: text
        }, (ok, body) => {
            if (mine !== root.generation)
                return;
            root.searching = false;
            if (!ok) {
                root.results = [];
                root.searchError = "unreachable";
                return;
            }
            try {
                root.results = root.rank(root.parseSearch(JSON.parse(body)));
                root.searchError = root.results.length === 0 ? "empty" : "";
            } catch (error) {
                root.results = [];
                root.searchError = "unreadable";
            }
        });
    }

    property bool playWhenReady: false

    function playTop() {
        const best = results.find(entry => entry.videoId !== "");
        if (best && !searching) {
            playWhenReady = false;
            playNow(best.videoId);
            return;
        }
        playWhenReady = true;
    }

    onResultsChanged: if (playWhenReady && !searching) {
        const best = results.find(entry => entry.videoId !== "");
        playWhenReady = false;
        if (best)
            playNow(best.videoId);
    }

    function queue(videoId, done) {
        request("POST", "/api/v1/queue", {
            videoId: videoId,
            insertPosition: "INSERT_AFTER_CURRENT_VIDEO"
        }, done || null);
    }

    property string awaitedVideoId: ""
    property int awaitedTries: 0

    readonly property int settleTries: 25

    function playNow(videoId) {
        if (awaitedVideoId === videoId)
            return;

        queue(videoId, ok => {
            if (!ok)
                return;
            root.awaitedVideoId = videoId;
            root.awaitedTries = 0;
            settle.restart();
        });
    }

    function findAwaited(rows) {
        const current = rows.findIndex(row => row.current);

        if (current < 0)
            return rows.length > 0 && rows[0].videoId === awaitedVideoId ? 0 : -1;

        if (rows[current].videoId === awaitedVideoId)
            return current;

        const after = current + 1;
        return after < rows.length && rows[after].videoId === awaitedVideoId ? after : -1;
    }

    function settleStep() {
        resolveQueue(rows => {
            if (rows) {
                root.adoptQueue(rows);
                const landed = root.findAwaited(rows);
                if (landed >= 0) {
                    root.awaitedVideoId = "";
                    if (landed !== root.queueIndex)
                        root.jumpTo(landed);
                    return;
                }
            }

            root.awaitedTries++;
            if (root.awaitedTries < root.settleTries)
                settle.restart();
            else
                root.awaitedVideoId = "";
        });
    }

    Timer {
        id: settle
        interval: 120
        onTriggered: root.settleStep()
    }

    property var upNext: []
    property int queueIndex: -1
    property bool liked: false

    property var likedRows: []
    property bool likedSignedIn: true

    readonly property bool likedLoading: likedFetch.loading

    function loadLiked() {
        if (likedLoading)
            return;
        likedFetch.request = {
            command: [Quickshell.env("VJMUSIC_BIN") || "vjmusic", "liked"],
            context: null
        };
    }

    RequestProcess {
        id: likedFetch

        timeout: 60000
        onFinished: (code, output) => {
            let rows = null;
            try {
                rows = code === 0 ? JSON.parse(output.trim().split("\n").pop()) : null;
            } catch (error) {}
            root.likedRows = rows ?? [];
            root.likedSignedIn = rows !== null;
            likedFetch.request = null;
        }
    }

    function readQueue(payload) {
        const items = payload?.items || [];
        const rows = [];

        for (var index = 0; index < items.length; index++) {
            const item = items[index].playlistPanelVideoRenderer;
            if (!item || !item.videoId)
                continue;

            const thumbs = item.thumbnail?.thumbnails || [];
            rows.push({
                videoId: item.videoId,
                index: index,
                current: item.selected === true,
                title: item.title?.runs?.[0]?.text || "",
                artist: item.shortBylineText?.runs?.[0]?.text || "",
                album: "",
                kind: "",
                duration: item.lengthText?.runs?.[0]?.text || "",
                art: thumbs.length > 0 ? thumbs[0].url : ""
            });
        }

        return rows;
    }

    function resolveQueue(onReady) {
        request("GET", "/api/v1/queue-info", null, (ok, body) => {
            if (!ok) {
                onReady(null);
                return;
            }
            try {
                onReady(root.readQueue(JSON.parse(body)));
            } catch (error) {
                onReady(null);
            }
        });
    }

    function adoptQueue(rows) {
        root.upNext = rows || [];
        root.queueIndex = root.upNext.findIndex(row => row.current);
    }

    function refreshQueue() {
        resolveQueue(rows => root.adoptQueue(rows));
    }

    function playQueued(entry) {
        resolveQueue(rows => {
            if (!rows)
                return;

            root.adoptQueue(rows);

            const index = rows[entry.index]?.videoId === entry.videoId ? entry.index : rows.findIndex(row => row.videoId === entry.videoId);

            if (index >= 0 && index !== root.queueIndex)
                root.jumpTo(index);
        });
    }

    function jumpTo(index) {
        request("PATCH", "/api/v1/queue", {
            index: index
        }, ok => {
            if (ok)
                root.refreshQueue();
        });
    }

    function refreshLiked() {
        request("GET", "/api/v1/like-state", null, (ok, body) => {
            if (!ok)
                return;
            try {
                root.liked = JSON.parse(body).state === "LIKE";
            } catch (error) {
                root.liked = false;
            }

            if (root.title !== "" && MusicHistoryService.isLiked(root.artist, root.title, "") !== root.liked)
                MusicHistoryService.setLiked(root.artist, root.title, "", root.art, root.liked);
        });
    }

    function toggleLike() {
        const wanted = !liked;
        liked = wanted;
        MusicHistoryService.setLiked(artist, title, "", art, wanted);
        request("POST", "/api/v1/like", null, () => root.refreshLiked());
    }

    function probe() {
        request("GET", "/api/v1/song", null, null);
        refreshQueue();
        refreshLiked();
    }

    onQueryChanged: {
        playWhenReady = false;
        searching = query.trim() !== "";
        searchDebounce.restart();
    }

    onActiveChanged: {
        if (!active)
            return;
        if (query.trim() === "")
            search();
        if (likedRows.length === 0)
            loadLiked();
    }

    Timer {
        id: searchDebounce
        interval: Style.durMedium2
        onTriggered: root.search()
    }

    Timer {
        running: (root.active || MusicLyricsService.visible) && root.playing && root.canSeek
        interval: 200
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    Timer {
        running: root.active
        interval: 5000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.probe()
    }

    IpcHandler {
        target: "music"

        function toggle(): void {
            PanelService.toggle("music");
        }
        function open(): void {
            PanelService.open("music");
        }
        function close(): void {
            PanelService.close("music");
        }
        function playPause(): void {
            root.playPause();
        }
        function next(): void {
            root.next();
        }
        function previous(): void {
            root.previous();
        }
    }
}
