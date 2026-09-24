import QtQuick.Layouts
import qs.Commons
import qs.Services
import qs.Widgets

Panel {
    id: root

    name: "music"
    title: MusicService.text("music")
    panelWidth: Style.musicWidth
    maxPanelHeight: Style.musicHeight
    centered: true
    scrollable: false

    onOpenedChanged: {
        if (opened)
            content.focusSearch();
    }

    MusicContent {
        id: content
        Layout.fillWidth: true
        Layout.fillHeight: true
        onDismissed: root.close()
    }
}
