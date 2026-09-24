import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Panel {
    name: "vr"
    panelWidth: Style.panelWidthL
    fillHeight: true

    pinned: VrSummary {}

    VrPages {}
}
