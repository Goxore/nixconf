import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import qs.Commons
import qs.Services
import qs.Widgets

Item {
    id: root

    required property var notification

    property bool expired: false
    property real collapse: 1

    readonly property bool critical: notification?.urgency === NotificationUrgency.Critical
    readonly property var defaultAction: notification?.actions.find(action => action.identifier === "default") ?? null

    signal dismissed(bool expired)

    function requestDismiss(expired) {
        root.expired = expired;
        if (!exitAnim.running)
            exitAnim.start();
    }

    Layout.preferredHeight: (card.implicitHeight + Style.spacing) * collapse
    implicitHeight: Layout.preferredHeight
    clip: exitAnim.running

    Component.onCompleted: enterAnim.start()

    Timer {
        running: interval > 0 && !card.hovered
        interval: NotificationService.timeoutFor(root.notification)
        onTriggered: root.requestDismiss(true)
    }

    ParallelAnimation {
        id: enterAnim

        NumberMotion {
            target: card
            property: "opacity"
            from: 0
            to: 1
            duration: Style.durEnter
        }

        NumberMotion {
            target: slide
            property: "x"
            from: Style.notificationSlide
            to: 0
            duration: Style.durEnter
            easing.bezierCurve: Style.emphasizedDecelerate
        }
    }

    SequentialAnimation {
        id: exitAnim

        ParallelAnimation {
            NumberMotion {
                target: card
                property: "opacity"
                to: 0
                duration: Style.durExit
            }

            NumberMotion {
                target: slide
                property: "x"
                to: root.width * 0.4
                duration: Style.durExit
                easing.bezierCurve: Style.emphasizedAccelerate
            }

            NumberMotion {
                target: root
                property: "collapse"
                to: 0
                duration: Style.durExit
                easing.bezierCurve: Style.emphasized
            }
        }

        ScriptAction {
            script: root.dismissed(root.expired)
        }
    }

    Pressable {
        id: card

        width: parent.width
        implicitHeight: layout.implicitHeight + Style.panelPadding * 2
        height: implicitHeight

        description: root.notification?.summary ?? ""
        cornerRadius: Style.radiusXl

        transform: Translate {
            id: slide
        }

        onClicked: {
            root.defaultAction?.invoke();
            root.requestDismiss(false);
        }

        Surface {
            anchors.fill: parent
            z: -1
            level: 2
            radius: Style.radiusXl
            color: Theme.surfaceContainer
            borderColor: root.critical ? Theme.error : Theme.surfaceContainerHighest
        }

        ColumnLayout {
            id: layout

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Style.panelPadding
            spacing: Style.groupSpacing

            NotificationContent {
                Layout.fillWidth: true
                image: root.notification?.image ?? ""
                appIcon: root.notification?.appIcon ?? ""
                appName: root.notification?.appName ?? ""
                summary: root.notification?.summary ?? ""
                body: root.notification?.body ?? ""
                critical: root.critical

                IconButton {
                    icon: Icons.close
                    compact: true
                    description: "Dismiss"
                    opacity: card.hovered || activeFocus ? 1 : 0
                    onClicked: root.requestDismiss(false)

                    Behavior on opacity {
                        NumberMotion {}
                    }
                }
            }

            Flow {
                Layout.fillWidth: true
                Layout.leftMargin: Style.iconButtonSize + Style.groupSpacing
                visible: actions.count > 0
                spacing: Style.buttonGap

                Repeater {
                    id: actions

                    model: root.notification?.actions.filter(action => action.identifier !== "default") ?? []

                    delegate: Button {
                        required property var modelData

                        text: modelData.text || modelData.identifier
                        variant: "tonal"
                        compact: true
                        onClicked: {
                            modelData.invoke();
                            root.requestDismiss(false);
                        }
                    }
                }
            }
        }
    }
}
