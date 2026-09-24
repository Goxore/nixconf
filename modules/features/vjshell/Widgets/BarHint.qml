import QtQuick
import Quickshell
import qs.Commons
import qs.Services

Timer {
    id: root

    required property Item target
    property string text: ""
    property bool hovered: false

    function reveal() {
        const pos = target.mapToItem(null, 0, 0);
        TooltipService.show(text, pos.y + target.height / 2, target.QsWindow.window?.screen?.name ?? "");
    }

    interval: Style.tooltipDelay

    onTriggered: reveal()
    onHoveredChanged: {
        if (hovered && text !== "") {
            restart();
            return;
        }
        stop();
        TooltipService.hide();
    }
    onTextChanged: if (hovered && TooltipService.shown)
        TooltipService.text = text
}
