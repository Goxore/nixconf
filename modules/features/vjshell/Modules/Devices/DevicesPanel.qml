import QtQuick
import QtQuick.Layouts
import qs.Services
import qs.Widgets

Panel {
    name: "devices"
    title: DeviceService.text("devices")

    DeviceList {
        Layout.fillWidth: true
    }
}
