import QtQuick
import Quickshell
import qs.Services

ShellRoot {
    id: root

    property int stage: 0

    function near(actual, expected, label) {
        if (Math.abs(actual - expected) > 0.02)
            throw new Error(label + ": " + actual + " is not " + expected);
    }

    function same(actual, expected, label) {
        if (actual !== expected)
            throw new Error(label + ": " + actual + " is not " + expected);
    }

    function runs(texts) {
        return texts.map(text => ({
                    text: text
                }));
    }

    function column(texts) {
        return {
            musicResponsiveListItemFlexColumnRenderer: {
                text: {
                    runs: runs(texts)
                }
            }
        };
    }

    function row(videoId, title, subtitle) {
        return {
            musicResponsiveListItemRenderer: {
                overlay: {
                    musicItemThumbnailOverlayRenderer: {
                        content: {
                            musicPlayButtonRenderer: {
                                playNavigationEndpoint: {
                                    watchEndpoint: {
                                        videoId: videoId
                                    }
                                }
                            }
                        }
                    }
                },
                flexColumns: [column([title]), column(subtitle)]
            }
        };
    }

    readonly property var cardShelf: ({
            musicCardShelfRenderer: {
                onTap: {
                    browseEndpoint: {
                        browseId: "UCartist"
                    }
                },
                title: {
                    runs: runs(["Somebody"])
                },
                contents: [row("card1", "Card One", ["Song", " • ", "Somebody", " • ", "3:58", "500M plays"])]
            }
        })

    readonly property var itemSection: ({
            itemSectionRenderer: {
                contents: [row("sect1", "Section One", ["Song", " • ", "3:55", "54M plays"])]
            }
        })

    readonly property var searchFixture: ({
            contents: {
                tabbedSearchResultsRenderer: {
                    tabs: [
                        {
                            tabRenderer: {
                                content: {
                                    sectionListRenderer: {
                                        contents: [root.cardShelf, root.itemSection]
                                    }
                                }
                            }
                        }
                    ]
                }
            }
        })

    function checkParsing() {
        const parsed = MusicService.parseSearch(searchFixture);

        same(parsed.length, 2, "recursive walk should find rows in both card and item sections");

        const card = parsed.find(row => row.videoId === "card1");
        same(card.title, "Card One", "card shelf title");
        same(card.artist, "Somebody", "artist must skip the leading type token");
        same(card.duration, "3:58", "duration");
        same(card.kind, "Song", "kind");

        const section = parsed.find(row => row.videoId === "sect1");
        same(section.title, "Section One", "item section title");
        same(section.artist, "", "artist stays empty when only a play count follows the type");
        same(section.duration, "3:55", "duration survives a missing artist");
    }

    function checkFrecency() {
        const now = Date.now();
        const halfLife = MusicHistoryService.halfLifeMs;

        near(MusicHistoryService.decayed({
            score: 4,
            lastPlayed: now
        }, now), 4, "a fresh entry keeps its score");

        near(MusicHistoryService.decayed({
            score: 4,
            lastPlayed: now - halfLife
        }, now), 2, "one half life halves the score");

        near(MusicHistoryService.decayed({
            score: 4,
            lastPlayed: now - halfLife * 2
        }, now), 1, "two half lives quarter the score");
    }

    function checkRanking() {
        const results = [
            {
                videoId: "a",
                title: "Unknown One",
                artist: "Nobody",
                album: "",
                duration: "",
                art: ""
            },
            {
                videoId: "b",
                title: "Unknown Two",
                artist: "Nobody",
                album: "",
                duration: "",
                art: ""
            },
            {
                videoId: "known",
                title: "Known One",
                artist: "Somebody",
                album: "",
                duration: "",
                art: ""
            }
        ];

        same(MusicService.rank(results.slice(0, 2)).map(row => row.videoId).join(","), "a,b", "unknown results keep relevance order");

        same(MusicService.rank(results)[0].videoId, "known", "a played track is lifted above fresher results");
    }

    function checkPlayTop() {
        MusicService.results = [];
        MusicService.playTop();
        same(MusicService.playWhenReady, true, "an empty result set arms a pending play");

        MusicService.results = [
            {
                videoId: "",
                title: "History Row",
                artist: "",
                album: "",
                duration: "",
                art: ""
            },
            {
                videoId: "playable",
                title: "Playable",
                artist: "",
                album: "",
                duration: "",
                art: ""
            }
        ];
        same(MusicService.playWhenReady, false, "arriving results consume the pending play");

        MusicService.query = "anything";
        same(MusicService.playWhenReady, false, "editing the query cancels a pending play");
        MusicService.query = "";
    }

    function checkQueueLanding() {
        MusicService.awaitedVideoId = "wanted";

        same(MusicService.findAwaited([
            {
                videoId: "now",
                current: true
            },
            {
                videoId: "other",
                current: false
            }
        ]), -1, "an insert that has not landed yet must not steal a jump");

        same(MusicService.findAwaited([
            {
                videoId: "now",
                current: true
            },
            {
                videoId: "wanted",
                current: false
            },
            {
                videoId: "other",
                current: false
            }
        ]), 1, "the landed insert sits right after the current track");

        same(MusicService.findAwaited([
            {
                videoId: "wanted",
                current: true
            }
        ]), 0, "an insert that is already playing needs no jump");

        MusicService.awaitedVideoId = "";
    }

    Timer {
        interval: 250
        repeat: true
        running: true

        onTriggered: {
            if (!MusicHistoryService.loaded)
                return;

            if (root.stage === 0) {
                MusicHistoryService.record("Somebody", "Known One", "known", "cover");
                MusicHistoryService.record("Somebody", "Known One", "known", "cover");
                MusicHistoryService.record("Someone Else", "Known Two", "", "");
                root.stage++;
                return;
            }

            root.near(MusicHistoryService.frecency("Somebody", "Known One", ""), 2, "two plays");
            root.near(MusicHistoryService.frecency("", "", "known"), 2, "lookup by video id");
            root.near(MusicHistoryService.frecency("Nobody", "Never Played", ""), 0, "unplayed track");

            const top = MusicHistoryService.top(5);
            root.same(top[0].title, "Known One", "history orders by frecency");
            root.same(top[0].art, "cover", "history keeps artwork");
            root.same(top.length, 2, "history holds both tracks");

            root.checkFrecency();
            root.checkParsing();
            root.checkRanking();
            root.checkPlayTop();
            root.checkQueueLanding();

            console.log("PASS music search parsing, frecency decay, history ordering, result ranking and queue landing");
            Qt.quit();
        }
    }
}
