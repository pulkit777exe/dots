import QtQuick
import "../services"

Icon {
    id: root

    property int level: 100      // 0-100
    property bool charging: false
    property bool available: true

    icon: {
        if (!root.available) return "battery_unknown"
        if (root.charging) return "battery_charging_full"
        if (root.level >= 95) return "battery_full"
        if (root.level >= 80) return "battery_6_bar"
        if (root.level >= 60) return "battery_5_bar"
        if (root.level >= 45) return "battery_4_bar"
        if (root.level >= 30) return "battery_3_bar"
        if (root.level >= 15) return "battery_2_bar"
        return "battery_alert"
    }

    iconColor: (!root.charging && root.available && root.level <= 15)
        ? Theme.colors.danger
        : Qt.rgba(1, 1, 1, 0.92)
}
