import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

Panel {
    id: root

    panelName: "calendar"
    icon: Icons.calendar

    property date viewDate: new Date()
    readonly property date today: new Date()

    readonly property int todayY: today.getFullYear()
    readonly property int todayM: today.getMonth()
    readonly property int todayD: today.getDate()

    readonly property var weekDays: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
    readonly property var monthNamesUk: ["Січень", "Лютий", "Березень", "Квітень", "Травень", "Червень", "Липень", "Серпень", "Вересень", "Жовтень", "Листопад", "Грудень"]

    readonly property int visibleWeeks: 6
    readonly property int centerWeeks: 26
    readonly property int totalWeeks: 53

    // The Monday of the week containing the 1st of the current real month:
    // a fixed anchor the whole scrollable week range is measured from.
    readonly property date anchorMonday: {
        const d = new Date(today.getFullYear(), today.getMonth(), 1);
        const dow = (d.getDay() + 6) % 7;
        return new Date(d.getFullYear(), d.getMonth(), d.getDate() - dow);
    }

    function weekStart(weekIndex) {
        const d = new Date(root.anchorMonday);
        d.setDate(d.getDate() + weekIndex * 7);
        return d;
    }

    function weekCells(weekIndex) {
        const start = root.weekStart(weekIndex);
        const cells = [];
        for (let c = 0; c < 7; c++) {
            const day = new Date(start.getFullYear(), start.getMonth(), start.getDate() + c);
            cells.push({
                day: day.getDate(),
                inMonth: day.getMonth() === root.viewDate.getMonth() && day.getFullYear() === root.viewDate.getFullYear(),
                y: day.getFullYear(),
                m: day.getMonth()
            });
        }
        return cells;
    }

    function weekIndexFor(date) {
        const ms = date.getTime() - root.anchorMonday.getTime();
        return Math.round(ms / (7 * 24 * 60 * 60 * 1000));
    }

    function rowStep() {
        return list.iconBoxHeight + list.spacing;
    }

    function scrollToDate(date, animate) {
        const idx = root.weekIndexFor(date) + root.centerWeeks;
        const maxY = Math.max(0, list.contentHeight - list.height);
        const targetY = Math.max(0, Math.min(idx * root.rowStep(), maxY));
        if (animate === false) {
            list.contentY = targetY;
        } else {
            scrollAnim.to = targetY;
            scrollAnim.restart();
        }
    }

    function shiftMonth(delta) {
        root.scrollToDate(new Date(root.viewDate.getFullYear(), root.viewDate.getMonth() + delta, 1));
    }

    function goToday() {
        root.scrollToDate(new Date(root.todayY, root.todayM, 1));
    }

    function syncViewDateFromScroll() {
        const centerY = list.contentY + list.height / 2;
        const idx = Math.floor(centerY / root.rowStep()) - root.centerWeeks;
        const rep = root.weekStart(idx);
        rep.setDate(rep.getDate() + 3); // Thursday decides which month a boundary week belongs to
        const nd = new Date(rep.getFullYear(), rep.getMonth(), 1);
        if (nd.getTime() !== root.viewDate.getTime())
            root.viewDate = nd;
    }

    NumberAnimation {
        id: scrollAnim
        target: list
        property: "contentY"
        duration: Style.durResize
        easing.type: Easing.Bezier
        easing.bezierCurve: Style.standard
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing

        MaterialIcon {
            text: root.icon
            font.pixelSize: Style.fontSizeXl
            color: Theme.accent
        }

        Text {
            Layout.fillWidth: true
            text: Qt.formatDate(root.viewDate, "MMMM yyyy")
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeLarge
            font.weight: Font.Bold
            color: Theme.textBright
        }

        Text {
            text: root.monthNamesUk[root.viewDate.getMonth()]
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSize
            color: Theme.textDim
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

    ListView {
        id: list

        readonly property int iconBoxHeight: Style.iconBox

        Layout.fillWidth: true
        Layout.preferredHeight: root.visibleWeeks * iconBoxHeight + (root.visibleWeeks - 1) * spacing
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds
        snapMode: ListView.NoSnap

        model: root.totalWeeks

        onContentYChanged: root.syncViewDateFromScroll()

        Component.onCompleted: root.scrollToDate(root.viewDate, false)

        delegate: RowLayout {
            id: weekRow
            required property int index

            readonly property var cells: root.weekCells(index - root.centerWeeks)

            width: list.width
            spacing: 0

            Repeater {
                model: weekRow.cells

                delegate: DayCell {
                    required property var modelData

                    Layout.fillWidth: true
                    cell: modelData
                }
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
