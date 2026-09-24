import QtQuick
import QtQuick.Layouts
import qs.Commons

Item {
    id: root

    property string text: ""
    property string placeholder: ""
    property string label: ""
    property string icon: ""
    property string variant: "search"
    property string role: "bodyLarge"
    property bool clearable: variant === "search"

    readonly property bool focused: input.activeFocus
    readonly property bool pill: variant === "search"
    readonly property var spec: Style.typeFor(role)

    signal edited(string value)
    signal accepted(string value)
    signal moved(int step)
    signal escaped

    function take() {
        input.forceActiveFocus();
    }

    function selectAll() {
        input.selectAll();
    }

    function clear() {
        input.clear();
        root.edited("");
    }

    Layout.fillWidth: true
    implicitWidth: Style.listMin
    implicitHeight: column.implicitHeight

    onTextChanged: if (input.text !== text)
        input.text = text

    ColumnLayout {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.spacing

        Label {
            Layout.fillWidth: true
            Layout.leftMargin: Style.spacing
            visible: root.label !== ""
            text: root.label
            role: "labelMedium"
            color: root.focused ? Theme.primary : Theme.inkSurfaceVariant
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: root.variant === "plain" ? Math.max(Style.iconBox, root.spec.lineHeight) : Style.listItemOneLine
            radius: root.pill ? height / 2 : Style.radiusS
            color: root.variant === "plain" ? "transparent" : root.pill ? Theme.surfaceContainerHigh : Theme.surfaceContainerHighest
            border.width: root.variant !== "plain" && root.focused ? Style.focusRing : 0
            border.color: Theme.primary

            Behavior on color {
                ColorMotion {}
            }

            TapHandler {
                onTapped: input.forceActiveFocus()
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: root.variant === "plain" ? 0 : Style.panelPadding
                anchors.rightMargin: root.variant === "plain" ? 0 : clearButton.visible ? Style.spacing : Style.panelPadding
                spacing: Style.panelPadding

                MaterialIcon {
                    visible: root.icon !== ""
                    text: root.icon
                    font.pixelSize: Style.iconSizeXl
                    color: root.focused ? Theme.primary : Theme.inkSurfaceVariant
                }

                TextInput {
                    id: input

                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter

                    text: root.text
                    focus: true
                    clip: true
                    font.family: Style.fontFamily
                    font.pixelSize: root.spec.size
                    font.weight: root.spec.weight
                    color: Theme.inkSurface
                    selectionColor: Theme.primary
                    selectedTextColor: Theme.inkPrimary
                    selectByMouse: true
                    verticalAlignment: TextInput.AlignVCenter

                    Accessible.role: Accessible.EditableText
                    Accessible.name: root.label || root.placeholder

                    onTextEdited: root.edited(text)
                    onAccepted: root.accepted(text)

                    Keys.onEscapePressed: root.escaped()
                    Keys.onUpPressed: root.moved(-1)
                    Keys.onDownPressed: root.moved(1)
                    Keys.onPressed: event => {
                        if (!(event.modifiers & Qt.ControlModifier))
                            return;
                        if (event.key === Qt.Key_N)
                            root.moved(1);
                        else if (event.key === Qt.Key_P)
                            root.moved(-1);
                        else
                            return;
                        event.accepted = true;
                    }

                    Label {
                        anchors.fill: parent
                        visible: input.text === ""
                        text: root.placeholder
                        role: root.role
                        color: Theme.inkSurfaceVariant
                    }
                }

                IconButton {
                    id: clearButton

                    visible: root.clearable && input.text !== ""
                    icon: Icons.close
                    compact: true
                    description: root.placeholder
                    onClicked: {
                        root.clear();
                        input.forceActiveFocus();
                    }
                }
            }
        }
    }
}
