pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

Panel {
    id: root

    readonly property var weekDays: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
    readonly property var monthNamesUk: ["Січень", "Лютий", "Березень", "Квітень", "Травень", "Червень", "Липень", "Серпень", "Вересень", "Жовтень", "Листопад", "Грудень"]
    readonly property int visibleWeeks: 6
    readonly property int centerWeeks: 26
    readonly property int totalWeeks: 53
    readonly property real weekMs: 7 * 24 * 60 * 60 * 1000

    readonly property date today: clock.date
    property date base: new Date()
    property date viewDate: new Date()
    property string copied: ""

    readonly property date anchorMonday: mondayOf(new Date(base.getFullYear(), base.getMonth(), 1))
    readonly property real rowStep: Style.dayCell + list.spacing

    function mondayOf(date) {
        return new Date(date.getFullYear(), date.getMonth(), date.getDate() - (date.getDay() + 6) % 7);
    }

    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    function weekCells(week) {
        return Array.from({
            length: 7
        }, (_, column) => new Date(anchorMonday.getFullYear(), anchorMonday.getMonth(), anchorMonday.getDate() + week * 7 + column));
    }

    function weekIndexFor(date) {
        return Math.round((mondayOf(date).getTime() - anchorMonday.getTime()) / weekMs);
    }

    function scrollToDate(date, animate) {
        scroller.stop();
        const target = Math.max(0, Math.min((weekIndexFor(date) + centerWeeks) * rowStep, list.contentHeight - list.height));
        if (animate === false) {
            list.contentY = target;
            return;
        }
        scroller.to = target;
        scroller.restart();
    }

    function shiftMonth(delta) {
        scrollToDate(new Date(viewDate.getFullYear(), viewDate.getMonth() + delta, 1));
    }

    function goToday(animate) {
        scrollToDate(new Date(today.getFullYear(), today.getMonth(), 1), animate);
    }

    function syncViewDate() {
        const week = Math.floor((list.contentY + list.height / 2) / rowStep) - centerWeeks;
        const middle = weekCells(week)[3];
        const month = new Date(middle.getFullYear(), middle.getMonth(), 1);
        if (month.getTime() !== viewDate.getTime())
            viewDate = month;
    }

    function copy(date) {
        copied = Qt.formatDate(date, "yyyy-MM-dd");
        Quickshell.execDetached(["wl-copy", "--", copied]);
    }

    name: "calendar"
    title: Qt.formatDate(viewDate, "MMMM yyyy")
    subtitle: monthNamesUk[viewDate.getMonth()]

    onOpenedChanged: if (opened) {
        base = new Date();
        copied = "";
        Qt.callLater(() => root.goToday(false));
    }

    actions: [
        IconButton {
            icon: Icons.chevronLeft
            description: "Previous month"
            onClicked: root.shiftMonth(-1)
        },
        IconButton {
            icon: Icons.today
            description: "Today"
            onClicked: root.goToday()
        },
        IconButton {
            icon: Icons.chevronRight
            description: "Next month"
            onClicked: root.shiftMonth(1)
        }
    ]

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    NumberMotion {
        id: scroller
        target: list
        property: "contentY"
        duration: Style.durMedium2
        easing.bezierCurve: Style.emphasizedDecelerate
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.spacing

        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Repeater {
                model: root.weekDays

                delegate: Label {
                    required property string modelData
                    required property int index

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    role: "labelMedium"
                    color: index >= 5 ? Theme.outline : Theme.inkSurfaceVariant
                }
            }
        }

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.preferredHeight: root.visibleWeeks * Style.dayCell + (root.visibleWeeks - 1) * spacing
            clip: true
            spacing: Style.listGap
            boundsBehavior: Flickable.StopAtBounds
            model: root.totalWeeks

            onContentYChanged: root.syncViewDate()
            Component.onCompleted: root.goToday(false)

            delegate: RowLayout {
                id: week

                required property int index

                width: ListView.view.width
                spacing: 0

                Repeater {
                    model: root.weekCells(week.index - root.centerWeeks)

                    delegate: Item {
                        id: cell

                        required property date modelData

                        readonly property bool inMonth: modelData.getMonth() === root.viewDate.getMonth() && modelData.getFullYear() === root.viewDate.getFullYear()
                        readonly property bool isToday: root.sameDay(modelData, root.today)
                        readonly property bool weekend: modelData.getDay() === 0 || modelData.getDay() === 6
                        readonly property bool justCopied: root.copied === Qt.formatDate(modelData, "yyyy-MM-dd")

                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: Style.dayCell

                        Pressable {
                            anchors.centerIn: parent
                            width: Style.dayCell
                            height: Style.dayCell

                            description: Qt.formatDate(cell.modelData, "dddd d MMMM yyyy")
                            selected: cell.justCopied
                            cornerRadius: width / 2
                            layerColor: cell.justCopied ? Theme.inkPrimary : Theme.inkSurface

                            onClicked: root.copy(cell.modelData)

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: cell.justCopied ? Theme.primary : "transparent"
                                border.width: cell.isToday && !cell.justCopied ? Style.borderWidth : 0
                                border.color: Theme.primary

                                Behavior on color {
                                    ColorMotion {}
                                }
                            }

                            Label {
                                anchors.centerIn: parent
                                text: cell.modelData.getDate()
                                role: "bodyMedium"
                                font.weight: cell.isToday ? Font.Bold : Font.Normal
                                color: {
                                    if (cell.justCopied)
                                        return Theme.inkPrimary;
                                    if (cell.isToday)
                                        return Theme.primary;
                                    if (!cell.inMonth)
                                        return Theme.outlineVariant;
                                    return cell.weekend ? Theme.inkSurfaceVariant : Theme.inkSurface;
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Label {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: root.copied !== "" ? "Copied " + root.copied : "Click a day to copy its date"
        role: "bodySmall"
        color: root.copied !== "" ? Theme.primary : Theme.outline
    }
}
