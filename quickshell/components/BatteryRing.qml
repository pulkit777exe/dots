import QtQuick
import "../services"

Item {
    id: root

    property int percentage: Battery.percentage
    property bool charging: Battery.charging
    property color strokeColor: charging ? Theme.colors.accent : Qt.rgba(1, 1, 1, 0.95)
    property color trackColor: Qt.rgba(1, 1, 1, 0.15)
    property real strokeWidth: 2.2

    implicitWidth: 32
    implicitHeight: 32

    property real animatedPercentage: percentage
    Behavior on animatedPercentage {
        NumberAnimation { duration: MotionConfig.fade(); easing.type: Easing.OutCubic }
    }

    onAnimatedPercentageChanged: canvas.requestPaint()
    onStrokeColorChanged: canvas.requestPaint()
    onTrackColorChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        renderTarget: Canvas.Image
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            const cx = width / 2;
            const cy = height / 2;
            const r = (Math.min(width, height) - root.strokeWidth) / 2;
            if (r <= 0) return;

            // Draw subtle background full circle
            ctx.lineWidth = root.strokeWidth;
            ctx.strokeStyle = root.trackColor;
            ctx.lineCap = "round";
            ctx.beginPath();
            ctx.arc(cx, cy, r, 0, 2 * Math.PI);
            ctx.stroke();

            // Progress from top (-PI/2) symmetrically down both sides
            const frac = Math.max(0.01, Math.min(1.0, root.animatedPercentage / 100.0));
            const startAngle = -Math.PI / 2 - (frac * Math.PI);
            const endAngle = -Math.PI / 2 + (frac * Math.PI);

            ctx.lineWidth = root.strokeWidth;
            ctx.strokeStyle = root.strokeColor;
            ctx.lineCap = "round";
            ctx.beginPath();
            ctx.arc(cx, cy, r, startAngle, endAngle, false);
            ctx.stroke();
        }
    }
}
