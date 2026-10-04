import QtQuick
import QtQuick.Layouts
import "../../../components"
import "../../../services"

// "Suspend and lid behavior": everything this pane knows about whether the
// machine can suspend, whether there is a lid, and what logind says should
// happen when it closes.
//
// It was a section inside SystemPage.qml, and the split is along the line the
// file itself already drew. Power Mode is a control -- four power-profile buttons
// the user presses. This is a readout -- three cards that report what logind
// answered, one of them read-only on purpose because logind exposes no
// unprivileged write path for it. Different lifetimes too: the Power Mode card
// never needs a re-read, this section polls for as long as it is on screen.
//
// What moved here with the section is its polling. That is the part worth
// stating plainly, because it is the one thing that must not be split in half:
// `refresh()` and `watching` are two ends of the same pairing with PowerManager,
// and the pane below passes this section a single `paneVisible` so both ends see
// the same on/off signal they saw when this code lived in SystemPage.

ColumnLayout {
    id: root
    spacing: 12

    // Every value the section shows arrives through one of these bindings. Each
    // one has a fallback word, because the values are re-read while the pane is
    // open and a blank field in a settings pane reads as a broken pane. It also
    // keeps a missing or not-yet-answered value down to the one card that wanted
    // it.
    //
    // "unknown" is the fallback for anything logind might decline to answer --
    // it is the truthful answer to "we did not find out", which is not the
    // same as "no". suspendState is the exception: its own enum has no
    // unknown, and an unreported suspend state on a running machine is "idle".
    readonly property string suspendState: PowerManager.suspendState || "idle"
    readonly property string suspendCapability: PowerManager.suspendCapabilityClass || "unknown"
    readonly property string suspendDetail: PowerManager.suspendDetail || ""
    readonly property string lidState: PowerManager.lidState || "unknown"
    readonly property string lidPosition: PowerManager.lidPosition || "unknown"
    readonly property string lidDetail: PowerManager.lidDetail || ""

    // The three lid conditions are three independent logind values, so they
    // are read, labelled and drawn apart -- see the card at the bottom of the
    // section. The summary line below reuses these same three; there is no
    // second place where a policy is spelled out and could disagree with the
    // rows.
    readonly property string batteryPolicy: policyLabel(PowerManager.lidPolicy)
    readonly property string externalPowerPolicy: policyLabel(PowerManager.lidExternalPowerPolicy)
    readonly property string dockedPolicy: policyLabel(PowerManager.lidDockedPolicy)

    readonly property string lidPolicyCapability: PowerManager.lidPolicyCapabilityClass || "unknown"
    readonly property string lidPolicyDetail: PowerManager.lidPolicyDetail || ""

    // The same three values, in one readable line, after the reason there is
    // nothing to change. The policyDetail is the service's explanation of the
    // capability class above it; the tail is the state of each condition, so
    // the card can be read as one sentence as well as three rows.
    readonly property string lidPolicySummary: {
        const conditions = "battery: " + batteryPolicy
            + ", external power: " + externalPowerPolicy
            + ", docked: " + dockedPolicy;
        return lidPolicyDetail.length > 0 ? lidPolicyDetail + " — " + conditions : conditions;
    }

    // Whether the settings pane that hosts this section is on screen, passed in
    // rather than read off `visible`.
    //
    // Two reasons, and the second is the one that bites. Binding this to the
    // pane's `visible` directly would be simpler, and it would make the section
    // itself invisible whenever the pane is -- which is invisible most of the
    // time, because PagePanel keeps every page alive and only fades between them.
    // A ColumnLayout drops its invisible children, so the page would lose ~270px
    // of height the moment you navigated away from it and get it back on the
    // way in. A property that mirrors the pane without touching `visible` gives
    // the same signal to the poll and leaves the layout alone.
    property bool paneVisible: false

    // One pill in the whole configuration, so the state badges here are built
    // on it. The label always spells the state out; the colour only reinforces
    // it, because the themes do not keep their accents apart -- ariadne's
    // accent and success are within a shade of each other, and catppuccin's
    // accent is plain grey -- so a state that must not read as alarming cannot
    // be carried by hue alone.
    component StatusPill: Pill {
        id: badge

        property string label: ""
        property color tone: Theme.colors.textMuted

        horizontalPadding: 9
        verticalPadding: 3
        pillColor: Qt.alpha(tone, 0.16)

        StyledText {
            text: badge.label
            font.pixelSize: 11
            font.weight: Font.DemiBold
            textColor: badge.tone
        }
    }

    // Label, the value it currently holds, then what we know about the thing
    // itself. Same right-hand-value idiom as SettingsSliderRow.
    component StateRow: RowLayout {
        id: stateRow

        property string label: ""
        property string value: ""
        property string pillLabel: ""
        property color pillTone: Theme.colors.textMuted

        Layout.fillWidth: true
        spacing: 8

        StyledText {
            Layout.fillWidth: true
            variant: "mediaTitle"
            font.pixelSize: 13
            text: stateRow.label
            elide: Text.ElideRight
        }

        StyledText {
            text: stateRow.value
            variant: "mediaTitle"
            font.pixelSize: 13
            textColor: Theme.colors.textMuted
        }

        StatusPill {
            label: stateRow.pillLabel
            tone: stateRow.pillTone
        }
    }

    // One logind condition. Three of these, because the battery, external
    // power and docked answers are three independent values and averaging them
    // into one "lid policy" would be a claim logind never made.
    component PolicyRow: RowLayout {
        id: policyRow

        property string label: ""
        property string value: ""

        Layout.fillWidth: true
        spacing: 8

        StyledText {
            Layout.fillWidth: true
            variant: "mediaSubtitle"
            font.pixelSize: 12
            text: policyRow.label
            elide: Text.ElideRight
        }

        StyledText {
            text: policyRow.value
            variant: "mediaTitle"
            font.pixelSize: 12
            textColor: Theme.colors.text
        }
    }

    function cap(s) {
        const v = s === undefined || s === null ? "" : String(s);
        return v.length === 0 ? "" : v.charAt(0).toUpperCase() + v.slice(1);
    }

    // lidState is three-valued and "unknown" is a real answer on a machine
    // that cannot report a lid switch. It is never folded into the unavailable
    // branch: it gets its own word, its own tone, and a question mark, so the
    // difference between "we were not told" and "there is no lid" survives a
    // greyscale screenshot as well as a colour-blind reader.
    function stateLabel(state) {
        const word = root.cap(state);
        return state === "unknown" ? "? " + word : word;
    }

    function stateTone(state) {
        switch (state) {
            case "ready":
            case "available":
                return Theme.colors.success;
            case "error":
                return Theme.colors.danger;
            case "unknown":
                return Theme.colors.warning;
            default:
                return Theme.colors.textMuted;
        }
    }

    // logind reports "no preference" as an empty property, not as a token, so
    // an empty policy is spelled out here. A blank cell would look like the
    // section failed to read anything.
    function policyLabel(raw) {
        const v = raw === undefined || raw === null ? "" : String(raw).trim();
        if (v.length === 0) return "logind default";

        // validLidAction answers a question about logind's tokens, and these
        // words are this section's rendering of the empty case rather than one
        // of them. Asking about them gets an honest "no" and a wrong accusation.
        if (v === "logind default") return v;

        return root.isKnownLidAction(v) ? v : v + " (not a logind lid action)";
    }

    // The service owns the list of the eleven logind actions; this is the only
    // question worth asking it from here. A value it does not recognise is
    // still shown -- it is what logind said -- but marked, so a stale value is
    // never passed off as something logind understands. A failure to answer is
    // read as "assume valid": under-warning beats stamping a value the machine
    // did not produce.
    function isKnownLidAction(value) {
        try {
            return typeof PowerManager.validLidAction !== "function"
                || PowerManager.validLidAction(value) === true;
        } catch (e) {
            return true;
        }
    }

    // One real re-read, requested by a button that says so. PowerManager drops
    // it if a probe is already in flight, so a double-click cannot stack
    // copies of the same one-shot process.
    function refresh() {
        try {
            if (typeof PowerManager.refresh === "function") PowerManager.refresh();
        } catch (e) {
            // Nothing to refresh. The cards keep showing their last answers.
        }
    }

    // PagePanel keeps every page alive and hides the ones you are not looking
    // at with `visible: opacity > 0.01`, so `paneVisible` is this section's real
    // on/off signal -- Component.onCompleted alone also fires for the pages
    // that were never opened, which would leave the timer running for nobody.
    // The three handlers together are the pair: completed for the pane you
    // open first, visibility for every switch after it, destruction to make
    // sure a torn-down pane cannot leave the poll alive.
    function syncWatching() {
        try {
            PowerManager.watching = root.paneVisible;
        } catch (e) {
            // The service is not answering; there is nothing to keep alive.
        }
    }

    onPaneVisibleChanged: syncWatching()
    Component.onCompleted: syncWatching()
    Component.onDestruction: {
        try {
            PowerManager.watching = false;
        } catch (e) {
        }
    }

    SettingsSectionLabel {
        label: "Suspend and lid behavior"
    }

    // logind re-reads these values independently of the pane, so a plug-in or a
    // closed lid can land after the card has been drawn. One button, one real
    // re-read, rather than a control that only looks like a control.
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        spacing: 8

        StyledText {
            Layout.fillWidth: true
            variant: "mediaSubtitle"
            text: "Read from logind. Values can change while this pane is open."
            elide: Text.ElideRight
        }

        StyledButton {
            text: "Refresh"
            variant: "ghost"
            onClicked: root.refresh()
        }
    }

    SettingsCard {
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            StateRow {
                label: "Suspend"
                value: root.suspendCapability
                pillLabel: root.stateLabel(root.suspendState)
                pillTone: root.stateTone(root.suspendState)
            }

            StyledText {
                Layout.fillWidth: true
                Layout.topMargin: 2
                visible: text.length > 0
                variant: "mediaSubtitle"
                wrapMode: Text.WordWrap
                text: root.suspendDetail
            }
        }
    }

    SettingsCard {
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            // The heading is two-valued because "we were not told" and "there
            // is no lid switch" leave the section with the same thing to draw,
            // and the answer to that is not a vaguer heading -- it is the badge
            // and the line under it, which name the state and say what logind
            // was asked. The value column reads "Unknown" rather than "none", so
            // nothing on this card claims to know what hardware is fitted.
            StateRow {
                label: root.lidState === "available" ? "Laptop lid" : "Laptop lid unavailable"
                value: root.cap(root.lidPosition)
                pillLabel: root.stateLabel(root.lidState)
                pillTone: root.stateTone(root.lidState)
            }

            StyledText {
                Layout.fillWidth: true
                Layout.topMargin: 2
                visible: text.length > 0
                variant: "mediaSubtitle"
                wrapMode: Text.WordWrap
                text: root.lidDetail
            }
        }
    }

    // Read-only, and that is a finding rather than a missing feature.
    // logind exposes HandleLidSwitch{ExternalPower,Docked} as const properties
    // with no SetHandleLidSwitch method anywhere on the interface, so there is
    // no unprivileged write path; the only route is a root-owned
    // `systemctl set-property org.freedesktop.login1-handle-lid-switch`
    // drop-in. A selector here would be a control that cannot do anything, so
    // the capability class is shown instead of pretending to be editable.
    SettingsCard {
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            StateRow {
                label: "Lid policy"
                value: root.lidPolicyCapability
                pillLabel: "Read only"
                pillTone: Theme.colors.textMuted
            }

            PolicyRow { label: "On battery"; value: root.batteryPolicy }
            PolicyRow { label: "On external power"; value: root.externalPowerPolicy }
            PolicyRow { label: "Docked"; value: root.dockedPolicy }

            StyledText {
                Layout.fillWidth: true
                Layout.topMargin: 2
                variant: "mediaSubtitle"
                wrapMode: Text.WordWrap
                text: root.lidPolicySummary
            }
        }
    }
}