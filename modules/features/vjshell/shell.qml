import Quickshell
import qs.Modules.Projects
import qs.Modules.Bar
import qs.Modules.Bluetooth
import qs.Modules.Calendar
import qs.Modules.Devices
import qs.Modules.Launcher
import qs.Modules.Menu
import qs.Modules.Lyrics
import qs.Modules.Music
import qs.Modules.MicOverlay
import qs.Modules.Network
import qs.Modules.Notifications
import qs.Modules.Osd
import qs.Modules.Processes
import qs.Modules.VR

ShellRoot {
    Variants {
        model: Quickshell.screens
        delegate: Bar {}
    }

    Variants {
        model: Quickshell.screens
        delegate: TrayMenu {}
    }

    Variants {
        model: Quickshell.screens
        delegate: BarTooltip {}
    }

    Variants {
        model: Quickshell.screens
        delegate: Osd {}
    }

    Variants {
        model: Quickshell.screens
        delegate: Launcher {}
    }

    Variants {
        model: Quickshell.screens
        delegate: BluetoothPanel {}
    }

    Variants {
        model: Quickshell.screens
        delegate: WifiPanel {}
    }

    Variants {
        model: Quickshell.screens
        delegate: VrPanel {}
    }

    Variants {
        model: Quickshell.screens
        delegate: DevicesPanel {}
    }

    Variants {
        model: Quickshell.screens
        delegate: CalendarPanel {}
    }

    Variants {
        model: Quickshell.screens
        delegate: ProcessPanel {}
    }

    Variants {
        model: Quickshell.screens
        delegate: ProjectBar {}
    }

    Variants {
        model: Quickshell.screens
        delegate: Menu {}
    }

    Variants {
        model: Quickshell.screens
        delegate: ProjectPicker {}
    }

    Variants {
        model: Quickshell.screens
        delegate: ProjectEditor {}
    }

    Variants {
        model: Quickshell.screens
        delegate: NotificationPopups {}
    }

    Variants {
        model: Quickshell.screens
        delegate: NotificationHistory {}
    }

    Variants {
        model: Quickshell.screens
        delegate: Lyrics {}
    }

    Variants {
        model: Quickshell.screens
        delegate: LyricsControlPanel {}
    }

    Variants {
        model: Quickshell.screens
        delegate: MusicPanel {}
    }

    Variants {
        model: Quickshell.screens
        delegate: MicOverlay {}
    }
}
