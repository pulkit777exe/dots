import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import SddmComponents 2.0

// Sequoia — macOS login for SDDM. Menu bar with clock on top,
// centred avatar + name + frosted password field with arrow button,
// power buttons at the bottom. No session picker, no big clock —
// the real login has neither.
// Auth path is deliberately boring: sddm.login(user, password, sessionIndex)
// with lastUser/lastSession defaults, failed logins clear + refocus.
Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "black"

    property string fontFamily: config.stringValue("fontFamily") || "SF Pro Display"
    property string bgSource: config.stringValue("background") || "wallpaper.jpg"
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
        msg = ""
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

    // ── Menu bar. The macOS login has no big clock — the time lives
    // here, small, top right, exactly like the desktop menu bar. ──
    Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: 30
        color: Qt.rgba(0, 0, 0, 0.28)

        Text {
            visible: keyboard && keyboard.enabled && keyboard.layouts && keyboard.layouts.length > 1
            anchors.right: barClock.left
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: keyboard ? keyboard.currentLayout : ""
            color: "white"
            opacity: 0.9
            font.family: root.fontFamily
            font.pixelSize: 13
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
            id: barClock
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDate(root.now, "ddd d MMM") + "  " + Qt.formatTime(root.now, root.timeFmt)
            color: "white"
            opacity: 0.92
            font.family: root.fontFamily
            font.pixelSize: 13
            font.weight: Font.Medium
        }
    }

    // ── User block, centred like the macOS login ────────────────
    Column {
        id: userBlock
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -34
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 10

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

            // Circular avatar with no extra modules: Item.clip stays square
            // and ShaderEffect needs GL, so Canvas clips the photo to a
            // disk in plain 2D. The hidden Image only decodes the photo
            // and reports its natural size for the centre-crop math.
            Item {
                id: avatarDisk
                width: 84
                height: 84
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    id: facePhoto
                    source: userIcon(root.userIndex)
                    visible: false
                    asynchronous: true
                    onStatusChanged: {
                        if (status === Image.Error && source != "avatar.jpg")
                            source = "avatar.jpg"
                        else if (status === Image.Ready)
                            faceCanvas.requestPaint()
                    }
                }
                Canvas {
                    id: faceCanvas
                    anchors.fill: parent
                    property string faceUrl: facePhoto.source
                    onFaceUrlChanged: {
                        if (faceUrl !== "" && !isImageLoaded(faceUrl))
                            loadImage(faceUrl)
                        requestPaint()
                    }
                    onImageLoaded: requestPaint()
                    Component.onCompleted: {
                        if (faceUrl !== "" && !isImageLoaded(faceUrl))
                            loadImage(faceUrl)
                    }
                    onPaint: {
                        var ctx = getContext("2d")
                        var r = width / 2
                        ctx.clearRect(0, 0, width, height)
                        ctx.beginPath()
                        ctx.arc(r, r, r, 0, Math.PI * 2)
                        ctx.fillStyle = "#59535c6b"
                        ctx.fill()
                        if (faceUrl !== "" && isImageLoaded(faceUrl)
                                && facePhoto.status === Image.Ready
                                && facePhoto.implicitWidth > 0
                                && facePhoto.implicitHeight > 0) {
                            var iw = facePhoto.implicitWidth
                            var ih = facePhoto.implicitHeight
                            var s = Math.max(width / iw, height / ih)
                            var sw = width / s, sh = height / s
                            ctx.save()
                            ctx.beginPath()
                            ctx.arc(r, r, r - 1, 0, Math.PI * 2)
                            ctx.clip()
                            ctx.drawImage(faceUrl, (iw - sw) / 2, (ih - sh) / 2,
                                          sw, sh, 0, 0, width, height)
                            ctx.restore()
                        }
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: 42
                    color: "transparent"
                    border.color: "#8cffffff"
                    border.width: 1
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
            font.pixelSize: 17
            font.weight: Font.DemiBold
            style: Text.Raised
            styleColor: "#60000000"
        }

        // Password field, macOS login style: a frosted-white pill with
        // the prompt inside it and the round arrow button on the right.
        // No GraphicalEffects dependency — plain alpha.
        Item {
            id: pwWrap
            width: 200
            height: 32
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
                color: pwField.activeFocus ? Qt.rgba(1, 1, 1, 0.72) : Qt.rgba(1, 1, 1, 0.55)
                border.width: 1
                border.color: root.msgIsError ? Qt.rgba(0.85, 0.3, 0.28, 0.95)
                             : Qt.rgba(0, 0, 0, 0.18)
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
                anchors.leftMargin: 14
                anchors.rightMargin: 40
                placeholderText: ""
                echoMode: TextInput.Password
                passwordCharacter: "●"
                font.family: root.fontFamily
                font.pixelSize: 15
                font.letterSpacing: pwField.text === "" ? 0 : 3
                horizontalAlignment: TextInput.AlignHCenter
                verticalAlignment: TextInput.AlignVCenter
                color: "#26292f"
                placeholderTextColor: "#71767e"
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

            // Prompt inside the field. A plain Text, not placeholderText:
            // under a Password echoMode the placeholder is unreliable,
            // while this shows if and only if the field is empty.
            Text {
                anchors.fill: pwField
                anchors.leftMargin: 14
                anchors.rightMargin: 40
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: "Enter Password"
                color: "#71767e"
                font.family: root.fontFamily
                font.pixelSize: 15
                visible: pwField.text === "" && !root.busy
            }

            // Round arrow button, macOS style: submits on click, shows
            // the spinner inside itself while PAM verifies.
            Rectangle {
                id: goButton
                width: 24
                height: 24
                radius: 12
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                color: goMouse.containsMouse ? Qt.rgba(28, 30, 36, 0.78)
                                             : Qt.rgba(28, 30, 36, 0.55)
                Text {
                    anchors.centerIn: parent
                    text: root.busy ? "◌" : "→"
                    color: "white"
                    font.pixelSize: 13
                    RotationAnimation on rotation {
                        running: root.busy
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 900
                    }
                }
                MouseArea {
                    id: goMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: doLogin()
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

    // ── Sleep/restart/shut down, bottom centre like macOS. The session
    // picker macOS would never show is gone entirely: the session is
    // preselected silently, Tab still cycles it for multi-boot machines.
    Row {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 22
        spacing: 30

        Text {
            text: "Restart"
            color: "white"
            opacity: 0.85
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
            opacity: 0.85
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
