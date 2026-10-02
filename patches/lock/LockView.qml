pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import "PhaseArt.js" as Art

// Fondasi lock screen Tsugumori untuk Omarchy. Task 2 ini hanya kontrak
// Service, token desain, background solid, field shader, dan animasi appear.
// Panel/glyph/auth menyusul di Task 3-5.
//
// import qs.Commons sengaja belum dipakai: satu-satunya consumer-nya
// Style.font.family (glyph sidik jari 󰈷, Private Use Area Nerd Font) baru
// dipakai di Task 4. qs.Commons hanya resolve kalau folder config punya
// Commons/qmldir, yang di produksi hanya ada di /usr/share/omarchy/shell —
// di harness repo ini import itu bikin quickshell gagal loadtotal.
FocusScope {
    id: view
    focus: true
    property real progress: 0

    // --- Kontrak Service.qml (wajib ada walau tak dipakai; bind ke props
    // --- yang hilang = QML throw). Wallpaper sengaja diabaikan: lock
    // --- Tsugumori = solid #080808 + shader field, tanpa wallpaper.
    property string backgroundPath: ""
    property int backgroundVersion: 0
    property bool fingerprintConfigured: false
    property bool authenticatingPassword: false
    property string failureMessage: ""
    property int failedAttempts: 0
    property bool inputEnabled: true
    property bool loadBackground: true
    property string passwordText: ""
    // LockView Omarchy asli punya ini; di sana diisi internal saat password
    // diisi programatis (guard loop passwordText <-> passwordTextEdited).
    // Belum dipakai di Task 2, tapi dideklarasikan supaya port ini drop-in
    // kalau versi OmarchyWEI mengikatnya dari Service.
    property bool syncingPasswordText: false

    // --- Kontrak Service.qml untuk footer power ---
    property bool powerBusy: false
    property string powerError: ""
    // Declarasi kontrak saja. Service.qml mengirim `root.sessionLock.secure`
    // ke sini, tapi child-object id TIDAK terjangkau lewat `root.` di config
    // Quickshell (dibuktikan: `ReferenceError: lockView is not defined` dari
    // scope root), jadi nilainya selalu false. Karena itu powerEnabled TIDAK
    // dipakai sebagai gate — lihat `enabled:` di PowerButton.
    property bool powerEnabled: false
    // Dead properties, dipertahankan hanya agar Service.qml tetap drop-in
    // (menghapus deklarasi bikinQML throw "no such property").
    // ponytail: hapus bersama baris binding di Service.qml saat file itu
    // masuk daftar restore hook.
    property bool sessionSecure: false

    // --- Internal, diturunkan dari kontrak ---
    property int glyphLength: passwordText.length
    // Gate input HANYA ikut stock Omarchy: inputEnabled (yang sudah ter-bind ke
    // root.lockRequested) + bukan sedang auth + bukan sedang power confirm.
    readonly property bool inputReady: inputEnabled
    readonly property bool pending: authenticatingPassword
    readonly property bool error: failureMessage.length > 0
    readonly property bool controlsReady: inputReady && !pending && !powerBusy
    property date now: new Date()
    property string powerConfirmation: ""
    property bool shaderFailed: false
    property real glyphPhase: 0

    signal submitPassword(string password)
    signal passwordTextEdited(string password)
    signal clearFailureRequested()
    signal wakeRequested()
    signal powerRequested(string action)

    // Password dua arah tanpa round-trip: field membaca passwordText, user
    // ketik -> emit -> Service -> binding balik. QML hanya memicu
    // onTextEdited untuk edit user, jadi tidak ada loop.
    onPasswordTextChanged: if (passwordText.length > 0 && error) clearFailureRequested()

    // Jam: Tsugumori punya Timer ini di parent-nya; di sini view yang memiliki.
    Timer {
        interval: 1000; repeat: true; running: true; triggeredOnStart: true
        onTriggered: view.now = new Date()
    }

    // --- Token: baris 28-49 PhaseLockView.qml, dengan penyesuaian yang
    // --- dijelaskannya di task brief.
    readonly property string userName: Quickshell.env("USER")
    readonly property bool gpuRendering: GraphicsInfo.api !== GraphicsInfo.Software && !shaderFailed
    readonly property bool compact: width < 540
    readonly property real dpr: Math.max(1, Screen.devicePixelRatio)
    readonly property var phase: Art.componentState(progress)
    readonly property bool transitioning: progress > 0 && progress < 1
    // Cabang hiding dihapus: Task 2 tidak punya state hiding sama sekali.
    readonly property string lockLabel: progress < 1 ? (compact ? "REGISTER" : "LOCK / APPEAR") : "LOCKED"
    readonly property color red: "#d1161c"
    readonly property color ivory: "#e4e2dc"
    readonly property color grey: "#99958c"
    readonly property string mono: "JetBrains Mono"
    readonly property real panelWidth: Math.min(408, Math.max(240, width - 32))
    // Rumus identik PhaseLockView.qml:42. Urutan penting: panelHeight <-
    // login (ukuran natural), lalu panelScale <- panelHeight (skala).
    // Kalau dibalik jadi panelHeight <- panelScale, itu binding loop.
    readonly property real panelHeight: login.implicitHeight + login.contentInset * 2 + 2
    // Another 15% above the previous 1.15 scale; retain the small-display fit guard.
    readonly property real panelScale: Math.min(1.15 * 1.15,
        Math.max(1, width - 32) / panelWidth,
        Math.max(1, height - 32) / panelHeight)
    readonly property int folioWidth: compact ? 64 : 106

    // --- Fungsi kontrak (menggantikan PhaseLockView.qml:51-93) ---
    // Retry ala stock: callLater + dipanggil ulang saat state berubah.
    // Sekali tembak saja tidak cukup — window/animasi belum siap saat onCompleted.
    function focusPassword() {
        if (inputEnabled && !pending && !powerBusy) passwordInput.forceActiveFocus();
    }
    onInputEnabledChanged: if (inputEnabled) Qt.callLater(focusPassword)
    onPowerBusyChanged: if (inputEnabled) Qt.callLater(focusPassword)
    onPendingChanged: if (inputEnabled) Qt.callLater(focusPassword)
    function choosePower(action) {
        // Hanya controlsReady. Gate powerEnabled dihapus karena nilainya selalu
        // false (binding `root.sessionLock.secure` tidak sampai ke LockView), dan
        // selama masih ada gate itu setiap klik jadi no-op senyap.
        // Guard sesungguhnya tetap di Service.qml requestPower(): `!sessionLock.secure`
        // ditolak + powerError ditampilkan, dicek ulang tiap klik.
        if (!controlsReady) return;
        if (action !== "reboot" && action !== "poweroff") return;
        if (powerConfirmation === action) {
            powerConfirmation = "";
            powerRequested(action);
        } else if (powerConfirmation !== "") {
            powerConfirmation = "";
            focusPassword();
        } else {
            powerConfirmation = action;
        }
    }
    function cancelPower() {
        powerConfirmation = "";
        focusPassword();
    }
    // Dipisah dari UI supaya bisa diuji tanpa simulasi keyboard, dan dipakai
    // bersama oleh TextInput.onAccepted dan tombol unlock.
    function submit() {
        if (!controlsReady) return;
        cancelPower();
        var submitted = passwordText;
        passwordTextEdited("");
        if (submitted.length > 0) submitPassword(submitted);
    }
    function clear() {
        if (powerConfirmation !== "") { cancelPower(); return }
        passwordTextEdited("");
        clearFailureRequested();
    }
    function useCpuFallback(description) {
        if (shaderFailed) return;
        console.error("Tsugumori: GPU artwork unavailable; using static artwork fallback:", description);
        shaderFailed = true;
    }
    function animateGlyph() {
        glyphAnimation.stop();
        var target = Math.min(64, Math.max(0, glyphLength));
        glyphAnimation.from = glyphPhase;
        glyphAnimation.to = target;
        glyphAnimation.duration = Math.min(700, 100 * Math.max(1, Math.sqrt(Math.abs(target - glyphPhase))));
        glyphAnimation.start();
    }
    onGlyphLengthChanged: animateGlyph()
    onControlsReadyChanged: {
        if (!controlsReady) powerConfirmation = "";
        focusPassword();
    }
    Keys.onEscapePressed: function(event) { view.clear(); event.accepted = true }
    Keys.onPressed: function(event) {
        wakeRequested();
        // Ctrl+U ikut disimpan: perilaku Omarchy yang sudah ada.
        if (event.key === Qt.Key_U && (event.modifiers & Qt.ControlModifier)) {
            clear(); event.accepted = true;
        }
    }

    // Appear 1450ms. Preview lock (inputEnabled false) melompat ke state final
    // supaya settings preview tidak nunggu animasi.
    NumberAnimation {
        id: progressAnimation
        target: view
        property: "progress"
        from: 0; to: 1
        duration: 1450
        easing.type: Easing.Linear
    }
    NumberAnimation {
        id: glyphAnimation
        target: view
        property: "glyphPhase"
        easing.type: Easing.OutCubic
    }
    // Beberapa compositor memfokuskan surface baru setelah input siap.
    Timer {
        property int attempts: 0
        interval: 50
        repeat: true
        running: view.controlsReady && view.powerConfirmation === "" && attempts < 8
        onTriggered: { attempts++; view.focusPassword(); }
    }
    Component.onCompleted: {
        glyphPhase = Math.min(64, glyphLength);
        if (inputEnabled) progressAnimation.start(); else progress = 1;
        focusPassword();
    }

    // --- PhaseLockView.qml:110-151 verbatim ---
    Rectangle { anchors.fill: parent; color: "#080808" }
    Item {
        id: field
        objectName: "phaseField"
        anchors.fill: parent
        readonly property int columns: Math.ceil(width / 84)
        readonly property int rows: Math.ceil(height / 84)
        readonly property int batches: Math.ceil(columns / 32)
        readonly property PhaseCpuFallback cpuRenderer: cpuField.item as PhaseCpuFallback
        readonly property int paintCount: cpuRenderer ? cpuRenderer.paintCount : 0
        Loader {
            anchors.fill: parent
            active: view.gpuRendering
            sourceComponent: Item {
                Repeater {
                    model: field.rows * field.batches
                    PhaseLines {
                        required property int index
                        width: field.width; height: 84
                        y: (field.height - field.rows * 84) / 2 + rowIndex * 84
                        rowIndex: Math.floor(index / field.batches)
                        firstColumn: (index % field.batches) * 32
                        batchColumns: Math.min(32, field.columns - firstColumn)
                        rootColumns: field.columns
                        glyphMode: 0
                        progress: view.progress
                        glyphCount: 0
                        pixelRatio: view.dpr
                        pixelOrigin: Qt.point(0, y)
                        onRenderFailed: description => view.useCpuFallback(description)
                    }
                }
            }
        }
        Loader {
            id: cpuField
            anchors.fill: parent
            active: !view.gpuRendering
            opacity: view.phase.back
            sourceComponent: PhaseCpuFallback { pixelRatio: view.dpr }
        }
    }

    Item {
        id: panel
        objectName: "loginPanel"
        width: view.panelWidth
        height: view.panelHeight
        scale: view.panelScale
        transformOrigin: Item.Center
        x: Math.round((view.width - width) / 2)
        y: Math.round((view.height - height) / 2)
        Rectangle { anchors.fill: parent; color: "#090909"; opacity: view.phase.back }
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 1
            border.color: "#49423a"
            opacity: view.phase.border
        }
        Rectangle {
            x: 1; y: 1
            width: view.folioWidth; height: parent.height - 2
            color: view.red; opacity: view.phase.folio
        }
        Item {
            x: 1; y: 1; width: view.folioWidth; height: parent.height - 2
            opacity: view.phase.folioText
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: view.compact ? 35 : 20
                rotation: view.compact ? 90 : 0
                text: "TYPE-17"
                color: "#170b0a"
                font { family: view.mono; pixelSize: 11; weight: Font.Medium; letterSpacing: 1 }
                renderType: Text.CurveRendering
            }
            Column {
                anchors.centerIn: parent
                Repeater {
                    model: ["継", "衛"]
                    Text {
                        required property string modelData
                        text: modelData
                        color: "#170b0a"
                        height: font.pixelSize * 1.08
                        font { family: "Noto Sans CJK JP"; pixelSize: view.compact ? 43 : 68; weight: Font.Medium }
                        renderType: Text.CurveRendering
                    }
                }
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height - (view.compact ? 68 : 43)
                width: folioLabel.implicitWidth + 14; height: 23
                color: "#190a09"
                rotation: view.compact ? 90 : 0
                Text {
                    id: folioLabel
                    anchors.centerIn: parent
                    text: "SID0NIA"
                    color: view.red
                    font { family: view.mono; pixelSize: 11; weight: Font.Medium; letterSpacing: 1 }
                    renderType: Text.CurveRendering
                }
            }
        }

        Column {
            id: login
            objectName: "login"
            property int contentInset: view.compact ? 14 : 20
            x: view.folioWidth + 1 + contentInset; y: 1 + contentInset
            width: panel.width - view.folioWidth - 2 - contentInset * 2
            spacing: view.compact ? 16 : 18
            Column {
                width: parent.width
                spacing: 9
                opacity: view.phase.user
                Item {
                    width: parent.width; height: 21
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "USER <font color='#d1161c'>//</font>"
                        textFormat: Text.StyledText
                        color: view.grey
                        font { family: view.mono; pixelSize: 11; letterSpacing: 1 }
                        renderType: Text.CurveRendering
                    }
                    Rectangle {
                        anchors.right: parent.right
                        width: 53; height: 21; color: view.red
                        Text {
                            anchors.centerIn: parent
                            text: "◆ 704"; color: "#090909"
                            font { family: view.mono; pixelSize: 11; weight: Font.Medium }
                            renderType: Text.CurveRendering
                        }
                    }
                }
                Text {
                    objectName: "userLabel"
                    width: parent.width
                    text: view.userName.toUpperCase()
                    textFormat: Text.PlainText
                    wrapMode: Text.WrapAnywhere
                    color: view.ivory
                    font { family: view.mono; pixelSize: view.compact ? 14 : 17; weight: Font.Medium; letterSpacing: view.compact ? .1 : .7 }
                    renderType: Text.CurveRendering
                }
            }

            Item {
                id: clockStrip
                objectName: "clockStrip"
                width: parent.width
                readonly property bool stacked: clock.implicitWidth + dateColumn.width + 12 > width
                height: (stacked ? clock.height + dateColumn.height + 8 : Math.max(clock.height, dateColumn.height)) + 15
                opacity: view.phase.clock
                Text {
                    id: clock
                    text: Qt.formatDateTime(view.now, "HH") + "<font color='#d1161c'>:</font>" + Qt.formatDateTime(view.now, "mm")
                    textFormat: Text.StyledText
                    color: view.ivory
                    font { family: view.mono; pixelSize: view.compact ? 30 : 32; letterSpacing: -1 }
                    renderType: Text.CurveRendering
                }
                Column {
                    id: dateColumn
                    x: clockStrip.stacked ? 0 : parent.width - width
                    y: clockStrip.stacked ? clock.height + 8 : 0
                    width: Math.max(dayLabel.implicitWidth, yearLabel.implicitWidth)
                    spacing: 3
                    Text {
                        id: dayLabel
                        text: Qt.formatDateTime(view.now, "dd MMM").toUpperCase()
                        color: view.ivory
                        font { family: view.mono; pixelSize: 11 }
                        renderType: Text.CurveRendering
                    }
                    Text {
                        id: yearLabel
                        text: Qt.formatDateTime(view.now, "ddd").toUpperCase() + " <font color='#d1161c'>//</font> " + Qt.formatDateTime(view.now, "yyyy")
                        textFormat: Text.StyledText
                        color: view.grey
                        font { family: view.mono; pixelSize: 11 }
                        renderType: Text.CurveRendering
                    }
                }
                Rectangle {
                    x: dateColumn.x - 12; y: dateColumn.y
                    width: 1; height: dateColumn.height
                    color: "#3b3631"; visible: !view.compact && !clockStrip.stacked
                }
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#3b3631" }
            }

            Item {
                id: glyph
                objectName: "compoundGlyph"
                width: Math.min(parent.width, 162); height: width
                x: Math.round((parent.width - width) / 2)
                readonly property point renderOrigin: Qt.point(
                    panel.x + (1 - view.panelScale) * panel.width / 2 + (login.x + x) * view.panelScale,
                    panel.y + (1 - view.panelScale) * panel.height / 2 + (login.y + y) * view.panelScale)
                Loader {
                    anchors.fill: parent
                    active: view.gpuRendering
                    sourceComponent: PhaseLines {
                        glyphMode: 1
                        rootColumns: 3
                        progress: view.progress
                        glyphCount: view.glyphPhase
                        pixelRatio: view.dpr * view.panelScale
                        pixelOrigin: Qt.point(glyph.renderOrigin.x / view.panelScale, glyph.renderOrigin.y / view.panelScale)
                        onRenderFailed: description => view.useCpuFallback(description)
                    }
                }
                Loader {
                    anchors.fill: parent
                    active: !view.gpuRendering
                    opacity: view.phase.glyph
                    sourceComponent: PhaseCpuFallback {
                        isGlyph: true; glyphCount: view.glyphPhase; pixelRatio: view.dpr * view.panelScale
                    }
                }
            }

            // --- PhaseLockView.qml:336-462 verbatim, dengan 4 adaptasi Omarchy ---
            Column {
                width: parent.width; spacing: 9
                opacity: view.phase.auth
                Item {
                    width: parent.width; height: 15
                    Text {
                        text: "PASSWORD <font color='#d1161c'>//</font>"
                        textFormat: Text.StyledText
                        color: view.grey
                        font { family: view.mono; pixelSize: 11; letterSpacing: .7 }
                        renderType: Text.CurveRendering
                    }
                    // (4) Ganti Text 認証: hint sidik jari hanya tampil kalau
                    // sensor terdaftar, dan family-nya token view.mono — bukan
                    // Style.font.family (qs.Commons tidak resolve di luar shell).
                    Text {
                        objectName: "fingerprintIndicator"
                        anchors.right: parent.right
                        text: view.fingerprintConfigured ? "󰈷" : "認証"
                        color: view.grey
                        font {
                            family: view.fingerprintConfigured ? view.mono : "Noto Sans CJK JP"
                            pixelSize: 11
                        }
                        renderType: Text.CurveRendering
                    }
                }
                Rectangle {
                    objectName: "passwordRow"
                    width: parent.width; height: 44
                    color: "#111111"; border.width: 1; border.color: "#55504a"
                    Rectangle {
                        width: 2; height: parent.height
                        color: passwordInput.activeFocus ? "#ed272d" : view.red
                    }
                    TextInput {
                        id: passwordInput
                        objectName: "passwordInput"
                        x: 12; y: 1; width: parent.width - 65; height: parent.height - 2
                        // (1a) Sumber mengikat ke view.password; di Omarchy
                        // Service owns the text (passwordText <-> passwordTextEdited).
                        text: view.passwordText
                        echoMode: TextInput.Password
                        passwordCharacter: "•"
                        passwordMaskDelay: 0
                        selectByMouse: true
                        clip: true
                        color: view.ivory
                        selectionColor: "#751418"
                        selectedTextColor: view.ivory
                        verticalAlignment: TextInput.AlignVCenter
                        font { family: view.mono; pixelSize: 16; letterSpacing: 2 }
                        renderType: Text.CurveRendering
                        inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                        enabled: view.controlsReady
                        activeFocusOnTab: true
                        focus: true
                        cursorDelegate: Rectangle { width: 2; color: view.red; visible: passwordInput.activeFocus }
                        Accessible.name: "Password"
                        Accessible.role: Accessible.EditableText
                        // (1a) Ketik = wake. Perilaku LockView Omarchy asli.
                        onTextEdited: { view.passwordTextEdited(text); view.wakeRequested() }
                        onAccepted: view.submit()
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Escape) { view.clear(); event.accepted = true }
                            else if (event.key === Qt.Key_U && (event.modifiers & Qt.ControlModifier)) {
                                view.clear(); event.accepted = true;
                            }
                        }
                    }
                    Text {
                        x: 12; anchors.verticalCenter: parent.verticalCenter
                        visible: passwordInput.text.length === 0
                        text: "Enter password…"; color: view.grey
                        font { family: view.mono; pixelSize: 11 }
                        renderType: Text.CurveRendering
                    }
                    Button {
                        id: submitButton
                        objectName: "unlockButton"
                        anchors { right: parent.right; top: parent.top; bottom: parent.bottom; margins: 1 }
                        width: 42; padding: 0
                        enabled: view.controlsReady
                        Accessible.name: "Unlock"
                        background: Rectangle { color: submitButton.hovered || submitButton.visualFocus ? "#e7282e" : view.red }
                        contentItem: Text {
                            text: "↗"; color: "#090909"
                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            font { family: view.mono; pixelSize: 20 }
                            renderType: Text.CurveRendering
                        }
                        // (1b) Sumber: view.cancelPower(); view.submitted().
                        // Omarchy: submit() sudah memanggil cancelPower() di
                        // dalamnya, dan signal-nya submitPassword.
                        onClicked: view.submit()
                    }
                }
                // (1c) Cabang "hiding" dihapus (tidak ada state-nya di Omarchy),
                // dan pesan Service dirender apa adanya — failureMessage sudah
                // memuat counter percobaan, jadi failedAttempts tak dirender
                // sendiri supaya tidak dobel.
                Text {
                    objectName: "authStatus"
                    width: parent.width
                    height: Math.max(15, implicitHeight)
                    text: view.powerBusy ? "POWER REQUEST PENDING…" : view.powerError !== "" ? view.powerError
                        : view.error ? view.failureMessage : view.pending ? "AUTHENTICATING…"
                        : "SESSION LOCKED"
                    wrapMode: Text.Wrap
                    color: view.error || (view.powerError !== "" && !view.powerBusy) ? view.red : view.grey
                    font { family: view.mono; pixelSize: 11 }
                    renderType: Text.CurveRendering
                    Accessible.role: Accessible.StaticText
                }
                Item {
                    objectName: "powerFooter"
                    width: parent.width; height: 44
                    Rectangle {
                        width: parent.width; height: 1
                        color: "#3b3631"
                    }
                    Row {
                        objectName: "powerControls"
                        anchors { right: parent.right; bottom: parent.bottom }
                        width: Math.min(180, parent.width); height: 26; spacing: 10
                        PowerButton {
                            objectName: "restartButton"
                            width: (parent.width - parent.spacing) / 2; height: parent.height
                            text: view.powerConfirmation === "reboot" ? "RESTART?"
                                : view.powerConfirmation !== "" ? "CANCEL" : "RESTART"
                            Accessible.name: view.powerConfirmation === "reboot" ? "Confirm restart"
                                : view.powerConfirmation !== "" ? "Cancel shutdown" : "Restart"
                            onClicked: view.choosePower("reboot")
                        }
                        PowerButton {
                            objectName: "shutdownButton"
                            width: (parent.width - parent.spacing) / 2; height: parent.height
                            text: view.powerConfirmation === "poweroff" ? "SHUT DOWN?"
                                : view.powerConfirmation !== "" ? "CANCEL" : "SHUT DOWN"
                            Accessible.name: view.powerConfirmation === "poweroff" ? "Confirm shutdown"
                                : view.powerConfirmation !== "" ? "Cancel restart" : "Shut down"
                            onClicked: view.choosePower("poweroff")
                        }
                    }
                }
            }
        }
    }

    // --- PhaseLockView.qml:466-524 verbatim, kecuali enabled di (1d) ---
    component PowerButton: Button {
        id: button
        // Match MenuFooterButton without adding shell/theme dependencies to the lock.
        readonly property bool interactionActive: enabled && (hovered || down || activeFocus)
        property real fillProgress: interactionActive ? 1 : 0
        padding: 0
        // Gate cukup controlsReady. Gate secure TIDAK diulang di sini karena
        // powerEnabled selalu false (binding `root.sessionLock.secure` tidak
        // sampai ke LockView) — dulu akibatnya tombol mati permanen.
        // Guard sesungguhnya ada di Service.qml requestPower(): `if (!sessionLock.secure)`
        // menolak dan menampilkan powerError, jadi tidak ada jalur destructive
        // yang lolos. Gate di sini cuma tampilan, guard di sana yang menentukan.
        enabled: view.controlsReady
        focusPolicy: Qt.StrongFocus
        hoverEnabled: true
        opacity: enabled ? 1 : .45
        Behavior on fillProgress {
            NumberAnimation {
                duration: 220
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.76, 0, 0.24, 1, 1, 1]
            }
        }
        HoverHandler { cursorShape: button.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
        background: Item {
            Rectangle {
                x: 2; y: 2
                width: Math.max(0, parent.width - 4) * button.fillProgress
                height: Math.max(0, parent.height - 4)
                color: view.red
            }
            Repeater {
                model: 4
                Item {
                    id: corner
                    required property int index
                    readonly property bool rightEdge: index % 2 === 1
                    readonly property bool bottomEdge: index >= 2
                    width: 6; height: 6
                    x: rightEdge ? parent.width - width : 0
                    y: bottomEdge ? parent.height - height : 0
                    opacity: button.interactionActive ? 1 : .6
                    Rectangle {
                        width: parent.width; height: 1
                        y: corner.bottomEdge ? parent.height - height : 0
                        color: view.red
                    }
                    Rectangle {
                        width: 1; height: parent.height
                        x: corner.rightEdge ? parent.width - width : 0
                        color: view.red
                    }
                }
            }
        }
        contentItem: Text {
            text: button.text
            textFormat: Text.PlainText
            color: button.interactionActive ? "#090909" : "#b0aba6"
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            font { family: view.mono; pixelSize: 10; letterSpacing: 1.3 }
            renderType: Text.CurveRendering
            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }

    // --- PhaseLockView.qml:526-583 verbatim (live: tanpa !view.hiding) ---
    Item {
        id: registration
        objectName: "panelRegistration"
        x: panel.x; y: panel.y
        width: panel.width; height: panel.height
        scale: view.panelScale
        transformOrigin: Item.Center
        visible: view.transitioning
        opacity: Art.ramp(view.progress, .06, .17) * (1 - Art.ramp(view.progress, .78, .97))
        Repeater {
            model: 38
            Rectangle {
                required property int index
                readonly property real tickHeight: Art.lerp(7, 1, view.phase.border)
                x: ((index % 19) + .5) * registration.width / 19
                y: (index < 19 ? 0 : registration.height) - tickHeight
                width: 1 / view.dpr; height: tickHeight * 2
                color: index < 19 && index % 6 === 0 ? "#b91a20" : "#999486"
                opacity: index < 19 ? .7 : .45
            }
        }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 1; strokeColor: "#b91a20"; fillColor: "transparent"
                PathSvg { path: "M0,32 V0 H32 M" + (registration.width - 32) + "," + registration.height
                    + " H" + registration.width + " V" + (registration.height - 32) }
            }
            ShapePath {
                strokeWidth: 1; strokeColor: "#999486"; fillColor: "transparent"
                PathSvg { path: "M" + (registration.width - 32) + ",0 H" + registration.width
                    + " V32 M0," + (registration.height - 32) + " V" + registration.height + " H32" }
            }
        }
        Rectangle {
            x: view.folioWidth; width: 1 / view.dpr
            height: parent.height * Art.ramp(view.progress, .18, .61)
            color: "#b91a20"; opacity: .6
        }
    }

    Repeater {
        model: 4
        FormationCorner {
            objectName: "formationCorner" + index
            readonly property real inset: view.compact ? 14 : 20
            compact: view.compact
            live: view.progress === 1
            span: Math.min(244, (view.width - inset * 2 - 20) / 2)
            label: view.lockLabel
            x: index % 2 ? view.width - inset - span - 5 : inset - 5
            y: index < 2 ? 11 : view.height - 61
            width: span + 10; height: 50
            opacity: Art.ramp(view.progress, .28, .74)
            visible: view.height >= view.panelHeight * view.panelScale + 116
        }
    }
}
