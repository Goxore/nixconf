import QtQuick
import Quickshell
import qs.Commons
import qs.Widgets

ShellRoot {
    id: root

    readonly property var tones: ["primary", "secondary", "tertiary", "error", "warning", "success"]

    readonly property var surfaces: ["surface", "surfaceContainerLow", "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest"]

    property var failures: []

    function demand(label, foreground, background, minimum) {
        const ratio = Theme.contrast(foreground, background);
        if (ratio < minimum)
            failures.push(label + " " + ratio.toFixed(2) + " < " + minimum);
    }

    function checkColors() {
        for (const tone of tones) {
            demand("filled " + tone, Theme.tone(tone).ink, Theme.tone(tone).color, 4.5);
            demand("tonal " + tone, Theme.tone(tone).inkContainer, Theme.tone(tone).container, 4.5);
        }

        for (const name of surfaces) {
            const surface = Theme[name];
            demand("inkSurface on " + name, Theme.inkSurface, surface, 4.5);
            demand("inkSurfaceVariant on " + name, Theme.inkSurfaceVariant, surface, 4.5);
        }

        demand("outline on surface", Theme.outline, Theme.surface, 3.0);
        demand("disabled content on surface", Theme.disabledContent, Theme.surface, 3.0);
        demand("disabled container on surface", Theme.disabledContainer, Theme.surface, 1.1);
    }

    function checkTypeScale() {
        const roles = ["displaySmall", "headlineLarge", "headlineMedium", "headlineSmall", "titleLarge", "titleMedium", "titleSmall", "bodyLarge", "bodyMedium", "bodySmall", "labelLarge", "labelMedium", "labelSmall"];

        for (const role of roles) {
            const spec = Style.typeScale[role];
            if (!spec)
                failures.push("missing type role " + role);
            else if (!(spec.size > 0) || !(spec.lineHeight >= spec.size))
                failures.push("bad type metrics for " + role);
        }

        if (Style.typeFor("nonsense") !== Style.typeScale.bodyMedium)
            failures.push("typeFor did not fall back to bodyMedium");
    }

    function checkShape() {
        const scale = [Style.radiusXs, Style.radiusS, Style.radiusM, Style.radiusL, Style.radiusXl];
        const expected = [4, 8, 12, 16, 28];

        for (var index = 0; index < expected.length; index++) {
            if (scale[index] !== expected[index])
                failures.push("shape scale step " + index + " is " + scale[index] + ", expected " + expected[index]);
        }

        if (Style.stateHover !== 0.08 || Style.statePress !== 0.12 || Style.stateFocus !== 0.12)
            failures.push("state layer opacities drifted from the Material spec");

        if (Style.buttonHeight !== 40 || Style.touchTarget !== 48)
            failures.push("button height or touch target drifted from the Material spec");
    }

    FloatingWindow {
        visible: true
        implicitWidth: 460
        implicitHeight: 260

        Column {
            anchors.fill: parent
            spacing: Style.spacing

            Button {
                id: filled
                text: "Filled"
                icon: Icons.check
                variant: "filled"
            }

            Button {
                id: disabled
                text: "Disabled"
                icon: Icons.close
                variant: "outlined"
                enabled: false
            }

            Switch {
                id: toggle
                checked: true
            }

            Tabs {
                id: tabs
                width: 400
                current: "one"
                model: [
                    {
                        key: "one",
                        label: "One",
                        icon: Icons.check
                    },
                    {
                        key: "two",
                        label: "Two",
                        icon: Icons.close
                    }
                ]
            }
        }

        Timer {
            interval: 200
            running: true
            onTriggered: {
                root.checkColors();
                root.checkTypeScale();
                root.checkShape();

                if (filled.contentColor !== Theme.inkPrimary)
                    root.failures.push("filled button did not use inkPrimary");

                if (disabled.contentColor !== Theme.disabledContent)
                    root.failures.push("disabled button did not use the disabled content role");

                if (filled.implicitHeight !== Style.buttonHeight)
                    root.failures.push("button height did not follow the spec");

                if (tabs.index !== 0)
                    root.failures.push("tabs did not resolve the active index");

                if (root.failures.length > 0)
                    throw new Error("Material compliance: " + root.failures.join("; "));

                console.log("PASS material colour contrast, type scale, shape and component specs");
                Qt.quit();
            }
        }
    }
}
