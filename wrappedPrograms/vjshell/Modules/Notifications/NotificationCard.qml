import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.Commons
import qs.Services
import qs.Widgets

Surface {
    id: root

    required property var notification

    signal dismissed

    readonly property bool critical: notification?.urgency === NotificationUrgency.Critical

    Layout.preferredHeight: layout.implicitHeight + Style.panelPadding * 2

    level: 2
    radius: Style.radiusM
    borderColor: critical ? Theme.urgent : Theme.surfaceHigh

    function requestDismiss() {
        if (!exitAnim.running)
            exitAnim.start();
    }

    Component.onCompleted: enterAnim.start()

    ParallelAnimation {
        id: enterAnim

        NumberAnimation {
            target: root
            property: "opacity"
            from: 0
            to: 1
            duration: Style.durEnter
            easing.type: Easing.Bezier
            easing.bezierCurve: Style.standard
        }
        NumberAnimation {
            target: root
            property: "x"
            from: 40
            to: 0
            duration: Style.durEnter
            easing.type: Easing.Bezier
            easing.bezierCurve: Style.emphasizedDecelerate
        }
    }

    SequentialAnimation {
        id: exitAnim

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "opacity"
                to: 0
                duration: Style.durExit
                easing.type: Easing.Bezier
                easing.bezierCurve: Style.standard
            }
            NumberAnimation {
                target: root
                property: "x"
                to: root.width * 0.4
                duration: Style.durExit
                easing.type: Easing.Bezier
                easing.bezierCurve: Style.emphasizedAccelerate
            }
            NumberAnimation {
                target: root
                property: "Layout.preferredHeight"
                to: 0
                duration: Style.durExit
                easing.type: Easing.Bezier
                easing.bezierCurve: Style.emphasized
            }
        }

        ScriptAction {
            script: root.dismissed()
        }
    }

    Timer {
        running: interval > 0 && !hover.hovered
        interval: NotificationService.timeoutFor(root.notification?.urgency)
        onTriggered: root.requestDismiss()
    }

    StateLayer {
        id: state
        cornerRadius: root.radius
        hovered: hover.hovered
        pressed: tap.pressed
    }

    HoverHandler {
        id: hover
    }

    TapHandler {
        id: tap
        onPressedChanged: {
            if (pressed)
                state.press(point.position.x, point.position.y);
            else
                state.release();
        }
        onTapped: root.requestDismiss()
    }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: Style.panelPadding
        spacing: Style.spacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.panelPadding

            Item {
                implicitWidth: Style.iconBox
                implicitHeight: Style.iconBox
                visible: image.visible || fallback.visible

                IconImage {
                    id: image
                    anchors.fill: parent
                    source: root.notification?.image || Quickshell.iconPath(root.notification?.appIcon ?? "", true)
                    visible: status === Image.Ready
                }

                MaterialIcon {
                    id: fallback
                    anchors.centerIn: parent
                    visible: !image.visible
                    text: Icons.bell
                    font.pixelSize: Style.iconSizeXl
                    color: root.critical ? Theme.urgent : Theme.textDim
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                        text: root.notification?.summary ?? ""
                        elide: Text.ElideRight
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontSize
                        font.weight: Font.Bold
                        color: root.critical ? Theme.urgent : Theme.textBright
                    }

                    Text {
                        text: root.notification?.appName ?? ""
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontSizeSmall
                        color: Theme.textDim
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.notification?.body ?? ""
                    wrapMode: Text.WordWrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                    textFormat: Text.StyledText
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSizeSmall
                    color: Theme.text
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            visible: repeater.count > 0
            spacing: Style.spacing

            Repeater {
                id: repeater
                model: root.notification?.actions ?? []

                delegate: PanelButton {
                    required property var modelData
                    text: modelData.text || modelData.identifier
                    onClicked: {
                        modelData.invoke();
                        root.requestDismiss();
                    }
                }
            }
        }
    }
}
