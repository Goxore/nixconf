import QtQuick
import Quickshell
import qs.Services

ShellRoot {
    id: root

    property int stage: 0

    function check(value, message) {
        if (!value)
            throw new Error(message);
    }

    Component.onCompleted: {
        check(NotificationService.timeoutFor({
            expireTimeout: 0
        }) === 0, "persistent notification expired");
        check(NotificationService.timeoutFor({
            expireTimeout: 1250
        }) === 1250, "notification timeout units");
        check(MusicLyricsService.buildUrl("A B", "C & D") === "https://lrclib.net/api/get?artist_name=A%20B&track_name=C%20%26%20D", "lyrics query encoding");
        check(MusicLyricsService.timeToSeconds("01:23,50") === 83.5, "lyric timing");
        check(LyricsTextService.translatable("cs"), "lyrics left untranslated");
        check(!LyricsTextService.translatable("uk") && !LyricsTextService.translatable("ru"), "lyrics translated away from Cyrillic");
        check(!LyricsTextService.translatable("en") && !LyricsTextService.translatable(""), "lyrics translated into their own language");
        check(LyricsTextService.isCjk(["夜が明ける前に"]) && !LyricsTextService.isCjk(["Jožin z bažin"]), "lyrics romanization scope");
        SystemService.cpuPrev = null;
        SystemService.parseStat("cpu 100 0 0 100 0 0 0 0 80 0\ncpu0 0");
        SystemService.parseStat("cpu 150 0 0 150 0 0 0 0 120 0\ncpu0 0");
        check(SystemService.cpuUsage === 0.5, "guest CPU time counted twice");
        check(TranslateService.parse("ENUK hello").targetLang === "uk", "translation language parsing");
        CalcService.update("= 1 - 1");
    }

    Timer {
        interval: 20
        running: true
        repeat: true
        onTriggered: {
            if (root.stage === 0 && CalcService.active) {
                root.check(CalcService.result === "0", "zero calculation hidden");
                CalcService.clear();
                root.check(!CalcService.active, "calculator did not clear");
                TranslateService.update("ENUK old");
                root.stage = 1;
                replace.start();
            } else if (root.stage === 2 && !TranslateService.loading) {
                root.check(TranslateService.result === "fresh" && TranslateService.translated === "fresh", "translation used an old request");
                TranslateService.clear();
                root.check(!TranslateService.recognized && TranslateService.result === "", "translation did not clear");
                console.log("PASS calculator, translation, notification, lyrics and CPU regressions");
                Qt.quit();
            }
        }
    }

    Timer {
        id: replace
        interval: 450
        onTriggered: {
            TranslateService.update("ENUK fresh");
            root.check(TranslateService.result === "" && TranslateService.loading, "previous translation remained copyable");
            root.stage = 2;
        }
    }
}
