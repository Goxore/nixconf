pragma Singleton

import Quickshell

Singleton {
    readonly property string home: Quickshell.env("HOME")
    readonly property string stateHome: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/quickshell"
    readonly property string cacheHome: (Quickshell.env("XDG_CACHE_HOME") || home + "/.cache") + "/vjshell"
    readonly property string runtimeHome: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/vjshell"

    function state(name) {
        return stateHome + "/" + name;
    }

    function cache(name) {
        return cacheHome + "/" + name;
    }

    function runtime(name) {
        return runtimeHome + "/" + name;
    }
}
