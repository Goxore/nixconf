import QtQuick
import QtTest
import Quickshell
import qs.Widgets

ShellRoot {
    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 200
        implicitHeight: 100
        Button {
            id: button
            text: "Fixture"
            property int count: 0
            onClicked: count++
        }
        TestCase {
            id: input
            when: false
        }
        Timer {
            interval: 100
            running: true
            onTriggered: {
                button.forceActiveFocus();
                input.keyClick(Qt.Key_Return);
                if (button.count !== 1)
                    throw new Error("Return activation");
                input.keyClick(Qt.Key_Space);
                if (button.count !== 2)
                    throw new Error("Space activation");
                button.enabled = false;
                input.keyClick(Qt.Key_Return);
                if (button.count !== 2)
                    throw new Error("Disabled activation");
                console.log("PASS keyboard activation and disabled controls");
                Qt.quit();
            }
        }
    }
}
