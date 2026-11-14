import QtQuick
import QtQuick.Layouts
import "../../services"

ColumnLayout {
    id: root
    spacing: 12

    readonly property var searchKeys: ["input", "keyboard", "layout", "language",
        "repeat", "rate", "delay", "numlock", "touchpad", "mouse", "pointer",
        "scroll", "tap", "natural", "sensitivity", "acceleration", "typing"]

    function set(key, value) {
        Config.set(key, value);
        HyprSettings.apply();
    }

    SettingsHeader {
        icon: "keyboard"
        title: "Input"
        subtitle: "Keyboard, pointer, and touchpad behavior."
    }

    SettingsCard {
        SettingsLabelRow { label: "Keyboard layout" }

        SettingsChoiceRow {
            label: "Layout"
            value: Config.kbLayout
            options: [
                { value: "us", label: "US" },
                { value: "gb", label: "UK" },
                { value: "de", label: "DE" },
                { value: "fr", label: "FR" },
                { value: "es", label: "ES" },
                { value: "it", label: "IT" },
                { value: "br", label: "BR" },
                { value: "ru", label: "RU" },
                { value: "jp", label: "JP" },
            ]
            onSelected: (v) => root.set("kbLayout", v)
        }

        SettingsTextFieldRow {
            label: "Variant"
            value: Config.kbVariant
            placeholder: "e.g. intl, nodeadkeys (empty for default)"
            onCommitted: (v) => root.set("kbVariant", v.trim())
        }

        SettingsSliderRow {
            label: "Repeat rate"
            value: Config.repeatRate
            from: 10
            to: 100
            suffix: " /s"
            onMoved: (v) => root.set("repeatRate", Math.round(v))
        }

        SettingsSliderRow {
            label: "Repeat delay"
            value: Config.repeatDelay
            from: 100
            to: 1000
            suffix: " ms"
            onMoved: (v) => root.set("repeatDelay", Math.round(v))
        }

        SettingsToggleRow {
            label: "Num Lock on by default"
            checked: Config.numlock
            onToggled: (v) => root.set("numlock", v)
        }
    }

    SettingsCard {
        SettingsLabelRow { label: "Pointer" }

        SettingsSliderRow {
            label: "Pointer speed"
            value: Config.sensitivity
            from: -1
            to: 1
            decimals: 2
            onMoved: (v) => root.set("sensitivity", Math.round(v * 100) / 100)
        }

        SettingsChoiceRow {
            label: "Acceleration"
            value: Config.accelProfile
            options: [
                { value: "adaptive", label: "Adaptive" },
                { value: "flat", label: "Flat" },
                { value: "custom", label: "Custom" },
            ]
            onSelected: (v) => root.set("accelProfile", v)
        }
    }

    SettingsCard {
        SettingsLabelRow { label: "Touchpad" }

        SettingsToggleRow {
            label: "Tap to click"
            checked: Config.tapToClick
            onToggled: (v) => root.set("tapToClick", v)
        }

        SettingsToggleRow {
            label: "Natural scrolling"
            checked: Config.naturalScroll
            onToggled: (v) => root.set("naturalScroll", v)
        }

        SettingsToggleRow {
            label: "Disable while typing"
            checked: Config.disableWhileTyping
            onToggled: (v) => root.set("disableWhileTyping", v)
        }

        SettingsChoiceRow {
            label: "Scroll method"
            value: Config.scrollMethod
            options: [
                { value: "two_finger", label: "Two fingers" },
                { value: "edge", label: "Edge" },
                { value: "button", label: "Button" },
            ]
            onSelected: (v) => root.set("scrollMethod", v)
        }
    }
}
