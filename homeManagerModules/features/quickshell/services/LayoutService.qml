// CREDIT: https://github.com/end-4/dots-hyprland/commit/ad7fdd1d3fcda4dfccef2a0f5afdfd09c705f840
pragma Singleton
import QtQuick
import Quickshell.Hyprland

QtObject {
    id: layoutService

    property string currentLayout: ":D"

    function parseLayout(fullLayoutName) {
        if (!fullLayoutName)
            return;

        const shortName = fullLayoutName.substring(0, 2).toLowerCase();

        if (currentLayout !== shortName) {
            currentLayout = shortName;
        }
    }

    function handleRawEvent(event) {
        if (event.name !== "activelayout")
            return;

        const dataString = event.data;
        const layoutInfo = dataString.split(",");
        const fullLayoutName = layoutInfo[layoutInfo.length - 1];

        parseLayout(fullLayoutName);
    }

    Component.onCompleted: {
        Hyprland.rawEvent.connect(handleRawEvent);
    }
}
