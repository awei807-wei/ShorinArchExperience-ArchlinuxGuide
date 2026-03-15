import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick.Effects
import Quickshell.Services.Mpris

ShellRoot {
    id: root
    
    readonly property int u: 16
    
    // Cyber-Zen 极简配色方案
    readonly property color bgGlass: Qt.rgba(0.078, 0.078, 0.098, 0.65)
    readonly property color accent: Qt.rgba(0.486, 0.604, 0.573, 1)
    readonly property color accentGlow: Qt.rgba(0.486, 0.604, 0.573, 0.3)
    readonly property color textPrimary: Qt.rgba(0.91, 0.91, 0.91, 1)
    readonly property color textSecondary: Qt.rgba(0.533, 0.533, 0.533, 1)
    readonly property color tintColor: Qt.rgba(0.1, 0.15, 0.18, 0.4)
    
    property string wallpaperPath: ""
    property string hostname: ""
    property string username: ""
    property string networkName: ""
    property int batteryLevel: 0
    property string fallbackMedia: ""

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
        id: hostnameProc
        command: ["sh", "-c", "hostnamectl --static"]
        running: true
        stdout: SplitParser {
            onRead: function(data) { root.hostname = data.trim() }
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

    // 备选媒体获取（针对无名播放器）
    Process {
        id: mediaFallbackProc
        command: ["playerctl", "metadata", "--format", "{{title}} - {{artist}}"]
        running: true
        stdout: SplitParser {
            onRead: function(data) { 
                var d = data.trim()
                if (d && d !== " - ") {
                    root.fallbackMedia = d
                } else {
                    root.fallbackMedia = ""
                }
            }
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
            mediaFallbackProc.running = false
            mediaFallbackProc.running = true
        }
    }

    // 电源管理指令
    Process { id: powerOffProc; command: ["systemctl", "poweroff"] }
    Process { id: rebootProc; command: ["systemctl", "reboot"] }
    Process { id: suspendProc; command: ["systemctl", "suspend"] }

    WlSessionLock {
        id: lock
        locked: true
        
        WlSessionLockSurface {
            color: "#0f0f12"
            
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
                
                MultiEffect {
                    source: wallpaperImage
                    anchors.fill: parent
                    blurEnabled: true
                    blur: 1.0
                    blurMax: 64
                    brightness: -0.3
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
                        for (var i = 0; i < 60; i++) {
                            particles.push({
                                x: Math.random() * width,
                                y: Math.random() * height,
                                size: Math.random() * 3 + 1.5,
                                vx: (Math.random() - 0.5) * 0.8,
                                vy: (Math.random() - 0.5) * 0.8,
                                alpha: Math.random() * 0.6 + 0.2,
                                color: Math.random() > 0.5 ? "#ffffff" : "#7c9a92"
                            })
                        }
                        initialized = true
                    }

                    onWidthChanged: initParticles()
                    onHeightChanged: initParticles()
                    
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
                            
                            p.x += p.vx
                            p.y += p.vy
                            
                            if (p.x < 0) p.x = width
                            if (p.x > width) p.x = 0
                            if (p.y < 0) p.y = height
                            if (p.y > height) p.y = 0
                        }
                    }
                    
                    Timer {
                        interval: 16 
                        running: true
                        repeat: true
                        onTriggered: particleCanvas.requestPaint()
                    }
                }
            }

            // --- UI 交互层 ---
            
            // 左上角状态气泡
            Row {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: root.u * 2.5
                spacing: root.u * 0.75
                
                Rectangle {
                    width: Math.min(root.u * 12, networkRow.implicitWidth + root.u * 2)
                    height: root.u * 2.2
                    radius: height / 2
                    color: root.bgGlass
                    border.color: Qt.rgba(1, 1, 1, 0.1)
                    clip: true
                    Row {
                        id: networkRow
                        anchors.centerIn: parent
                        spacing: root.u * 0.5
                        Text { 
                            text: "📡"
                            font.pixelSize: root.u * 0.9
                            height: root.u * 1.5
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            text: root.networkName || "未连接"
                            color: root.textPrimary
                            font.family: "Source Han Sans CN"
                            font.pixelSize: root.u * 0.8
                            maximumLineCount: 1
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, root.u * 9)
                            height: root.u * 1.5
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
                Rectangle {
                    width: root.u * 6
                    height: root.u * 2.2
                    radius: height / 2
                    color: root.bgGlass
                    border.color: Qt.rgba(1, 1, 1, 0.1)
                    Row {
                        anchors.centerIn: parent
                        spacing: root.u * 0.5
                        Text {
                            text: "🔋"
                            font.pixelSize: root.u * 0.9
                            height: root.u * 1.5
                            verticalAlignment: Text.AlignVCenter
                        }
                        Text {
                            text: root.batteryLevel + "%"
                            color: root.textPrimary
                            font.family: "Source Han Sans CN"
                            font.pixelSize: root.u * 0.8
                            height: root.u * 1.5
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }

            // 右上角电源操作
            Row {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: root.u * 2.5
                spacing: root.u * 0.75
                
                Repeater {
                    model: [
                        { icon: "⏻", action: function() { powerOffProc.running = true } }
                    ]
                    delegate: Rectangle {
                        width: root.u * 2.8
                        height: root.u * 2.8
                        radius: width / 2
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.color: Qt.rgba(1, 1, 1, 0.1)
                        Text {
                            anchors.centerIn: parent
                            text: modelData.icon
                            color: root.textSecondary
                            font.pixelSize: root.u * 1.2
                        }
                        MouseArea { 
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: parent.color = Qt.rgba(1, 1, 1, 0.1)
                            onExited: parent.color = Qt.rgba(1, 1, 1, 0.05)
                            onClicked: modelData.action() 
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
                    color: root.bgGlass
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    
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
                                    GradientStop { position: 1; color: "#5a7a72" }
                                }
                                Text {
                                    anchors.centerIn: parent
                                    font.pixelSize: root.u * 1.8
                                    color: "white"
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
                            Text {
                                text: root.hostname
                                color: root.textSecondary
                                font.pixelSize: root.u * 0.85
                                font.family: "monospace"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: root.u * 3
                            radius: 12
                            color: Qt.rgba(0, 0, 0, 0.3)
                            border.color: passwordInput.activeFocus ? root.accent : Qt.rgba(1, 1, 1, 0.1)
                            TextInput {
                                id: passwordInput
                                anchors.fill: parent
                                anchors.margins: root.u
                                focus: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                font.pixelSize: root.u * 1.1
                                color: root.textPrimary
                                echoMode: TextInput.Password
                                onAccepted: { lock.locked = false; Qt.quit() }
                                Keys.onEscapePressed: { lock.locked = false; Qt.quit() }
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: !passwordInput.text && !passwordInput.activeFocus
                                text: "输入密码"
                                color: root.textSecondary
                                font.pixelSize: root.u
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: root.u * 3
                            radius: 12
                            color: root.accent
                            Text {
                                anchors.centerIn: parent
                                text: "解锁会话"
                                color: "#0a0a0f"
                                font.weight: Font.Bold
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: { lock.locked = false; Qt.quit() }
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
                    Text { text: "⌨"; color: root.textSecondary; font.pixelSize: root.u; height: root.u * 1.5; verticalAlignment: Text.AlignVCenter }
                    Text { text: "US"; color: root.textSecondary; font.family: "monospace"; font.pixelSize: root.u * 0.9; height: root.u * 1.5; verticalAlignment: Text.AlignVCenter }
                }
                Row {
                    spacing: root.u * 0.5
                    Text { text: "🔒"; color: root.textSecondary; font.pixelSize: root.u; height: root.u * 1.5; verticalAlignment: Text.AlignVCenter }
                    Text { text: "已锁定"; color: root.textSecondary; font.family: "Source Han Sans CN"; font.pixelSize: root.u * 0.9; height: root.u * 1.5; verticalAlignment: Text.AlignVCenter }
                }
                Row {
                    spacing: root.u * 0.5
                    Text { text: "🎵"; color: root.textSecondary; font.pixelSize: root.u; height: root.u * 1.5; verticalAlignment: Text.AlignVCenter }
                    Text { 
                        id: mediaText
                        text: {
                            // 极简且稳健的取值逻辑
                            var p = MprisController.activePlayer
                            if (p && p.trackTitle) {
                                return p.trackArtist ? (p.trackTitle + " - " + p.trackArtist) : p.trackTitle
                            }
                            return root.fallbackMedia || "未在播放"
                        }
                        color: root.textSecondary
                        font.family: "Source Han Sans CN"
                        font.pixelSize: root.u * 0.9
                        height: root.u * 1.5
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, root.u * 15)
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: passwordInput.focus = true
            }
        }
    }
}