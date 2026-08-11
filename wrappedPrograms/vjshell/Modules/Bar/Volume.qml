import QtQuick
import Quickshell
import qs.Commons
import qs.Services
import qs.Widgets

BarButton {
    icon: {
        if (AudioService.muted)
            return Icons.volumeMuted;
        if (AudioService.volume < 0.34)
            return Icons.volumeLow;
        if (AudioService.volume < 0.67)
            return Icons.volumeMedium;
        return Icons.volumeHigh;
    }

    iconColor: AudioService.muted ? Theme.urgent : Theme.text
    tooltip: AudioService.muted ? "Muted" : Math.round(AudioService.volume * 100) + "%"

    onClicked: AudioService.toggleMute()
    onScrolled: direction => AudioService.stepVolume(direction * AudioService.step)
    onRightClicked: Quickshell.execDetached(["pwvucontrol"])
}
