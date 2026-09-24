import QtQuick
import qs.Commons

ColorAnimation {
    duration: Style.durState
    easing.type: Easing.Bezier
    easing.bezierCurve: Style.standard
}
