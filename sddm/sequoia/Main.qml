import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import SddmComponents 2.0

// Sequoia — macOS-style SDDM greeter.
// Reference: wallpaper fills the screen, "Saturday 12 April" + "11:44"
// top-centre, avatar + name + password dots bottom-centre.
// Auth path is deliberately boring: sddm.login(user, password, sessionIndex)
// with lastUser/lastSession defaults, failed logins clear + refocus.
Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "black"

    property string fontFamily: config.stringValue("fontFamily") || "SF Pro Display"
    property string bgSource: config.stringValue("background") || "wallpaper.jpg"
    property string hintInitial: config.stringValue("hintText") || "Enter your password to log in"
    property string dateFmt: config.stringValue("dateFormat") || "dddd d MMMM"
    property string timeFmt: config.stringValue("timeFormat") || "HH:mm"
    property real dimOverlay: parseFloat(config.stringValue("dimOverlay")) || 0.12

    property date now: new Date()
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property string msg: ""
    property bool msgIsError: false
    property bool busy: false

    // Role offsets mirror SDDM's UserModel (Name, RealName, HomeDir, Icon).
    // tidy-sddm uses Qt.UserRole+4 for the face icon; same here.
    function userName(idx) {
        var v = userModel.data(userModel.index(idx, 0), Qt.UserRole + 1)
        return v !== undefined && v !== null ? String(v) : ""
    }
    function userRealName(idx) {
        var v = userModel.data(userModel.index(idx, 0), Qt.UserRole + 2)
        var plain = userName(idx)
        if (v === undefined || v === null || String(v) === "")
            return plain
        return String(v)
    }
    function userIcon(idx) {
        var v = userModel.data(userModel.index(idx, 0), Qt.UserRole + 4)
        if (v === undefined || v === null || String(v) === "")
            return "avatar.jpg"
        return String(v)
    }
    function sessionName(idx) {
        if (!sessionModel || sessionModel.count === 0)
            return ""
        // SessionRole: Directory +1, File +2, Type +3, Name +4, Exec +5.
        var v = sessionModel.data(sessionModel.index(idx, 0), Qt.UserRole + 4)
        if (v !== undefined && v !== null && String(v) !== "")
            return String(v)
        return "session"
    }

    function currentUserName() {
        if (userModel.count === 0)
            return userModel.lastUser || ""
        return userName(Math.max(0, Math.min(userIndex, userModel.count - 1)))
    }

    function doLogin() {
        if (busy)
            return
        var u = currentUserName()
        if (u === "") {
            msg = "No user to log in as"
            msgIsError = true
            return
        }
        if (pwField.text === "") {
            msg = "Please enter a password"
            msgIsError = true
            pwField.forceActiveFocus()
            return
        }
        busy = true
        msg = ""
        sddm.login(u, pwField.text, sessionIndex)
    }

    function cycleSession(dir) {
        if (!sessionModel || sessionModel.count < 2)
            return
        sessionIndex = (sessionIndex + dir + sessionModel.count) % sessionModel.count
    }

    function cycleUser(dir) {
        if (userModel.count < 2)
            return
        userIndex = (userIndex + dir + userModel.count) % userModel.count
        pwField.text = ""
        msg = ""
        pwField.forceActiveFocus()
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    TextConstants { id: textConstants }

    Connections {
        target: sddm
        function onLoginSucceeded() {
            busy = false
            msg = ""
        }
        function onLoginFailed() {
            busy = false
            pwField.text = ""
            pwField.enabled = true
            msg = textConstants.loginFailed + " — try again"
            msgIsError = true
            failShake.restart()
            pwField.forceActiveFocus()
        }
        function onInformationMessage(message) {
            if (message && message !== "") {
                msg = message
                msgIsError = false
            }
        }
    }

    Component.onCompleted: {
        // Prefer the uwsm-managed Hyprland session when present so a fresh
        // boot lands in the right place even before "remember last" kicks in.
        if (sessionModel && sessionModel.count > 0) {
            var want = sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
            var fname = function (i) {
                try { return String(sessionModel.data(sessionModel.index(i, 0), Qt.UserRole + 2)) } catch (e) { return "" }
            }
            var lname = function (i) {
                try { return String(sessionModel.data(sessionModel.index(i, 0), Qt.UserRole + 4)).toLowerCase() } catch (e2) { return "" }
            }
            for (var i = 0; i < sessionModel.count; i++) {
                if (fname(i).indexOf("uwsm") !== -1 || lname(i).indexOf("uwsm") !== -1) {
                    want = i
                    break
                }
            }
            // Fall back to any hyprland entry if no uwsm flavour exists.
            if (want === (sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0)) {
                for (var j = 0; j < sessionModel.count; j++) {
                    if (lname(j).indexOf("hyprland") !== -1) {
                        want = j
                        break
                    }
                }
            }
            sessionIndex = want
        }
        if (userModel && userModel.count > 0)
            userIndex = userModel.lastIndex >= 0 ? userModel.lastIndex : 0
        msg = root.hintInitial
        msgIsError = false
        pwField.forceActiveFocus()
    }

    // ── Background ──────────────────────────────────────────────
    Image {
        id: bg
        anchors.fill: parent
        source: root.bgSource
        fillMode: Image.PreserveAspectCrop
        smooth: true
        asynchronous: true
        onStatusChanged: {
            // Absolute-path configs from another machine break silently;
            // fall back to the bundled wallpaper instead of black.
            if (status === Image.Error && source != "wallpaper.jpg")
                source = "wallpaper.jpg"
        }
    }
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, root.dimOverlay)
    }

    // Clicking empty space focuses the password field (macOS behaviour:
    // any key starts typing the password).
    MouseArea {
        anchors.fill: parent
        onClicked: pwField.forceActiveFocus()
    }

    // ── Clock, top centre (like the reference) ──────────────────
    Column {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Math.max(36, parent.height * 0.055)
        spacing: 2

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(root.now, root.dateFmt)
            color: "#f2f7ff"
            font.family: root.fontFamily
            font.pixelSize: 22
            font.weight: Font.Medium
            style: Text.Raised
            styleColor: "#60000000"
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(root.now, root.timeFmt)
            color: "#eef4ff"
            font.family: root.fontFamily
            font.pixelSize: 104
            font.weight: Font.DemiBold
            style: Text.Raised
            styleColor: "#60000000"
        }
    }

    // ── Status row, top right ───────────────────────────────────
    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 14
        anchors.rightMargin: 18
        spacing: 16

        Text {
            visible: keyboard && keyboard.enabled && keyboard.layouts && keyboard.layouts.length > 1
            text: keyboard ? keyboard.currentLayout : ""
            color: "white"
            opacity: 0.92
            font.family: root.fontFamily
            font.pixelSize: 13
            anchors.verticalCenter: parent.verticalCenter
            style: Text.Raised
            styleColor: "#60000000"
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (keyboard) {
                        var i = keyboard.currentLayoutIndex + 1
                        if (i >= keyboard.layouts.length)
                            i = 0
                        keyboard.currentLayoutIndex = i
                    }
                }
            }
        }

        Text {
            id: sessionLabel
            visible: sessionModel && sessionModel.count > 1
            text: sessionName(root.sessionIndex)
            color: "white"
            opacity: 0.85
            font.family: root.fontFamily
            font.pixelSize: 13
            anchors.verticalCenter: parent.verticalCenter
            style: Text.Raised
            styleColor: "#60000000"
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: cycleSession(1)
            }
        }

        Text {
            text: "Restart"
            color: "white"
            opacity: 0.92
            font.family: root.fontFamily
            font.pixelSize: 13
            anchors.verticalCenter: parent.verticalCenter
            visible: sddm.canReboot
            style: Text.Raised
            styleColor: "#60000000"
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: sddm.reboot()
            }
        }
        Text {
            text: "Shut Down"
            color: "white"
            opacity: 0.92
            font.family: root.fontFamily
            font.pixelSize: 13
            anchors.verticalCenter: parent.verticalCenter
            visible: sddm.canPowerOff
            style: Text.Raised
            styleColor: "#60000000"
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: sddm.powerOff()
            }
        }
    }

    // ── User block, bottom centre ───────────────────────────────
    Column {
        id: userBlock
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: Math.max(48, parent.height * 0.07)
        spacing: 8

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            Text {
                visible: userModel.count > 1
                text: "‹"
                color: "white"
                opacity: 0.8
                font.pixelSize: 28
                anchors.verticalCenter: parent.verticalCenter
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: cycleUser(-1)
                }
            }

            // Circular avatar without GraphicalEffects (unavailable on a
            // minimal install): a rounded disk clipping the photo.
            Rectangle {
                id: avatarDisk
                width: 56
                height: 56
                radius: 28
                clip: true
                color: "#59535c6b"
                border.color: "#8cffffff"
                border.width: 1
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    anchors.fill: parent
                    source: userIcon(root.userIndex)
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    asynchronous: true
                    onStatusChanged: {
                        if (status === Image.Error && source != "avatar.jpg")
                            source = "avatar.jpg"
                    }
                }
            }

            Text {
                visible: userModel.count > 1
                text: "›"
                color: "white"
                opacity: 0.8
                font.pixelSize: 28
                anchors.verticalCenter: parent.verticalCenter
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: cycleUser(1)
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: userModel.count > 0 ? userRealName(root.userIndex) : (userModel.lastUser || "user")
            color: "#f4f7ff"
            font.family: root.fontFamily
            font.pixelSize: 15
            font.weight: Font.Medium
            style: Text.Raised
            styleColor: "#60000000"
        }

        // Password pill. Frosted-glass look like the reference: a translucent
        // white disk behind the dots, brighter rim while typing, red rim on
        // a failed attempt. No GraphicalEffects dependency — plain alpha.
        Item {
            id: pwWrap
            width: 220
            height: 38
            anchors.horizontalCenter: parent.horizontalCenter

            SequentialAnimation {
                id: failShake
                NumberAnimation { target: pwWrap; property: "x"; from: 0; to: -12; duration: 60 }
                NumberAnimation { target: pwWrap; property: "x"; from: -12; to: 12; duration: 60 }
                NumberAnimation { target: pwWrap; property: "x"; from: 12; to: -6; duration: 60 }
                NumberAnimation { target: pwWrap; property: "x"; from: -6; to: 0; duration: 60 }
            }

            Rectangle {
                id: pwGlass
                anchors.fill: parent
                radius: height / 2
                color: pwField.activeFocus ? Qt.rgba(1, 1, 1, 0.32) : Qt.rgba(1, 1, 1, 0.2)
                border.width: 1
                border.color: root.msgIsError ? Qt.rgba(0.85, 0.3, 0.28, 0.95)
                             : pwField.activeFocus ? Qt.rgba(1, 1, 1, 0.85)
                             : Qt.rgba(1, 1, 1, 0.5)
                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }
            }
            // Faint inner top highlight for the frosted edge.
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: height / 2
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.12)
            }

            TextField {
                id: pwField
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                placeholderText: ""
                echoMode: TextInput.Password
                passwordCharacter: "●"
                font.family: root.fontFamily
                font.pixelSize: 16
                font.letterSpacing: 3
                horizontalAlignment: TextInput.AlignHCenter
                verticalAlignment: TextInput.AlignVCenter
                color: "#26292f"
                placeholderTextColor: "#00000000"
                focus: true
                enabled: !root.busy
                selectByMouse: false
                background: Rectangle {
                    color: "transparent"
                    border.width: 0
                }
                onAccepted: doLogin()
                Keys.onUpPressed: cycleUser(-1)
                Keys.onDownPressed: cycleUser(1)
                Component.onCompleted: forceActiveFocus()
            }

            // Spinner while PAM verifies.
            Text {
                visible: root.busy
                anchors.right: parent.right
                anchors.rightMargin: -28
                anchors.verticalCenter: parent.verticalCenter
                text: "◌"
                color: "#dfe8ff"
                opacity: 0.9
                font.pixelSize: 18
                RotationAnimation on rotation {
                    running: root.busy
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: 900
                }
            }
        }

        Text {
            id: msgLine
            anchors.horizontalCenter: parent.horizontalCenter
            width: 420
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.msg
            color: root.msgIsError ? "#ffd9d2" : "#e6ecf7"
            opacity: root.msgIsError ? 0.95 : 0.75
            font.family: root.fontFamily
            font.pixelSize: 13
            style: Text.Raised
            styleColor: "#60000000"
            visible: text !== ""
        }

        Text {
            visible: keyboard && keyboard.capsLock
            anchors.horizontalCenter: parent.horizontalCenter
            text: textConstants.capslockWarning
            color: "#ffe9a8"
            font.family: root.fontFamily
            font.pixelSize: 12
            style: Text.Raised
            styleColor: "#60000000"
        }
    }

    // ── Session footnote, bottom left (subtle, still reachable) ─
    Row {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 18
        anchors.bottomMargin: 14
        spacing: 8
        opacity: 0.75
        visible: sessionModel && sessionModel.count > 0

        Text {
            text: "Session:"
            color: "white"
            font.family: root.fontFamily
            font.pixelSize: 12
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: sessionName(root.sessionIndex)
            color: "white"
            font.family: root.fontFamily
            font.pixelSize: 12
            font.underline: true
            anchors.verticalCenter: parent.verticalCenter
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: cycleSession(1)
            }
        }
    }

    Keys.onPressed: function (event) {
        // Any key focuses the password box, like the macOS screen where
        // typing starts immediately. Tab cycles sessions for keyboards
        // without a mouse handy.
        if (event.key === Qt.Key_Tab) {
            cycleSession(1)
            event.accepted = true
            return
        }
        if (!pwField.activeFocus && event.text !== "") {
            pwField.forceActiveFocus()
        }
    }
}
