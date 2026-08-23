pragma Singleton
import QtQuick

/**
 * Global constants for the Island shell.
 * Single source of truth for fonts, icon codepoints, sizing, animation.
 * Every component reads from here — no hardcoded values scattered around.
 */
QtObject {
    id: root

    // -- Fonts --
    readonly property string fontFamily: "JetBrainsMono Nerd Font Mono"
    readonly property string iconFontFamily: "Material Icons"

    // -- Animation durations (ms) --
    readonly property int animFast: 120
    readonly property int animNormal: 200
    readonly property int animSlow: 300

    // -- Hover-intent delays (ms) --
    // Two tiers: a quick "peek" reveal (wifi/battery/last-played, no
    // full Control Center) and the slower full expand. Both timers start
    // together on hover-enter; peek resolves first since its delay is shorter.
    readonly property int peekOpenDelay: 120
    readonly property int peekCloseDelay: 400
    readonly property int hoverOpenDelay: 350
    readonly property int hoverCloseDelay: 250

    // -- Workspace-aware auto-hide --
    // Island is only ever forced hidden when the active workspace has at
    // least one window AND the island itself isn't mid-interaction. This
    // strip is the always-present hover target that brings it back.
    readonly property int hotZoneWidth: 300
    readonly property int hotZoneHeight: 12

    // -- Toast timeouts (ms) --
    readonly property int toastTimeout: 1400
    readonly property int notifToastTimeout: 4000

    // -- Sizing --
    readonly property int pillMinWidth: 200
    readonly property int toggleWidth: 42
    readonly property int toggleHeight: 24
    readonly property int iconSizeSmall: 14
    readonly property int iconSizeNormal: 16
    readonly property int iconSizeLarge: 20

    // -- Material Icons codepoints (verified in font cmap) --

    // Wifi
    readonly property string iconWifi: "\uE63E"          // wifi
    readonly property string iconWifiOff: "\uE648"       // wifi_off

    // Bluetooth
    readonly property string iconBtOn: "\uE1A7"          // bluetooth
    readonly property string iconBtOff: "\uE1A9"         // bluetooth_disabled

    // Battery levels (bar icons, 5 bars down to 1 bar)
    readonly property string iconBatFull: "\uE1A4"       // battery_full
    readonly property string iconBat5Bar: "\uEBD4"       // battery_5_bar
    readonly property string iconBat4Bar: "\uEBE2"       // battery_4_bar
    readonly property string iconBat3Bar: "\uEBDD"       // battery_3_bar
    readonly property string iconBat2Bar: "\uEBE0"       // battery_2_bar
    readonly property string iconBat1Bar: "\uEBD9"       // battery_1_bar
    readonly property string iconBatAlert: "\uE19C"      // battery_alert
    readonly property string iconBatCharge: "\uE1A3"     // battery_charging_full

    // Volume
    readonly property string iconVolHigh: "\uE050"       // volume_up
    readonly property string iconVolMed: "\uE04D"        // volume_down
    readonly property string iconVolLow: "\uE04E"        // volume_mute
    readonly property string iconVolMute: "\uE04F"       // volume_off

    // Brightness (7 levels: high to low)
    readonly property string iconBrightHigh: "\uE3AC"    // brightness_7
    readonly property string iconBright6: "\uE3AB"       // brightness_6
    readonly property string iconBright5: "\uE3AA"       // brightness_5
    readonly property string iconBright4: "\uE3A9"       // brightness_4
    readonly property string iconBright3: "\uE3A8"       // brightness_3
    readonly property string iconBright2: "\uE3A7"       // brightness_2
    readonly property string iconBright1: "\uE3A6"       // brightness_1
    readonly property string iconBright: "\uE3AB"        // brightness_6 (default)

    // Control Center toggles
    readonly property string iconSettings: "\uE8B8"      // settings
    readonly property string iconPeace: "\uE9E0"         // shield (DND/focus)
    readonly property string iconNightLight: "\uF03D"    // nightlight

    // Media controls
    readonly property string iconPlay: "\uE037"          // play_arrow
    readonly property string iconPause: "\uE034"         // pause
    readonly property string iconNext: "\uE044"          // skip_next
    readonly property string iconPrev: "\uE045"          // skip_previous

    // Power menu
    readonly property string iconLock: "\uE897"          // lock
    readonly property string iconSuspend: "\uF03D"       // nightlight (moon for suspend)
    readonly property string iconLogout: "\uE9BA"        // logout
    readonly property string iconReboot: "\uF053"        // restart_alt
    readonly property string iconPower: "\uE8AC"         // power_settings_new

    // Navigation
    readonly property string iconBack: "\uE5C4"          // arrow_back
    readonly property string iconChevron: "\uE5CC"       // chevron_right
    readonly property string iconSearch: "\uE8B6"        // search
    readonly property string iconClose: "\uE5CD"         // close

    // Status / semantic
    readonly property string iconSuccess: "\uE86C"       // check_circle
    readonly property string iconWarning: "\uE002"       // warning
    readonly property string iconDanger: "\uE000"        // error
    readonly property string iconInfo: "\uE88E"          // info
    readonly property string iconCheck: "\uE5CA"         // check
    readonly property string iconPerson: "\uE7FD"        // person
    readonly property string iconDndOn: "\uE644"         // do_not_disturb_on
    readonly property string iconDndOff: "\uE643"        // do_not_disturb_off
    readonly property string iconNotifications: "\uE7F4" // notifications

    // -- Helper functions --

    function batteryIcon(percentage, charging) {
        if (charging) return iconBatCharge
        if (percentage >= 90) return iconBatFull
        if (percentage >= 75) return iconBat5Bar
        if (percentage >= 50) return iconBat4Bar
        if (percentage >= 35) return iconBat3Bar
        if (percentage >= 20) return iconBat2Bar
        if (percentage >= 10) return iconBat1Bar
        return iconBatAlert
    }

    function wifiIcon(strength) {
        return iconWifi
    }

    function semanticIcon(severity) {
        switch (severity) {
            case "success": return iconSuccess
            case "warning": return iconWarning
            case "danger":  return iconDanger
            default:        return iconInfo
        }
    }

    function semanticColor(severity, themeColors) {
        switch (severity) {
            case "success": return themeColors.success
            case "warning": return themeColors.warning
            case "danger":  return themeColors.danger
            default:        return themeColors.textMuted
        }
    }
}
