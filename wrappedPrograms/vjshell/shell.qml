import Quickshell
import qs.Modules.Bar
import qs.Modules.Bluetooth
import qs.Modules.Launcher
import qs.Modules.Network
import qs.Modules.Notifications
import qs.Modules.Osd

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
        delegate: NotificationPopups {}
    }

    Variants {
        model: Quickshell.screens
        delegate: NotificationHistory {}
    }
}
