pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services
import qs.Widgets

Overlay {
    id: root

    property int project: ProjectService.active
    property string query: ""

    readonly property string typed: query.trim()
    readonly property bool coining: typed !== ""
    readonly property var matches: {
        const needle = typed.toLowerCase();
        if (needle === "")
            return ProjectService.shelf;
        return ProjectService.shelf.filter(profile => profile.name.toLowerCase().includes(needle) || profile.dir.toLowerCase().includes(needle));
    }

    function aimedAt() {
        if (PanelService.subject === PanelService.fresh)
            return ProjectService.firstFree();
        if (PanelService.subject === PanelService.here)
            return ProjectService.active;
        return PanelService.subject;
    }

    function take(profile) {
        ProjectService.assign(project, profile.id);
        ProjectService.switchTo(project);
        close();
    }

    function coin() {
        ProjectService.describe(project, typed, "");
        ProjectService.switchTo(project);
        close();
    }

    function activate() {
        if (list.currentIndex >= 0 && list.currentIndex < matches.length)
            take(matches[list.currentIndex]);
        else if (coining)
            coin();
    }

    function move(step) {
        if (step > 0) {
            if (list.currentIndex < matches.length - 1)
                list.currentIndex++;
            else if (coining)
                list.currentIndex = -1;
        } else if (list.currentIndex > 0) {
            list.currentIndex--;
        } else if (list.currentIndex === -1) {
            list.currentIndex = matches.length - 1;
        }
    }

    name: "projectPicker"
    topAligned: true
    surfaceWidth: Style.launcherWidth
    surfaceHeight: column.implicitHeight + Style.buttonGap * 2

    onOpenedChanged: if (opened) {
        project = aimedAt();
        field.clear();
        list.currentIndex = 0;
        field.take();
    }

    Connections {
        target: ProjectService

        function onActiveChanged() {
            settle.restart();
        }
    }

    Timer {
        id: settle
        interval: Style.durMedium2
        onTriggered: if (PanelService.activePanel === "" && ProjectService.blank(ProjectService.active))
            PanelService.pick(ProjectService.active)
    }

    ColumnLayout {
        id: column

        anchors.fill: parent
        anchors.margins: Style.buttonGap
        spacing: Style.buttonGap

        TextField {
            id: field

            icon: Icons.projects
            placeholder: "Open or name a project"
            onEdited: value => {
                root.query = value;
                list.currentIndex = root.matches.length > 0 ? 0 : -1;
            }
            onAccepted: root.activate()
            onMoved: step => root.move(step)
            onEscaped: root.close()
        }

        ListRow {
            Layout.fillWidth: true
            visible: root.coining
            filled: false
            icon: Icons.add
            headline: "Create “" + root.typed + "”"
            supporting: "Start a new project with this name"
            selected: list.currentIndex === -1
            onClicked: root.coin()
        }

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, Style.listMax)
            visible: count > 0
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            spacing: Style.listGap
            model: root.matches
            currentIndex: 0
            keyNavigationEnabled: false
            Controls.ScrollBar.vertical: ListScrollBar {}

            delegate: ListRow {
                id: row

                required property var modelData
                required property int index

                width: ListView.view.width
                filled: false
                icon: modelData.icon || Icons.project
                headline: modelData.name
                supporting: ProjectService.tilde(modelData.dir)
                supportingElide: Text.ElideMiddle
                selected: index === list.currentIndex
                onClicked: root.take(modelData)

                IconButton {
                    icon: Icons.remove
                    compact: true
                    description: "Forget " + row.modelData.name
                    opacity: row.hovered || row.selected || activeFocus ? 1 : 0
                    onClicked: ProjectService.forget(row.modelData.id)

                    Behavior on opacity {
                        NumberMotion {}
                    }
                }
            }
        }

        EmptyState {
            visible: list.count === 0 && !root.coining
            icon: Icons.projects
            title: "No projects yet"
            supporting: "Type a name to start one"
        }
    }
}
