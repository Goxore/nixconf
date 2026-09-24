pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services
import qs.Widgets

Overlay {
    id: root

    readonly property int project: PanelService.subject === PanelService.here ? ProjectService.active : PanelService.subject

    property string chosenIcon: ""
    property string nameText: ""
    property string folderText: ""

    function save() {
        ProjectService.describe(project, nameText.trim(), chosenIcon, ProjectService.expand(folderText.trim()));
        close();
    }

    name: "projectEditor"
    topAligned: true
    surfaceWidth: Style.panelWidthL
    surfaceHeight: column.implicitHeight + Style.panelPadding * 2

    onOpenedChanged: if (opened) {
        const place = ProjectService.placeOf(project);
        nameText = ProjectService.named(project);
        folderText = ProjectService.tilde(place ? place.dir : "");
        chosenIcon = ProjectService.iconOf(project);
        nameField.take();
        nameField.selectAll();
    }

    ColumnLayout {
        id: column

        anchors.fill: parent
        anchors.margins: Style.panelPadding
        spacing: Style.panelPadding

        Label {
            Layout.fillWidth: true
            Layout.leftMargin: Style.spacing
            text: "Edit project"
            role: "headlineSmall"
        }

        TextField {
            id: nameField

            variant: "field"
            label: "Name"
            icon: root.chosenIcon
            placeholder: "Project name"
            text: root.nameText
            onEdited: value => root.nameText = value
            onAccepted: root.save()
            onEscaped: root.close()
        }

        TextField {
            variant: "field"
            label: "Folder"
            icon: Icons.folder
            placeholder: "~/Projects/name"
            text: root.folderText
            onEdited: value => root.folderText = value
            onAccepted: root.save()
            onEscaped: root.close()
        }

        Label {
            Layout.leftMargin: Style.spacing
            text: "Icon"
            role: "labelMedium"
            color: Theme.inkSurfaceVariant
        }

        GridLayout {
            Layout.fillWidth: true
            columns: Math.max(1, Math.floor((width + Style.spacing) / (Style.iconGridCell + Style.spacing)))
            columnSpacing: Style.spacing
            rowSpacing: Style.spacing

            Repeater {
                model: Icons.palette

                delegate: Pressable {
                    id: cell

                    required property var modelData

                    readonly property bool chosen: root.chosenIcon === modelData.icon

                    Layout.fillWidth: true
                    implicitHeight: Style.iconGridCell

                    description: modelData.name
                    selected: chosen
                    Accessible.role: Accessible.RadioButton
                    cornerRadius: chosen ? Style.radiusXl : Style.radiusM
                    layerColor: chosen ? Theme.inkSecondaryContainer : Theme.inkSurface

                    onClicked: root.chosenIcon = modelData.icon

                    Rectangle {
                        anchors.fill: parent
                        radius: cell.cornerRadius
                        color: cell.chosen ? Theme.secondaryContainer : Theme.surfaceContainerHigh

                        Behavior on color {
                            ColorMotion {}
                        }

                        Behavior on radius {
                            NumberMotion {
                                easing.bezierCurve: Style.emphasizedDecelerate
                            }
                        }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: cell.modelData.icon
                        font.pixelSize: Style.iconSizeXl
                        fill: cell.chosen ? 1 : 0
                        color: cell.chosen ? Theme.inkSecondaryContainer : Theme.inkSurfaceVariant
                    }
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignRight
            Layout.topMargin: Style.buttonGap
            spacing: Style.buttonGap

            Button {
                text: "Cancel"
                variant: "text"
                onClicked: root.close()
            }

            Button {
                text: "Save"
                variant: "filled"
                onClicked: root.save()
            }
        }
    }
}
