pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Widgets

Singleton {
    id: root

    readonly property int chunkBudget: 900
    readonly property int sampleBudget: 600

    readonly property string targetLang: "en"
    readonly property var untranslatedLangs: ["uk", "ru"]

    readonly property var sourceLines: MusicLyricsService.parsedSyncedLyrics.map(entry => entry.text)

    property string language: ""
    property var romanized: []
    property var translations: []

    property string trackArtist: ""
    property string trackTitle: ""
    property string cacheKey: ""
    property bool cacheHit: false

    property string processedKey: ""
    property int generation: 0

    property var chunks: []
    property int chunkAt: 0
    property var draft: []

    readonly property bool romanizedReady: romanized.length === sourceLines.length && sourceLines.length > 0

    function displayLine(index) {
        if (romanizedReady && romanized[index])
            return romanized[index];
        return sourceLines[index] || "";
    }

    function translationFor(index) {
        if (index < 0 || index >= translations.length)
            return "";
        return translations[index] || "";
    }

    function isCjk(lines) {
        return /[぀-ゟ゠-ヿ㐀-䶿一-鿿]/.test(lines.join("\n"));
    }

    function isLangCode(code) {
        return /^[a-z]{2,3}(-[a-z]{2,4})?$/i.test(code);
    }

    function translatable(code) {
        return isLangCode(code) && code !== targetLang && untranslatedLangs.indexOf(code) === -1;
    }

    function buildSample(lines) {
        const picked = [];
        let size = 0;

        for (const line of lines) {
            if (line === "")
                continue;
            picked.push(line);
            size += line.length + 1;
            if (size >= sampleBudget)
                break;
        }
        return picked.join("\n");
    }

    function buildChunks(lines) {
        const built = [];
        let current = [];
        let size = 0;

        for (let index = 0; index < lines.length; index++) {
            if (lines[index] === "")
                continue;

            const cost = lines[index].length + 1;
            if (current.length > 0 && size + cost > chunkBudget) {
                built.push(current);
                current = [];
                size = 0;
            }
            current.push(index);
            size += cost;
        }

        if (current.length > 0)
            built.push(current);
        return built;
    }

    function runNextChunk() {
        if (chunkAt >= chunks.length)
            return;

        const indices = chunks[chunkAt];
        const payload = indices.map(index => sourceLines[index]).join("\n");

        translateProc.request = {
            command: ["trans", "-e", "bing", "-no-ansi", "-b", "-s", language, "-t", targetLang, payload],
            context: {
                generation: generation,
                indices: indices
            }
        };
    }

    function beginTranslation() {
        draft = new Array(sourceLines.length).fill("");
        chunks = buildChunks(sourceLines);
        runNextChunk();
    }

    function refresh(force) {
        const key = sourceLines.join("\u0000");
        if (!force && key === processedKey && generation > 0)
            return;
        processedKey = key;

        generation++;
        romanizeProc.request = null;
        identifyProc.request = null;
        translateProc.request = null;

        language = "";
        romanized = [];
        translations = [];
        chunks = [];
        chunkAt = 0;
        draft = [];

        const lines = sourceLines;
        if (lines.length === 0)
            return;

        if (isCjk(lines)) {
            const filled = [];
            for (let index = 0; index < lines.length; index++) {
                if (lines[index] !== "")
                    filled.push(index);
            }

            romanizeProc.request = {
                command: ["vjshell-romanize", filled.map(index => lines[index]).join("\n")],
                context: {
                    generation: generation,
                    indices: filled
                }
            };
        }

        trackArtist = MusicLyricsService.fetchedArtist;
        trackTitle = MusicLyricsService.fetchedTitle;
        cacheKey = LyricsCacheService.keyFor(trackArtist, trackTitle);

        const cached = force ? null : LyricsCacheService.lookup(trackArtist, trackTitle);
        if (cached && cached.sourceLines === key && cached.language) {
            language = cached.language;
            cacheHit = true;

            if (!translatable(language))
                return;
            if (cached.translations && cached.translations.length === lines.length) {
                translations = cached.translations;
                return;
            }

            cacheHit = false;
            beginTranslation();
            return;
        }

        cacheHit = false;
        identifyProc.request = {
            command: ["trans", "-e", "bing", "-no-ansi", "-b", "-id", buildSample(lines)],
            context: {
                generation: generation
            }
        };
    }

    onSourceLinesChanged: refresh()

    Component.onCompleted: refresh()

    IpcHandler {
        target: "lyricsText"

        function status(): string {
            return JSON.stringify({
                lines: root.sourceLines.length,
                language: root.language,
                translatable: root.translatable(root.language),
                romanized: root.romanized.length,
                translations: root.translations.length,
                chunks: root.chunks.length,
                chunkAt: root.chunkAt,
                provider: MusicLyricsService.activeProvider,
                cacheKey: root.cacheKey,
                cacheHit: root.cacheHit
            });
        }

        function retry(): void {
            root.refresh(true);
        }
    }

    RequestProcess {
        id: romanizeProc
        onFinished: (code, output, context) => {
            if (code !== 0 || context.generation !== root.generation)
                return;
            const parts = output.split("\n");
            if (parts.length > 0 && parts[parts.length - 1] === "")
                parts.pop();
            if (parts.length !== context.indices.length)
                return;
            const merged = root.sourceLines.slice();
            for (let slot = 0; slot < parts.length; slot++)
                merged[context.indices[slot]] = parts[slot];
            root.romanized = merged;
        }
    }

    RequestProcess {
        id: identifyProc
        onFinished: (code, output, context) => {
            if (code !== 0 || context.generation !== root.generation)
                return;
            const detected = output.trim();
            if (!root.isLangCode(detected))
                return;

            root.language = detected;
            if (!root.translatable(detected)) {
                LyricsCacheService.store(root.trackArtist, root.trackTitle, {
                    sourceLines: root.processedKey,
                    language: detected,
                    translations: []
                });
                return;
            }
            root.beginTranslation();
        }
    }

    RequestProcess {
        id: translateProc
        onFinished: (code, output, context) => {
            if (code !== 0 || context.generation !== root.generation)
                return;
            const indices = context.indices;
            const parts = output.trim().split(/\\n|\n/).map(part => part.trim());
            if (parts.length !== indices.length)
                return;
            for (let slot = 0; slot < indices.length; slot++) {
                const target = indices[slot];
                const line = parts[slot];
                root.draft[target] = line === root.sourceLines[target] ? "" : line;
            }
            root.translations = root.draft.slice();
            root.chunkAt++;
            if (root.chunkAt >= root.chunks.length)
                LyricsCacheService.store(root.trackArtist, root.trackTitle, {
                    sourceLines: root.processedKey,
                    language: root.language,
                    translations: root.draft.slice()
                });
            root.runNextChunk();
        }
    }
}
