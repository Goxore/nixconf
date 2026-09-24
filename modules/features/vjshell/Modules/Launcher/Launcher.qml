import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services
import qs.Widgets

Overlay {
    id: root

    name: "launcher"
    topAligned: true
    surfaceWidth: Style.launcherWidth
    surfaceHeight: column.implicitHeight + Style.buttonGap * 2

    readonly property var specials: {
        const kinds = [];
        if (TranslateService.recognized)
            kinds.push("translate");
        if (CalcService.active)
            kinds.push("calc");
        return kinds;
    }

    property int specialIndex: -1
    property bool navigated: false

    readonly property string selectedSpecial: specialIndex >= 0 && specialIndex < specials.length ? specials[specialIndex] : ""

    function selectSpecial(kind) {
        specialIndex = specials.indexOf(kind);
    }

    function moveDown() {
        navigated = true;
        if (specialIndex < 0)
            list.incrementCurrentIndex();
        else if (specialIndex < specials.length - 1)
            specialIndex++;
        else if (list.count > 0) {
            specialIndex = -1;
            list.currentIndex = 0;
        }
    }

    function moveUp() {
        navigated = true;
        if (specialIndex > 0)
            specialIndex--;
        else if (specialIndex === 0)
            return;
        else if (list.currentIndex === 0 && specials.length > 0)
            specialIndex = specials.length - 1;
        else
            list.decrementCurrentIndex();
    }

    function activateSelected() {
        if (selectedSpecial !== "") {
            const value = selectedSpecial === "translate" ? TranslateService.result : CalcService.result;
            if (value === "")
                return;
            Quickshell.execDetached(["wl-copy", "--", value]);
            close();
            return;
        }

        const entry = LauncherService.results[list.currentIndex];
        if (entry) {
            LauncherService.launch(entry);
            close();
        }
    }

    function search(text) {
        navigated = false;
        LauncherService.query = text;
        TranslateService.update(text);
        CalcService.update(TranslateService.recognized ? "" : text);
        list.currentIndex = 0;
    }

    onOpenedChanged: {
        if (!opened)
            return;
        LauncherService.query = "";
        CalcService.clear();
        TranslateService.clear();
        list.currentIndex = 0;
        specialIndex = -1;
        field.clear();
        field.take();
    }

    onSpecialsChanged: {
        if (!navigated)
            specialIndex = specials.length > 0 ? 0 : -1;
        else if (specialIndex >= specials.length)
            specialIndex = -1;
    }

    ColumnLayout {
        id: column

        anchors.fill: parent
        anchors.margins: Style.buttonGap
        spacing: Style.buttonGap

        TextField {
            id: field

            icon: Icons.search
            placeholder: "Search apps"
            onEdited: value => root.search(value)
            onAccepted: root.activateSelected()
            onMoved: step => step > 0 ? root.moveDown() : root.moveUp()
            onEscaped: root.close()
        }

        ResultRow {
            Layout.fillWidth: true
            visible: TranslateService.recognized
            selected: root.selectedSpecial === "translate"
            icon: Icons.translate
            loading: TranslateService.loading
            ready: TranslateService.result !== ""
            headline: TranslateService.result || TranslateService.pending
            supporting: TranslateService.loading ? "Translating " + TranslateService.pair : TranslateService.pair + " · " + TranslateService.translated
            onClicked: {
                root.selectSpecial("translate");
                root.activateSelected();
            }
        }

        ResultRow {
            Layout.fillWidth: true
            visible: CalcService.active
            selected: root.selectedSpecial === "calc"
            icon: Icons.calculate
            headline: CalcService.result
            supporting: CalcService.evaluated
            onClicked: {
                root.selectSpecial("calc");
                root.activateSelected();
            }
        }

        Divider {
            visible: root.specials.length > 0 && list.count > 0
            Layout.leftMargin: Style.panelPadding
            Layout.rightMargin: Style.panelPadding
        }

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, Style.listMax)
            visible: count > 0
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            spacing: Style.listGap
            model: LauncherService.results
            currentIndex: 0
            keyNavigationEnabled: false
            highlightMoveDuration: Style.durShort4
            Controls.ScrollBar.vertical: ListScrollBar {}

            delegate: AppRow {
                required property var modelData
                required property int index

                width: ListView.view.width
                entry: modelData
                selected: root.specialIndex < 0 && index === list.currentIndex
                onClicked: {
                    list.currentIndex = index;
                    root.specialIndex = -1;
                    root.activateSelected();
                }
            }
        }

        EmptyState {
            visible: list.count === 0 && root.specials.length === 0
            icon: Icons.emptySearch
            title: "No matches"
            supporting: "Type a sum like 2+2, or ENUK hello to translate"
        }
    }
}
