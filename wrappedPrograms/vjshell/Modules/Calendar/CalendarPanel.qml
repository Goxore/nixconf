import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

Panel {
    id: root

    panelName: "calendar"
    title: Qt.formatDate(root.viewDate, "MMMM yyyy")
    icon: Icons.calendar

    property date viewDate: new Date()
    property date previousViewDate: viewDate
    property int transitionDir: 1
    readonly property date today: new Date()

    readonly property int todayY: today.getFullYear()
    readonly property int todayM: today.getMonth()
    readonly property int todayD: today.getDate()

    readonly property var weekDays: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    function cellAt(index) {
        const year = viewDate.getFullYear();
        const month = viewDate.getMonth();

        const firstIndex = (new Date(year, month, 1).getDay() + 6) % 7;
        const daysInMonth = new Date(year, month + 1, 0).getDate();
        const daysInPrevMonth = new Date(year, month, 0).getDate();

        const dayOffset = index - firstIndex + 1;

        if (dayOffset < 1)
            return {
                day: daysInPrevMonth + dayOffset,
                inMonth: false,
                y: month === 0 ? year - 1 : year,
                m: month === 0 ? 11 : month - 1
            };

        if (dayOffset > daysInMonth)
            return {
                day: dayOffset - daysInMonth,
                inMonth: false,
                y: month === 11 ? year + 1 : year,
                m: month === 11 ? 0 : month + 1
            };

        return {
            day: dayOffset,
            inMonth: true,
            y: year,
            m: month
        };
    }

    function shiftMonth(delta) {
        root.viewDate = new Date(root.viewDate.getFullYear(), root.viewDate.getMonth() + delta, 1);
    }

    function goToday() {
        root.viewDate = new Date(root.todayY, root.todayM, 1);
    }

    onViewDateChanged: {
        const dir = viewDate.getTime() > previousViewDate.getTime() ? 1 : viewDate.getTime() < previousViewDate.getTime() ? -1 : 0;
        previousViewDate = viewDate;
        if (dir !== 0) {
            transitionDir = dir;
            monthTransition.restart();
        }
    }

    SequentialAnimation {
        id: monthTransition

        ScriptAction {
            script: {
                gridShift.x = root.transitionDir * 24;
                grid.opacity = 0;
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: gridShift
                property: "x"
                to: 0
                duration: Style.durMedium1
                easing.type: Easing.Bezier
                easing.bezierCurve: Style.emphasizedDecelerate
            }
            NumberAnimation {
                target: grid
                property: "opacity"
                to: 1
                duration: Style.durMedium1
                easing.type: Easing.Bezier
                easing.bezierCurve: Style.standard
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing

        NavButton {
            icon: Icons.chevronLeft
            onClicked: root.shiftMonth(-1)
        }

        Item {
            Layout.fillWidth: true
        }

        PanelButton {
            icon: Icons.today
            text: "Today"
            onClicked: root.goToday()
        }

        Item {
            Layout.fillWidth: true
        }

        NavButton {
            icon: Icons.chevronRight
            onClicked: root.shiftMonth(1)
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 0

        Repeater {
            model: root.weekDays

            delegate: Text {
                required property string modelData
                required property int index

                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSizeSmall
                font.weight: Font.Bold
                color: index >= 5 ? Theme.textDim : Theme.text
            }
        }
    }

    GridLayout {
        id: grid

        Layout.fillWidth: true
        columns: 7
        rowSpacing: 2
        columnSpacing: 0

        transform: Translate {
            id: gridShift
        }

        Repeater {
            model: 42

            delegate: DayCell {
                required property int index

                Layout.fillWidth: true
                cell: root.cellAt(index)
            }
        }
    }

    component NavButton: Item {
        id: nav

        required property string icon
        signal clicked

        implicitWidth: Style.iconBox
        implicitHeight: Style.iconBox

        StateLayer {
            id: state
            cornerRadius: Style.radiusFull
            hovered: hover.hovered
            pressed: tap.pressed
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: nav.icon
            color: Theme.text

            scale: tap.pressed ? Style.pressScale : 1.0

            Behavior on scale {
                NumberAnimation {
                    duration: Style.durShort2
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Style.standard
                }
            }
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
            onTapped: nav.clicked()
        }
    }

    component DayCell: Item {
        id: dayCell

        required property var cell

        readonly property bool isToday: cell.inMonth && cell.y === root.todayY && cell.m === root.todayM && cell.day === root.todayD
        readonly property bool isWeekend: {
            const dow = new Date(cell.y, cell.m, cell.day).getDay();
            return dow === 0 || dow === 6;
        }

        implicitHeight: Style.iconBox

        StateLayer {
            id: state
            cornerRadius: Style.radiusFull
            hovered: hover.hovered
            pressed: tap.pressed
        }

        Rectangle {
            anchors.centerIn: parent
            width: Style.iconBox - 4
            height: width
            radius: width / 2
            color: dayCell.isToday ? Theme.accent : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: Style.durState
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Style.standard
                }
            }

            Text {
                anchors.centerIn: parent
                text: dayCell.cell.day
                font.family: Style.fontFamily
                font.pixelSize: Style.fontSizeSmall
                font.weight: dayCell.isToday ? Font.Bold : Font.Normal
                color: {
                    if (dayCell.isToday)
                        return Theme.surface;
                    if (!dayCell.cell.inMonth)
                        return Theme.outline;
                    return dayCell.isWeekend ? Theme.textDim : Theme.text;
                }
            }
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
            onTapped: {
                const iso = new Date(dayCell.cell.y, dayCell.cell.m, dayCell.cell.day, 12).toISOString().slice(0, 10);
                Quickshell.execDetached(["wl-copy", "--", iso]);
            }
        }
    }
}
