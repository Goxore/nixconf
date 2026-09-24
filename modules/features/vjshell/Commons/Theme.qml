pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    function mix(from, to, amount) {
        return Qt.rgba(from.r + (to.r - from.r) * amount, from.g + (to.g - from.g) * amount, from.b + (to.b - from.b) * amount, 1);
    }

    function withAlpha(source, amount) {
        return Qt.rgba(source.r, source.g, source.b, amount);
    }

    function luminance(source) {
        const channel = value => value <= 0.03928 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4);
        return 0.2126 * channel(source.r) + 0.7152 * channel(source.g) + 0.0722 * channel(source.b);
    }

    function contrast(foreground, background) {
        const bright = luminance(foreground);
        const dark = luminance(background);
        return (Math.max(bright, dark) + 0.05) / (Math.min(bright, dark) + 0.05);
    }

    readonly property color shade: "#000000"

    readonly property color primary: Colors.primary
    readonly property color inkPrimary: Colors.inkPrimary
    readonly property color primaryContainer: Colors.primaryContainer
    readonly property color inkPrimaryContainer: Colors.inkPrimaryContainer

    readonly property color secondary: Colors.secondary
    readonly property color inkSecondary: Colors.inkSecondary
    readonly property color secondaryContainer: Colors.secondaryContainer
    readonly property color inkSecondaryContainer: Colors.inkSecondaryContainer

    readonly property color tertiary: Colors.tertiary
    readonly property color inkTertiary: Colors.inkTertiary
    readonly property color tertiaryContainer: Colors.tertiaryContainer
    readonly property color inkTertiaryContainer: Colors.inkTertiaryContainer

    readonly property color error: Colors.error
    readonly property color inkError: Colors.inkError
    readonly property color errorContainer: Colors.errorContainer
    readonly property color inkErrorContainer: Colors.inkErrorContainer

    readonly property color warning: Colors.warning
    readonly property color inkWarning: Colors.inkWarning
    readonly property color warningContainer: Colors.warningContainer
    readonly property color inkWarningContainer: Colors.inkWarningContainer

    readonly property color success: Colors.success
    readonly property color inkSuccess: Colors.inkSuccess
    readonly property color successContainer: Colors.successContainer
    readonly property color inkSuccessContainer: Colors.inkSuccessContainer

    readonly property color surface: Colors.surface
    readonly property color surfaceContainerLow: Colors.surfaceContainerLow
    readonly property color surfaceContainer: Colors.surfaceContainer
    readonly property color surfaceContainerHigh: Colors.surfaceContainerHigh
    readonly property color surfaceContainerHighest: Colors.surfaceContainerHighest

    readonly property color inkSurface: Colors.inkSurface
    readonly property color inkSurfaceVariant: Colors.inkSurfaceVariant

    readonly property color outline: Colors.outline
    readonly property color outlineVariant: Colors.outlineVariant

    readonly property color inverseSurface: Colors.inverseSurface
    readonly property color inkInverseSurface: Colors.inkInverseSurface

    readonly property color disabledContent: Colors.disabledContent
    readonly property color disabledContainer: Colors.disabledContainer
    readonly property color disabledOutline: Colors.disabledOutline

    readonly property var tones: ({
            primary: {
                color: primary,
                ink: inkPrimary,
                container: primaryContainer,
                inkContainer: inkPrimaryContainer
            },
            secondary: {
                color: secondary,
                ink: inkSecondary,
                container: secondaryContainer,
                inkContainer: inkSecondaryContainer
            },
            tertiary: {
                color: tertiary,
                ink: inkTertiary,
                container: tertiaryContainer,
                inkContainer: inkTertiaryContainer
            },
            error: {
                color: error,
                ink: inkError,
                container: errorContainer,
                inkContainer: inkErrorContainer
            },
            warning: {
                color: warning,
                ink: inkWarning,
                container: warningContainer,
                inkContainer: inkWarningContainer
            },
            success: {
                color: success,
                ink: inkSuccess,
                container: successContainer,
                inkContainer: inkSuccessContainer
            },
            surface: {
                color: inkSurface,
                ink: surface,
                container: surfaceContainerHigh,
                inkContainer: inkSurface
            }
        })

    function tone(name) {
        return tones[name] ?? tones.surface;
    }

    readonly property var containerLevels: [surface, surfaceContainerLow, surfaceContainer, surfaceContainerHigh, surfaceContainerHighest]

    function containerFor(level) {
        return containerLevels[Math.max(0, Math.min(containerLevels.length - 1, level))];
    }

    readonly property var shadowLevels: [withAlpha(shade, 0), withAlpha(shade, 0.22), withAlpha(shade, 0.30), withAlpha(shade, 0.38)]

    function shadowFor(level) {
        return shadowLevels[Math.max(0, Math.min(shadowLevels.length - 1, level))];
    }

    function agentColor(signal, kind) {
        switch (signal) {
        case "alert":
            return error;
        case "done":
            return success;
        case "working":
            switch (kind) {
            case "codex":
                return tertiary;
            case "opencode":
                return primary;
            default:
                return warning;
            }
        default:
            return inkSurfaceVariant;
        }
    }

    function loadColor(share) {
        if (share >= 0.85)
            return error;
        if (share >= 0.6)
            return warning;
        return primary;
    }
}
