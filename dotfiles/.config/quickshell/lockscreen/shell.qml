import QtQuick
import Quickshell
import Quickshell.Services.Pam
import Quickshell.Wayland
import Quickshell.Io
import QtQuick.Effects
import "../config" as Config

ShellRoot {
    id: root
    
    readonly property int u: 16

    // reducedMotion 时：粒子静止、禁用进场与交互动画
    readonly property bool reducedMotion: (Quickshell.env("QUICKSHELL_REDUCE_MOTION") || "").toLowerCase() === "1"
        || (Quickshell.env("QUICKSHELL_REDUCE_MOTION") || "").toLowerCase() === "true"
        || (Quickshell.env("QUICKSHELL_REDUCE_MOTION") || "").toLowerCase() === "yes"
    
    // 动态配色：读取 matugen 输出，让锁屏跟随壁纸变化
    readonly property string colorFilePath: "file:///home/shiyi/.cache/matugen/colors.json"
    property color bgGlass: Qt.rgba(0.078, 0.078, 0.098, 0.72)
    property color accent: Config.Theme.accent
    property color accentGlow: Qt.rgba(0.953, 0.741, 0.431, 0.3)
    property color textPrimary: Config.Theme.textPrimary
    property color textSecondary: Config.Theme.textSecondary
    property color tintColor: Qt.rgba(0.1, 0.08, 0.05, 0.4)
    property color fieldBg: Qt.rgba(0, 0, 0, 0.18)
    property color buttonText: "#141414"
    property color errorColor: Config.Theme.danger
    readonly property string idleFlagUrl: "file:///home/shiyi/.local/state/quickshell/idle_enabled"
    readonly property string debugLogPath: "/home/shiyi/.local/state/quickshell/lockscreen-debug.log"
    property bool idleEnabled: true
    property bool idleToggleBusy: false
    property bool authFailed: false
    property string authStatusText: ""
    property string lastPamPromptKey: ""
    property string passwordText: ""

    function colorFromHex(hex, alpha) {
        if (!hex || typeof hex !== "string" || hex.length < 7) return Qt.rgba(1, 1, 1, alpha)
        return Qt.rgba(
            parseInt(hex.slice(1, 3), 16) / 255,
            parseInt(hex.slice(3, 5), 16) / 255,
            parseInt(hex.slice(5, 7), 16) / 255,
            alpha
        )
    }

    function contrastColor(hex) {
        if (!hex || typeof hex !== "string" || hex.length < 7) return "#141414"
        var r = parseInt(hex.slice(1, 3), 16) / 255
        var g = parseInt(hex.slice(3, 5), 16) / 255
        var b = parseInt(hex.slice(5, 7), 16) / 255
        var luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance > 0.58 ? "#141414" : "#f5f5f5"
    }

    function applyDynamicColors(fileContent) {
        if (!fileContent) return
        try {
            var data = JSON.parse(fileContent)
            if (!data.colors) return

            var colors = data.colors
            if (colors.primary) {
                root.accent = colors.primary
                root.accentGlow = root.colorFromHex(colors.primary, 0.3)
                root.buttonText = root.contrastColor(colors.primary)
            }
            if (colors.on_surface) root.textPrimary = colors.on_surface
            if (colors.outline) root.textSecondary = colors.outline
            if (colors.surface_container) root.bgGlass = root.colorFromHex(colors.surface_container, 0.76)
            if (colors.surface) {
                root.tintColor = root.colorFromHex(colors.surface, 0.4)
                root.fieldBg = root.colorFromHex(colors.surface, 0.18)
            }
        } catch (e) {
            console.log("[lockscreen] dynamic color parse failed: " + e)
        }
    }

    function parseIdleFlag(fileContent) {
        var value = (fileContent || "").trim().toLowerCase()
        root.idleEnabled = !(value === "0" || value === "false" || value === "off" || value === "disabled" || value === "no")
    }

    function resetAuthState() {
        root.authFailed = false
        root.authStatusText = ""
        root.lastPamPromptKey = ""
    }

    function appendDebugLog(message) {
        var line = Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm:ss") + " " + message
        debugLogProc.exec([
            "sh",
            "-lc",
            "printf '%s\\n' \"$1\" >> \"$2\"",
            "lockscreen-debug",
            line,
            root.debugLogPath
        ])
    }

    function hasPasswordField() {
        return typeof passwordInput !== "undefined" && passwordInput !== null
    }

    function focusPasswordField() {
        if (!root.hasPasswordField()) return
        passwordInput.forceActiveFocus()
    }

    function selectPasswordField() {
        if (!root.hasPasswordField()) return
        passwordInput.selectAll()
    }

    function triggerUnlockErrorWobble() {
        if (root.reducedMotion) return
        if (typeof unlockErrorWobble === "undefined" || unlockErrorWobble === null) return
        unlockErrorWobble.restart()
    }

    function triggerAuthFailure(message, keepInput) {
        root.authFailed = true
        root.authStatusText = message && message.length ? message : "认证失败，请重试"

        if (!keepInput) {
            root.passwordText = ""
            if (root.hasPasswordField()) passwordInput.text = ""
        } else {
            root.selectPasswordField()
        }

        root.focusPasswordField()
        root.triggerUnlockErrorWobble()
    }

    function finishUnlock() {
        root.appendDebugLog("[unlock] finishUnlock")
        lock.locked = false
        unlockQuitTimer.restart()
    }

    function maybeRespondToPam() {
        if (!pam.active || !pam.responseRequired) {
            root.lastPamPromptKey = ""
            return
        }

        var promptKey = [
            pam.message,
            pam.messageIsError ? "1" : "0",
            pam.responseVisible ? "1" : "0"
        ].join("|")

        if (root.lastPamPromptKey === promptKey) return

        if (!root.passwordText.length) {
            pam.abort()
            root.triggerAuthFailure(pam.message || "请输入密码", true)
            return
        }

        root.lastPamPromptKey = promptKey
        root.authStatusText = pam.message && pam.message.length ? pam.message : "正在验证..."
        console.log("[lockscreen] pam respond via property fallback:", pam.message)
        root.appendDebugLog("[pam] respond via property fallback | message=" + pam.message)
        pam.respond(root.passwordText)
    }

    function handlePamPrompt(message, isError, responseRequired, responseVisible) {
        if (message && !responseRequired) {
            root.authStatusText = message
        }

        if (!responseRequired) {
            root.lastPamPromptKey = ""
            return
        }

        var promptKey = [
            message || "",
            isError ? "1" : "0",
            responseVisible ? "1" : "0"
        ].join("|")

        if (root.lastPamPromptKey === promptKey) return

        if (!root.passwordText.length) {
            pam.abort()
            root.triggerAuthFailure(message || "请输入密码", true)
            return
        }

        root.lastPamPromptKey = promptKey
        root.authStatusText = message && message.length ? message : "正在验证..."
        console.log("[lockscreen] pam respond via onMessage:", message)
        root.appendDebugLog("[pam] respond via prompt | message=" + message + " | error=" + isError + " | visible=" + responseVisible)
        pam.respond(root.passwordText)
    }

    function setIdleEnabled(enabled) {
        if (root.idleToggleBusy) return

        root.idleToggleBusy = true
        root.idleEnabled = enabled
        toggleIdleProc.exec([
            "sh",
            "-lc",
            "$HOME/.config/quickshell/scripts/idle-control.sh " + (enabled ? "enable" : "disable") + " >/dev/null 2>&1"
        ])
    }

    function beginUnlock() {
        root.powerMenuVisible = false
        root.resetAuthState()

        if (pam.active) return

        if (!root.passwordText.length) {
            root.triggerAuthFailure("请输入密码", true)
            return
        }

        console.log("[lockscreen] beginUnlock start pam")
        root.appendDebugLog("[pam] beginUnlock start")
        if (!pam.start()) {
            root.triggerAuthFailure("PAM 启动失败")
            root.appendDebugLog("[pam] start failed")
            return
        }

        pamResponseKickTimer.restart()
    }

    Timer {
        id: delayedColorRead
        interval: 200
        repeat: false
        onTriggered: root.applyDynamicColors(colorFileView.text())
    }

    Timer {
        id: pamResponseKickTimer
        interval: 1
        repeat: false
        onTriggered: root.maybeRespondToPam()
    }

    Timer {
        id: unlockQuitTimer
        interval: 250
        repeat: false
        onTriggered: Qt.quit()
    }

    FileView {
        id: colorFileView
        path: Qt.resolvedUrl(root.colorFilePath)
        watchChanges: true

        onFileChanged: {
            this.reload()
            delayedColorRead.start()
        }

        onLoadedChanged: {
            if (this.loaded) root.applyDynamicColors(this.text())
        }

        onLoadFailed: {
            console.log("[lockscreen] Color file not found, using fallback colors")
        }
    }

    Process {
        id: idleFlagEnsureProc
        running: true
        command: ["sh", "-lc", "$HOME/.config/quickshell/scripts/idle-control.sh ensure >/dev/null 2>&1"]
    }

    FileView {
        id: idleFlagView
        path: Qt.resolvedUrl(root.idleFlagUrl)
        watchChanges: true

        onFileChanged: {
            this.reload()
        }

        onLoadedChanged: {
            if (this.loaded) root.parseIdleFlag(this.text())
        }

        onLoadFailed: {
            root.idleEnabled = true
        }
    }
    
    property string wallpaperPath: ""
    property string hostname: ""
    property string username: ""
    property string networkName: ""
    property int batteryLevel: 0
    property bool powerMenuVisible: false

    // 异步获取系统资产
    Process {
        id: wallpaperProc
        command: ["sh", "-c", "swww query | sed -n 's/.*image: //p'"]
        running: true
        stdout: SplitParser {
            onRead: function(data) { root.wallpaperPath = data.trim() }
        }
    }
    
    Process {
        id: usernameProc
        command: ["sh", "-c", "whoami"]
        running: true
        stdout: SplitParser {
            onRead: function(data) { root.username = data.trim() }
        }
    }

    Process {
        id: networkProc
        command: ["sh", "-c", "nmcli -t -f NAME connection show --active 2>/dev/null | head -1"]
        running: true
        stdout: SplitParser {
            onRead: function(data) {
                var name = data.trim()
                root.networkName = name ? name : "未连接"
            }
        }
    }

    Process {
        id: batteryProc
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 100"]
        running: true
        stdout: SplitParser {
            onRead: function(data) { root.batteryLevel = parseInt(data.trim()) || 0 }
        }
    }

    // 定时刷新
    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            batteryProc.running = false
            batteryProc.running = true
        }
    }

    // 电源管理指令
    Process { id: powerOffProc; command: ["systemctl", "poweroff"] }
    Process { id: rebootProc; command: ["systemctl", "reboot"] }
    Process { id: suspendProc; command: ["systemctl", "suspend"] }
    Process {
        id: toggleIdleProc
        command: ["sh", "-lc", "true"]
        onExited: function() {
            root.idleToggleBusy = false
            idleFlagView.reload()
        }
    }
    Process {
        id: debugLogProc
        command: ["sh", "-lc", "true"]
    }

    PamContext {
        id: pam
        config: "swaylock"
        user: root.username || "shiyi"

        onCompleted: function(result) {
            console.log("[lockscreen] pam completed:", PamResult.toString(result))
            root.appendDebugLog("[pam] completed | result=" + PamResult.toString(result) + " | message=" + pam.message)
            if (result === PamResult.Success) {
                root.resetAuthState()
                root.passwordText = ""
                if (root.hasPasswordField()) passwordInput.text = ""
                root.finishUnlock()
                return
            }

            if (result === PamResult.MaxTries) {
                root.triggerAuthFailure("尝试次数过多")
                return
            }

            if (result === PamResult.Failed) {
                root.triggerAuthFailure(pam.message || "密码错误")
                return
            }

            root.triggerAuthFailure(pam.message || "PAM 认证异常")
        }

        onError: function(error) {
            console.log("[lockscreen] pam error:", PamError.toString(error))
            root.appendDebugLog("[pam] error | error=" + PamError.toString(error))
            root.triggerAuthFailure(PamError.toString(error) || "PAM 系统错误")
        }

        onPamMessage: {
            console.log("[lockscreen] pamMessage signal:", pam.message, pam.messageIsError, pam.responseRequired, pam.responseVisible)
            root.appendDebugLog("[pam] pamMessage | message=" + pam.message + " | error=" + pam.messageIsError + " | responseRequired=" + pam.responseRequired + " | responseVisible=" + pam.responseVisible)
            root.handlePamPrompt(pam.message, pam.messageIsError, pam.responseRequired, pam.responseVisible)
            pamResponseKickTimer.restart()
        }

        onActiveChanged: {
            if (pam.active) {
                console.log("[lockscreen] pam active")
                root.appendDebugLog("[pam] active=true")
                root.authStatusText = "正在验证..."
                pamResponseKickTimer.restart()
            } else {
                console.log("[lockscreen] pam inactive")
                root.appendDebugLog("[pam] active=false")
                root.lastPamPromptKey = ""
            }
        }

        onMessageChanged: {
            console.log("[lockscreen] pam messageChanged:", pam.message, pam.messageIsError, pam.responseRequired, pam.responseVisible)
            root.appendDebugLog("[pam] messageChanged | message=" + pam.message + " | error=" + pam.messageIsError + " | responseRequired=" + pam.responseRequired + " | responseVisible=" + pam.responseVisible)
            if (pam.message && !pam.responseRequired) root.authStatusText = pam.message
            pamResponseKickTimer.restart()
        }

        onResponseRequiredChanged: {
            console.log("[lockscreen] pam responseRequiredChanged:", pam.responseRequired)
            root.appendDebugLog("[pam] responseRequiredChanged | value=" + pam.responseRequired)
            pamResponseKickTimer.restart()
        }

        onResponseVisibleChanged: {
            console.log("[lockscreen] pam responseVisibleChanged:", pam.responseVisible)
            root.appendDebugLog("[pam] responseVisibleChanged | value=" + pam.responseVisible)
            pamResponseKickTimer.restart()
        }
    }

    WlSessionLock {
        id: lock
        locked: true
        
        WlSessionLockSurface {
            color: "#0f0f12"

            // 锁屏进场淡入（reducedMotion 时直接显示）
            opacity: 0
            Component.onCompleted: opacity = 1
            Behavior on opacity {
                NumberAnimation {
                    duration: root.reducedMotion ? 0 : Config.Theme.animSlow
                    easing.type: Easing.OutCubic
                }
            }
            
            // --- 背景渲染层 ---
            Item {
                anchors.fill: parent
                
                Image {
                    id: wallpaperImage
                    anchors.fill: parent
                    source: root.wallpaperPath
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                }

                // 静态壁纸只渲染一次并缓存到 GPU 纹理，MultiEffect blur 不再每帧采样源
                MultiEffect {
                    source: wallpaperImage
                    anchors.fill: parent
                    blurEnabled: true
                    blur: 1.0
                    blurMax: 64
                    brightness: -0.3
                    layer.enabled: true
                }
                
                Rectangle {
                    anchors.fill: parent
                    color: root.tintColor
                }

                // --- 动态粒子系统 ---
                Canvas {
                    id: particleCanvas
                    anchors.fill: parent
                    z: 1 
                    
                    property var particles: []
                    property bool initialized: false
                    
                    function initParticles() {
                        if (width <= 0 || height <= 0) return
                        particles = []
                        for (var i = 0; i < 30; i++) {
                            particles.push({
                                x: Math.random() * width,
                                y: Math.random() * height,
                                size: Math.random() * 3 + 1.5,
                                vx: (Math.random() - 0.5) * 1.7,
                                vy: (Math.random() - 0.5) * 1.7,
                                alpha: Math.random() * 0.6 + 0.2,
                                color: Math.random() > 0.5 ? Config.Theme.textPrimary : Config.Theme.accentSecondary
                            })
                        }
                        initialized = true
                    }

                    onWidthChanged: initParticles()
                    onHeightChanged: initParticles()

                    // reducedMotion 时绘制一帧静态粒子，不启动重绘 Timer
                    Component.onCompleted: {
                        if (root.reducedMotion) requestPaint()
                    }

                    onPaint: {
                        if (!initialized) initParticles()
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)

                        for (var i = 0; i < particles.length; i++) {
                            var p = particles[i]
                            ctx.beginPath()
                            ctx.globalAlpha = p.alpha
                            ctx.fillStyle = p.color
                            ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2)
                            ctx.fill()

                            if (!root.reducedMotion) {
                                p.x += p.vx
                                p.y += p.vy

                                if (p.x < 0) p.x = width
                                if (p.x > width) p.x = 0
                                if (p.y < 0) p.y = height
                                if (p.y > height) p.y = 0
                            }
                        }
                    }

                    // 30fps 重绘（原为 16ms/60fps）；粒子速度已按 33ms 帧间隔补偿，避免跳变
                    Timer {
                        interval: 33
                        running: !root.reducedMotion
                        repeat: true
                        onTriggered: particleCanvas.requestPaint()
                    }
                }
            }

            // --- UI 交互层 ---
            


            // 右上角电源操作
            MouseArea {
                id: powerMenuDismissArea
                anchors.fill: parent
                visible: root.powerMenuVisible
                enabled: root.powerMenuVisible
                z: 19
                onClicked: {
                    root.powerMenuVisible = false
                    root.focusPasswordField()
                }
            }

            Item {
                id: powerArea
                z: 20
                width: Math.max(topButtons.implicitWidth, powerMenu.width)
                height: topButtons.height + (root.powerMenuVisible ? (powerMenu.implicitHeight + root.u * 0.75) : 0)
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: root.u * 1
                anchors.rightMargin: root.u * 4

                Row {
                    id: topButtons
                    anchors.top: parent.top
                    anchors.right: parent.right
                    spacing: root.u * 0.55

                    // 电源按钮
                    Rectangle {
                        id: powerButton
                        width: root.u * 2.8
                        height: root.u * 2.8
                        radius: width / 2
                        color: powerButtonArea.containsMouse
                            ? Qt.rgba(1, 1, 1, 0.1)
                            : Qt.rgba(1, 1, 1, 0.05)
                        border.color: Qt.rgba(1, 1, 1, 0.1)

                        Behavior on color {
                            ColorAnimation { duration: Config.Theme.animFast }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "⏻"
                            color: root.textSecondary
                            font.pixelSize: root.u * 1.2
                        }

                        MouseArea {
                            id: powerButtonArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: function(mouse) {
                                root.powerMenuVisible = !root.powerMenuVisible
                                mouse.accepted = true
                            }
                        }
                    }

                    Rectangle {
                        id: idleToggleButton
                        width: root.u * 2.8
                        height: root.u * 2.8
                        radius: width / 2
                        color: idleToggleArea.containsMouse
                            ? Qt.rgba(1, 1, 1, 0.1)
                            : Qt.rgba(1, 1, 1, 0.05)
                        border.color: Qt.rgba(1, 1, 1, 0.1)
                        opacity: root.idleToggleBusy ? 0.66 : 1.0

                        Behavior on color {
                            ColorAnimation { duration: Config.Theme.animFast }
                        }

                        Item {
                            anchors.centerIn: parent
                            width: root.u * 1.4
                            height: root.u * 1.4

                            Text {
                                id: idleToggleButtonIcon
                                anchors.centerIn: parent
                                text: "👁"
                                color: root.textSecondary
                                font.pixelSize: root.u * 1.05
                                opacity: root.idleEnabled ? 0.72 : 0.98
                            }

                            Rectangle {
                                visible: root.idleEnabled
                                width: root.u * 1.15
                                height: root.u * 0.11
                                radius: height / 2
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.verticalCenterOffset: 1
                                rotation: -34
                                color: Qt.rgba(0.98, 0.96, 0.92, 0.56)
                            }
                        }

                        MouseArea {
                            id: idleToggleArea
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !root.idleToggleBusy
                            onClicked: root.setIdleEnabled(!root.idleEnabled)
                        }
                    }
                }

                // 电源菜单
                Rectangle {
                    id: powerMenu
                    anchors.top: topButtons.bottom
                    anchors.topMargin: root.u * 0.75
                    anchors.right: parent.right
                    width: Math.max(topButtons.implicitWidth, contentColumn.implicitWidth)
                    implicitHeight: contentColumn.height + root.u * 2
                    height: root.powerMenuVisible ? implicitHeight : 0
                    radius: Config.Theme.radiusMedium
                    clip: true
                    color: root.bgGlass
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    opacity: root.powerMenuVisible ? 1 : 0
                    visible: root.powerMenuVisible || opacity > 0
                    enabled: root.powerMenuVisible

                    Behavior on opacity {
                        NumberAnimation { duration: Config.Theme.animNormal; easing.type: Easing.OutCubic }
                    }
                    Behavior on height {
                        NumberAnimation { duration: Config.Theme.animNormal; easing.type: Easing.OutCubic }
                    }

                    Column {
                        id: contentColumn
                        anchors.top: parent.top
                        anchors.topMargin: root.u
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: root.u * 0.5

                        Repeater {
                            model: [
                                { text: "关机", icon: "ⵚ", proc: powerOffProc },
                                { text: "休眠", icon: "⯕", proc: suspendProc },
                                { text: "重启", icon: "↺", proc: rebootProc }
                            ]
                            delegate: Rectangle {
                                implicitWidth: itemRow.implicitWidth + root.u * 1.6
                                width: implicitWidth
                                height: root.u * 1.8
                                radius: Config.Theme.radiusSmall
                                color: itemArea.containsMouse
                                    ? Qt.rgba(1, 1, 1, 0.05)
                                    : "transparent"

                                Behavior on color {
                                    ColorAnimation { duration: Config.Theme.animFast }
                                }

                                Row {
                                    id: itemRow
                                    anchors.left: parent.left
                                    anchors.leftMargin: root.u * 0.8
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: root.u * 1.5
                                    spacing: root.u * 0.6

                                    Text {
                                        text: modelData.icon
                                        font.pixelSize: root.u
                                        color: root.textSecondary
                                        height: parent.height
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    Text {
                                        text: modelData.text
                                        font.pixelSize: root.u * 0.9
                                        font.family: "Source Han Sans CN"
                                        color: root.textPrimary
                                        height: parent.height
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }

                                MouseArea {
                                    id: itemArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        root.powerMenuVisible = false
                                        modelData.proc.running = true
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 中央核心面板
            Column {
                anchors.centerIn: parent
                spacing: root.u * 4
                
                // 动态时钟
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: root.u * 0.5
                    Text {
                        id: timeText
                        anchors.horizontalCenter: parent.horizontalCenter
                        font.pixelSize: root.u * 8
                        font.weight: Font.ExtraLight
                        font.family: "Source Han Sans CN"
                        color: root.textPrimary
                        text: Qt.formatDateTime(new Date(), "HH:mm")
                    }
                    Text {
                        id: dateText
                        anchors.horizontalCenter: parent.horizontalCenter
                        font.pixelSize: root.u * 1.2
                        font.family: "Source Han Sans CN"
                        color: root.textSecondary
                        text: {
                            var days = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
                            var now = new Date()
                            return now.getFullYear() + "年 " + (now.getMonth() + 1) + "月 " + now.getDate() + "日 " + days[now.getDay()]
                        }
                    }
                    Timer {
                        interval: 1000
                        running: true
                        repeat: true
                        onTriggered: timeText.text = Qt.formatDateTime(new Date(), "HH:mm")
                    }
                }

                // 认证卡片
                Rectangle {
                    width: root.u * 24
                    height: root.u * 18
                    radius: root.u
                    color: "transparent"
                    border.width: 0
                    border.color: "transparent"
                    
                    Column {
                        anchors.centerIn: parent
                        spacing: root.u * 1.5
                        width: parent.width - root.u * 4
                        
                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: root.u * 0.8
                            Rectangle {
                                width: root.u * 5
                                height: root.u * 5
                                radius: width / 2
                                anchors.horizontalCenter: parent.horizontalCenter
                                gradient: Gradient {
                                    GradientStop { position: 0; color: root.accent }
                                    GradientStop { position: 1; color: Qt.darker(root.accent, 1.22) }
                                }
                                Text {
                                    anchors.centerIn: parent
                                    font.pixelSize: root.u * 1.8
                                    color: root.buttonText
                                    text: root.username.substring(0, 2).toUpperCase()
                                }
                            }
                            Text {
                                text: root.username
                                color: root.textPrimary
                                font.pixelSize: root.u * 1.2
                                font.weight: Font.Medium
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }

                        Item {
                            width: parent.width
                            height: root.u * 3.2

                            Rectangle {
                                anchors.fill: parent
                                radius: 0
                                color: root.fieldBg
                                border.width: 0
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: root.authFailed || passwordInput.activeFocus ? 2 : 1
                                color: root.authFailed
                                    ? root.errorColor
                                    : (passwordInput.activeFocus ? root.accent : root.colorFromHex(root.accent, 0.72))
                                opacity: root.authFailed ? 1.0 : (passwordInput.activeFocus ? 0.98 : 0.48)

                                Behavior on height {
                                    NumberAnimation { duration: Config.Theme.animNormal; easing.type: Easing.OutCubic }
                                }
                                Behavior on color {
                                    ColorAnimation { duration: Config.Theme.animNormal; easing.type: Easing.OutCubic }
                                }
                                Behavior on opacity {
                                    NumberAnimation { duration: Config.Theme.animNormal; easing.type: Easing.OutCubic }
                                }
                            }

                            TextInput {
                                id: passwordInput
                                anchors.fill: parent
                                anchors.leftMargin: root.u * 0.8
                                anchors.rightMargin: root.u * 0.8
                                anchors.topMargin: root.u * 0.7
                                anchors.bottomMargin: root.u * 0.55
                                focus: true
                                enabled: !pam.active
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                font.pixelSize: root.u * 1.1
                                color: root.textPrimary
                                text: root.passwordText
                                echoMode: pam.responseVisible ? TextInput.Normal : TextInput.Password
                                inputMethodHints: Qt.ImhHiddenText | Qt.ImhNoPredictiveText | Qt.ImhSensitiveData
                                onAccepted: root.beginUnlock()
                                onTextChanged: {
                                    if (root.passwordText !== text) root.passwordText = text
                                }
                                onTextEdited: {
                                    if (!pam.active) root.resetAuthState()
                                }
                                Keys.onEscapePressed: {
                                    root.powerMenuVisible = false
                                    root.passwordText = ""
                                    passwordInput.text = ""
                                    root.resetAuthState()
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -root.u * 0.1
                                visible: !root.passwordText && !passwordInput.activeFocus && !pam.active
                                text: pam.message && pam.responseRequired ? pam.message : "输入密码"
                                color: root.textSecondary
                                font.pixelSize: root.u
                            }
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: root.authStatusText
                            visible: text.length > 0 && !pam.active
                            color: root.authFailed ? root.errorColor : root.textSecondary
                            font.family: "Source Han Sans CN"
                            font.pixelSize: root.u * 0.75
                            wrapMode: Text.WordWrap
                        }

                        Rectangle {
                            id: unlockButton
                            width: parent.width
                            height: root.u * 2.85
                            radius: 0
                            transformOrigin: Item.Center
                            opacity: pam.active ? 0.86 : 1.0
                            property color fillColor: unlockArea.pressed
                                ? Qt.darker(root.accent, 1.18)
                                : (unlockArea.containsMouse ? Qt.lighter(root.accent, 1.05) : root.accent)
                            property color outlineColor: root.colorFromHex(
                                root.buttonText === "#141414" ? "#000000" : "#ffffff",
                                unlockArea.containsMouse ? 0.18 : 0.10
                            )
                            color: fillColor
                            border.width: 1
                            border.color: outlineColor
                            scale: unlockArea.pressed ? 0.995 : 1.0

                            Behavior on fillColor {
                                ColorAnimation { duration: root.reducedMotion ? 0 : Config.Theme.animFast; easing.type: Easing.OutCubic }
                            }
                            Behavior on outlineColor {
                                ColorAnimation { duration: root.reducedMotion ? 0 : Config.Theme.animFast; easing.type: Easing.OutCubic }
                            }
                            Behavior on scale {
                                NumberAnimation { duration: root.reducedMotion ? 0 : Config.Theme.animFast; easing.type: Easing.OutCubic }
                            }

                            SequentialAnimation {
                                id: unlockErrorWobble
                                running: false

                                PropertyAnimation { target: unlockButton; property: "rotation"; to: -7; duration: 42; easing.type: Easing.OutCubic }
                                PropertyAnimation { target: unlockButton; property: "rotation"; to: 6; duration: 56; easing.type: Easing.OutCubic }
                                PropertyAnimation { target: unlockButton; property: "rotation"; to: -5; duration: 52; easing.type: Easing.OutCubic }
                                PropertyAnimation { target: unlockButton; property: "rotation"; to: 3; duration: 48; easing.type: Easing.OutCubic }
                                PropertyAnimation { target: unlockButton; property: "rotation"; to: 0; duration: 58; easing.type: Easing.OutCubic }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !pam.active
                                text: "解锁会话"
                                color: root.buttonText
                                font.weight: Font.Bold
                                font.pixelSize: root.u * 1.0
                                font.letterSpacing: 1.2
                            }

                            Item {
                                id: unlockLoadingContent
                                anchors.centerIn: parent
                                visible: pam.active
                                width: loadingSpinner.width + root.u * 0.55 + loadingLabel.implicitWidth
                                height: loadingSpinner.height > loadingLabel.implicitHeight
                                    ? loadingSpinner.height
                                    : loadingLabel.implicitHeight

                                Item {
                                    id: loadingSpinner
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: root.u * 1.0
                                    height: root.u * 1.0
                                    transformOrigin: Item.Center

                                    RotationAnimation on rotation {
                                        from: 0
                                        to: 360
                                        duration: 850
                                        loops: Animation.Infinite
                                        running: pam.active
                                    }

                                    Repeater {
                                        model: 8
                                        delegate: Item {
                                            width: loadingSpinner.width
                                            height: loadingSpinner.height
                                            anchors.centerIn: parent
                                            rotation: index * 45

                                            Rectangle {
                                                width: root.u * 0.12
                                                height: root.u * 0.28
                                                radius: width / 2
                                                color: root.buttonText
                                                opacity: 0.22 + index * 0.09
                                                anchors.top: parent.top
                                                anchors.horizontalCenter: parent.horizontalCenter
                                            }
                                        }
                                    }
                                }

                                Text {
                                    id: loadingLabel
                                    anchors.left: loadingSpinner.right
                                    anchors.leftMargin: root.u * 0.55
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.verticalCenterOffset: -root.u * 0.03
                                    text: "验证中"
                                    color: root.buttonText
                                    font.weight: Font.Bold
                                    font.pixelSize: root.u * 0.96
                                    font.letterSpacing: 1.0
                                }
                            }

                            MouseArea {
                                id: unlockArea
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !pam.active
                                onClicked: root.beginUnlock()
                            }
                        }

                    }
                }
            }

            // 底部状态栏
            Row {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.u * 2.5
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: root.u * 3
                Row {
                    spacing: root.u * 0.5
                    Text { text: "ⓛ"; color: root.textSecondary; font.pixelSize: root.u; height: root.u * 1.5; verticalAlignment: Text.AlignVCenter }
                    Text { text: "已锁定"; color: root.textSecondary; font.family: "Source Han Sans CN"; font.pixelSize: root.u * 0.9; height: root.u * 1.5; verticalAlignment: Text.AlignVCenter }
                }
            }

            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: {
                    root.focusPasswordField()
                    root.powerMenuVisible = false
                }
            }
            
            
        }
    }
}
