pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets

Singleton {
    id: root

    readonly property int maxAgeDays: 90
    readonly property real maxAgeMs: maxAgeDays * 24 * 60 * 60 * 1000

    property var entries: ({})

    function keyFor(artist, title) {
        return (artist || "").trim().toLowerCase() + "\u0000" + (title || "").trim().toLowerCase();
    }

    function lookup(artist, title) {
        if (!artist && !title)
            return null;

        const entry = entries[keyFor(artist, title)];
        if (!entry)
            return null;

        entry.accessedAt = Date.now();
        cacheFile.save();
        return entry;
    }

    function store(artist, title, patch) {
        if (!artist && !title)
            return;

        const key = keyFor(artist, title);
        const entry = Object.assign({}, entries[key] || {}, patch);
        entry.accessedAt = Date.now();

        const next = Object.assign({}, entries);
        next[key] = entry;
        entries = next;
        cacheFile.save();
    }

    function storeLyrics(artist, title, provider, lyrics) {
        const existing = entries[keyFor(artist, title)];
        const byProvider = Object.assign({}, (existing && existing.lyrics) || {});
        byProvider[provider] = lyrics;
        store(artist, title, {
            lyrics: byProvider
        });
    }

    function lyricsFor(artist, title, provider) {
        const entry = lookup(artist, title);
        if (!entry || !entry.lyrics)
            return "";
        return entry.lyrics[provider] || "";
    }

    function collect() {
        const cutoff = Date.now() - maxAgeMs;
        const kept = {};
        for (const key in entries)
            if ((entries[key].accessedAt || 0) >= cutoff)
                kept[key] = entries[key];
        if (Object.keys(kept).length === Object.keys(entries).length)
            return;
        entries = kept;
        cacheFile.save();
    }

    JsonStore {
        id: cacheFile

        path: Paths.cache("lyrics.json")

        onLoaded: {
            root.entries = adapter.entries || ({});
            root.collect();
        }
        onLoadFailed: error => root.entries = ({})

        JsonAdapter {
            property var entries: root.entries
        }
    }
}
