import QtQuick
import Quickshell.Io

QtObject {
    id: root

    required property string source
    property var words: ({})

    function text(key, values) {
        let value = words[key] || "";
        for (const name in values || {})
            value = value.split("{" + name + "}").join(String(values[name]));
        return value;
    }

    property FileView file: FileView {
        path: root.source
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.words = JSON.parse(text());
            } catch (error) {
                root.words = {};
            }
        }
    }
}
