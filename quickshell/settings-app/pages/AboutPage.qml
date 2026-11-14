import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../services"

ColumnLayout {
    id: root
    spacing: 12

    readonly property var searchKeys: ["about", "system", "info", "version",
        "kernel", "os", "hostname", "cpu", "gpu", "memory", "ram", "disk",
        "storage", "uptime", "hyprland", "quickshell"]

    property var info: ({})

    function value(key, fallback) {
        const v = root.info ? root.info[key] : undefined;
        return v === undefined || v === null || v === "" ? (fallback || "—") : String(v);
    }

    function refresh() {
        if (!infoProc.running) infoProc.running = true;
    }

    Component.onCompleted: refresh()
    onVisibleChanged: if (visible) refresh()

    Process {
        id: infoProc
        command: ["python3", Quickshell.shellDir + "/scripts/system-info.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.info = JSON.parse(text);
                } catch (e) {
                    console.warn("About: could not parse system info:", e);
                }
            }
        }
    }

    component InfoRow: RowLayout {
        id: row
        property string label: ""
        property string detail: ""

        Layout.fillWidth: true
        Layout.preferredHeight: 38
        spacing: 12

        Label {
            text: row.label
            font.pixelSize: Theme.px(13)
            color: Theme.withAlpha(Theme.colors.text, 0.9)
            Layout.preferredWidth: 150
            elide: Text.ElideRight
        }

        Label {
            Layout.fillWidth: true
            text: row.detail
            font.pixelSize: Theme.px(12)
            color: Theme.withAlpha(Theme.colors.text, 0.52)
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
        }
    }

    SettingsHeader {
        icon: "info"
        title: "About"
        subtitle: "System information and software versions."
    }

    SettingsCard {
        SettingsLabelRow { label: "Device" }

        InfoRow { label: "Name"; detail: root.value("device", "This computer") }
        InfoRow { label: "Hostname"; detail: root.value("hostname") }
        InfoRow { label: "Operating system"; detail: root.value("os") }
        InfoRow { label: "Kernel"; detail: root.value("kernel") + " · " + root.value("arch") }
        InfoRow { label: "Uptime"; detail: root.value("uptime") }
    }

    SettingsCard {
        SettingsLabelRow { label: "Hardware" }

        InfoRow { label: "Processor"; detail: root.value("cpu") }
        InfoRow { label: "Cores"; detail: root.value("cores") }
        InfoRow { label: "Graphics"; detail: root.value("gpu") }
        InfoRow { label: "Memory"; detail: root.value("memory") }
        InfoRow { label: "Storage"; detail: root.value("disk") }
    }

    SettingsCard {
        SettingsLabelRow { label: "Software" }

        InfoRow { label: "Hyprland"; detail: root.value("hyprland") }
        InfoRow { label: "Quickshell"; detail: root.value("quickshell") }
        InfoRow { label: "Session"; detail: root.value("session") }
        InfoRow { label: "Desktop"; detail: root.value("desktop") }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 8
            Item { Layout.fillWidth: true }
            StyledButton {
                label: infoProc.running ? "Refreshing…" : "Refresh"
                onClicked: root.refresh()
            }
        }
    }
}
