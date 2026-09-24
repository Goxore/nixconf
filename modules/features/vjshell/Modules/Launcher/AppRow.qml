import QtQuick
import Quickshell
import qs.Commons
import qs.Widgets

ListRow {
    required property var entry

    icon: Icons.application
    iconSource: Quickshell.iconPath(entry.icon, true)
    headline: entry.name
    supporting: entry.genericName || entry.comment || ""
    filled: false
}
