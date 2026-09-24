import QtQuick
import qs.Commons

ListRow {
    id: root

    property string value: ""
    property bool muted: false

    interactive: false
    dense: true
    trailingPadding: Style.panelPadding

    Label {
        text: root.value
        role: "bodyMedium"
        font.weight: Font.Medium
        horizontalAlignment: Text.AlignRight
        color: root.muted ? Theme.outline : Theme.inkSurface
    }
}
