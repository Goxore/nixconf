import QtQuick
import QtQuick.Layouts
import qs.Commons

ColumnLayout {
    id: root

    function arrange() {
        const rows = Array.from(visibleChildren).filter(child => child.first !== undefined && child.last !== undefined);
        rows.forEach((row, index) => {
            row.first = index === 0;
            row.last = index === rows.length - 1;
        });
    }

    Layout.fillWidth: true
    spacing: Style.listGap

    onVisibleChildrenChanged: Qt.callLater(arrange)
    Component.onCompleted: arrange()
}
