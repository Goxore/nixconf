pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Services
import qs.Widgets

ListGroup {
    id: root

    Repeater {
        model: DeviceService.devices

        ListRow {
            required property var modelData

            Layout.fillWidth: true
            interactive: false
            icon: DeviceService.iconOf(modelData)
            headline: modelData.name
            supporting: DeviceService.summary(modelData)
            supportingLines: 2
            selected: modelData.online
        }
    }
}
