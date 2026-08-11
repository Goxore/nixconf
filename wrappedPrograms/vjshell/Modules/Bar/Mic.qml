import qs.Commons
import qs.Services
import qs.Widgets

BarButton {
    icon: AudioService.micMuted ? Icons.micOff : Icons.micOn
    iconColor: AudioService.micMuted ? Theme.urgent : Theme.active
    tooltip: AudioService.micMuted ? "Microphone muted" : "Microphone live"

    onClicked: AudioService.toggleMicMute()
}
