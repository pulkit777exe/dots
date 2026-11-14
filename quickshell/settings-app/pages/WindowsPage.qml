import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../services"

ColumnLayout {
    id: root
    spacing: 12

    readonly property var searchKeys: ["windows", "window", "gaps", "border",
        "rounding", "corners", "opacity", "transparency", "dim", "shadow",
        "blur", "animations", "effects", "decorations"]

    function set(key, value) {
        Config.set(key, value);
        HyprSettings.apply();
    }

    SettingsHeader {
        icon: "window"
        title: "Windows"
        subtitle: "Gaps, borders, transparency, blur, and window animations."
    }

    SettingsCard {
        SettingsLabelRow { label: "Layout" }

        SettingsSliderRow {
            label: "Inner gaps"
            value: Config.gapsIn
            from: 0
            to: 40
            suffix: " px"
            onMoved: (v) => root.set("gapsIn", Math.round(v))
        }

        SettingsSliderRow {
            label: "Outer gaps"
            value: Config.gapsOut
            from: 0
            to: 60
            suffix: " px"
            onMoved: (v) => root.set("gapsOut", Math.round(v))
        }

        SettingsSliderRow {
            label: "Border size"
            value: Config.borderSize
            from: 0
            to: 10
            suffix: " px"
            onMoved: (v) => root.set("borderSize", Math.round(v))
        }

        SettingsSliderRow {
            label: "Corner rounding"
            value: Config.rounding
            from: 0
            to: 30
            suffix: " px"
            onMoved: (v) => root.set("rounding", Math.round(v))
        }
    }

    SettingsCard {
        SettingsLabelRow { label: "Effects" }

        SettingsSliderRow {
            label: "Active window opacity"
            value: Config.activeOpacity
            from: 0.5
            to: 1
            decimals: 2
            onMoved: (v) => root.set("activeOpacity", Math.round(v * 100) / 100)
        }

        SettingsSliderRow {
            label: "Inactive window opacity"
            value: Config.inactiveOpacity
            from: 0.5
            to: 1
            decimals: 2
            onMoved: (v) => root.set("inactiveOpacity", Math.round(v * 100) / 100)
        }

        SettingsToggleRow {
            label: "Dim inactive windows"
            checked: Config.dimInactive
            onToggled: (v) => root.set("dimInactive", v)
        }

        SettingsSliderRow {
            visible: Config.dimInactive
            label: "Dim strength"
            value: Config.dimStrength
            from: 0
            to: 0.8
            decimals: 2
            onMoved: (v) => root.set("dimStrength", Math.round(v * 100) / 100)
        }
    }

    SettingsCard {
        SettingsLabelRow { label: "Blur & shadows" }

        SettingsToggleRow {
            label: "Blur"
            checked: Config.blurEnabled
            onToggled: (v) => root.set("blurEnabled", v)
        }

        SettingsSliderRow {
            visible: Config.blurEnabled
            label: "Blur size"
            value: Config.blurSize
            from: 1
            to: 20
            onMoved: (v) => root.set("blurSize", Math.round(v))
        }

        SettingsSliderRow {
            visible: Config.blurEnabled
            label: "Blur passes"
            value: Config.blurPasses
            from: 1
            to: 5
            onMoved: (v) => root.set("blurPasses", Math.round(v))
        }

        SettingsToggleRow {
            label: "Window shadows"
            checked: Config.shadowEnabled
            onToggled: (v) => root.set("shadowEnabled", v)
        }

        SettingsSliderRow {
            visible: Config.shadowEnabled
            label: "Shadow range"
            value: Config.shadowRange
            from: 0
            to: 40
            onMoved: (v) => root.set("shadowRange", Math.round(v))
        }
    }

    SettingsCard {
        SettingsLabelRow { label: "Motion" }

        SettingsToggleRow {
            label: "Window and workspace animations"
            checked: Config.animationsEnabled
            onToggled: (v) => root.set("animationsEnabled", v)
        }

        Label {
            Layout.fillWidth: true
            text: "Shell animations live on the Motion page. This switch controls the compositor."
            font.pixelSize: Theme.px(11)
            color: Theme.withAlpha(Theme.colors.text, 0.48)
            wrapMode: Text.WordWrap
        }
    }
}
