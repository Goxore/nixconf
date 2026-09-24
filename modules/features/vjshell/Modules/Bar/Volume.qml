import Quickshell
import qs.Commons
import qs.Services
import qs.Widgets

BarButton {
    icon: AudioService.volumeIcon
    iconColor: AudioService.muted ? Theme.error : Theme.inkSurfaceVariant
    iconFill: AudioService.muted ? 1 : 0
    tooltip: AudioService.muted ? "Muted" : AudioService.percent + "%"

    onClicked: AudioService.toggleMute()
    onScrolled: direction => AudioService.stepVolume(direction * AudioService.step)
    onRightClicked: Quickshell.execDetached(["pwvucontrol"])
}
