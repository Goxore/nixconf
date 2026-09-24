pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets

Singleton {
    id: root

    readonly property real halfLifeDays: 30
    readonly property real halfLifeMs: halfLifeDays * 24 * 60 * 60 * 1000
    readonly property int maxEntries: 400
    readonly property int listenMs: 20000
    readonly property real floorScore: 0.02

    property var entries: ({})

    readonly property var byVideo: {
        const index = {};
        for (const key in entries) {
            const id = entries[key].videoId;
            if (id)
                index[id] = entries[key];
        }
        return index;
    }

    function keyFor(artist, title) {
        return (artist || "").trim().toLowerCase() + "␟" + (title || "").trim().toLowerCase();
    }

    function decayed(entry, now) {
        if (!entry)
            return 0;
        const age = Math.max(0, now - (entry.lastPlayed || 0));
        return (entry.score || 0) * Math.pow(0.5, age / halfLifeMs);
    }

    function frecency(artist, title, videoId) {
        const now = Date.now();
        const direct = entries[keyFor(artist, title)];
        if (direct)
            return decayed(direct, now);
        return videoId ? decayed(byVideo[videoId], now) : 0;
    }

    function record(artist, title, videoId, art) {
        if (!artist && !title)
            return;

        const key = keyFor(artist, title);
        const now = Date.now();
        const existing = entries[key];

        const next = Object.assign({}, entries);
        next[key] = {
            artist: artist || "",
            title: title || "",
            videoId: videoId || existing?.videoId || "",
            art: art || existing?.art || "",
            score: decayed(existing, now) + 1,
            plays: (existing?.plays || 0) + 1,
            lastPlayed: now
        };

        entries = prune(next);
        historyFile.save();
    }

    function ranked(source) {
        const now = Date.now();
        const rows = [];
        for (const key in source)
            rows.push({
                key: key,
                entry: source[key],
                score: decayed(source[key], now)
            });
        rows.sort((a, b) => b.score - a.score);
        return rows;
    }

    function prune(source) {
        const rows = ranked(source).filter(row => row.score >= floorScore || row.entry.liked === true);
        if (rows.length <= maxEntries && rows.length === Object.keys(source).length)
            return source;

        const kept = {};
        for (const row of rows)
            if (row.entry.liked === true)
                kept[row.key] = row.entry;

        for (const row of rows) {
            if (Object.keys(kept).length >= maxEntries)
                break;
            kept[row.key] = row.entry;
        }
        return kept;
    }

    function shape(entry) {
        return {
            videoId: entry.videoId || "",
            title: entry.title,
            artist: entry.artist,
            album: "",
            duration: "",
            kind: "",
            art: entry.art || ""
        };
    }

    function top(limit) {
        return ranked(entries).slice(0, limit).map(row => shape(row.entry));
    }

    function isLiked(artist, title, videoId) {
        const direct = entries[keyFor(artist, title)];
        if (direct)
            return direct.liked === true;
        return videoId ? byVideo[videoId]?.liked === true : false;
    }

    function setLiked(artist, title, videoId, art, liked) {
        if (!artist && !title)
            return;

        const key = keyFor(artist, title);
        const existing = entries[key];

        const next = Object.assign({}, entries);
        next[key] = Object.assign({}, existing || {
            artist: artist || "",
            title: title || "",
            score: 0,
            plays: 0,
            lastPlayed: Date.now()
        }, {
            videoId: videoId || existing?.videoId || "",
            art: art || existing?.art || "",
            liked: liked
        });

        entries = next;
        historyFile.save();
    }

    property bool loaded: false

    function adopt(stored) {
        const now = Date.now();
        const merged = Object.assign({}, stored || ({}));

        for (const key in entries) {
            const mine = entries[key];
            const theirs = merged[key];
            merged[key] = !theirs || decayed(mine, now) >= decayed(theirs, now) ? mine : theirs;
        }

        entries = prune(merged);
        loaded = true;
    }

    JsonStore {
        id: historyFile

        path: Paths.cache("music-history.json")

        onLoaded: root.adopt(adapter.entries)
        onLoadFailed: error => root.adopt({})

        JsonAdapter {
            property var entries: root.entries
        }
    }
}
