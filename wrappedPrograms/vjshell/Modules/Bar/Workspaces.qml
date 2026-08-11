import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services

ColumnLayout {
    id: root

    required property string screenName

    readonly property var tags: MangoService.tagsFor(screenName).filter(t => t && (t.active || t.clients > 0))

    Layout.fillWidth: true
    spacing: Style.spacing

    Repeater {
        model: root.tags

        delegate: Rectangle {
            id: indicator

            required property var modelData

            Layout.alignment: Qt.AlignHCenter

            implicitWidth: Style.dotSize
            implicitHeight: modelData.active ? Style.pillLength : Style.dotSize
            radius: width / 2

            color: modelData.urgent ? Theme.urgent : modelData.active ? Theme.active : Theme.occupied
            opacity: hover.hovered ? 0.75 : 1.0

            Behavior on implicitHeight {
                NumberAnimation {
                    duration: Style.animFast
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: Style.animFast
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: Style.animFast
                }
            }

            HoverHandler {
                id: hover
            }

            TapHandler {
                onTapped: MangoService.view(indicator.modelData.index, root.screenName)
            }
        }
    }
}
