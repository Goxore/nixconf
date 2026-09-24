import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ListRow {
    id: root

    property bool loading: false
    property bool ready: true

    filled: false

    Spinner {
        visible: root.loading
        implicitWidth: Style.iconSizeXl
        implicitHeight: Style.iconSizeXl
    }

    MaterialIcon {
        Layout.rightMargin: Style.buttonGap
        visible: !root.loading && root.ready
        text: Icons.copy
        color: root.selected ? Theme.inkSecondaryContainer : Theme.inkSurfaceVariant
    }
}
