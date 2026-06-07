import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: window

    Scaler {
        id: scaler
        currentWidth: Screen.width
    }
    
    function s(val) { 
        return scaler.s(val); 
    }

    MatugenColors { id: _theme }
    readonly property color base: _theme.base
    readonly property color mantle: _theme.mantle
    readonly property color crust: _theme.crust
    readonly property color text: _theme.text
    readonly property color subtext0: _theme.subtext0
    readonly property color overlay0: _theme.overlay0
    readonly property color surface0: _theme.surface0
    readonly property color surface1: _theme.surface1
    readonly property color surface2: _theme.surface2
    readonly property color mauve: _theme.mauve
    readonly property color blue: _theme.blue
    readonly property color green: _theme.green
    readonly property color yellow: _theme.yellow
    readonly property color red: _theme.red
    readonly property color peach: _theme.peach
    readonly property color sapphire: _theme.sapphire

    property int cpuUsage: 0
    property int memUsage: 0
    property int diskUsage: 0
    property string powerProfile: "balanced"
    property int upHours: 0
    property int upMins: 0
    property real sysVolume: 0
    property bool sysMuted: false
    property string currentUserName: ""

    property bool isDraggingVol: false
    Timer { id: volSyncDelay; interval: 800; onTriggered: window.isDraggingVol = false; triggeredOnStart: true; }

    readonly property color profileStart: {
        if (powerProfile === "performance") return window.red;
        if (powerProfile === "power-saver") return window.green;
        return window.blue;
    }
    readonly property color profileEnd: Qt.lighter(profileStart, 1.15)

    property real animCpu: 0
    property real animMem: 0
    property real animDisk: 0
    Behavior on animCpu { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }
    Behavior on animMem { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }
    Behavior on animDisk { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }

    Process {
        id: userPoller
        command: ["bash", "-c", "echo $USER"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                window.currentUserName = this.text.trim();
            }
        }
    }

    Process {
        id: sysPoller
        command: ["bash", "-c", 
            "top -bn1 | grep 'Cpu(s)' | awk '{print int($2+$4)}' 2>/dev/null || echo '0'; " +
            "free | awk '/^Mem:/ {print int($3/$2 * 100)}' 2>/dev/null || echo '0'; " +
            "df -h / | awk 'NR==2 {print int($5)}' 2>/dev/null || echo '0'; " +
            "powerprofilesctl get 2>/dev/null || echo 'balanced'; " +
            "awk '{print int($1/3600)\"h \"int(($1%3600)/60)\"m\"}' /proc/uptime 2>/dev/null || echo '0h 0m'; " +
            "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print int($2*100), ($3==\"[MUTED]\"?\"off\":\"on\")}' || echo '0 on'"
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n");
                if (lines.length >= 6) {
                    let newCpu = parseInt(lines[0]) || 0;
                    let newMem = parseInt(lines[1]) || 0;
                    let newDisk = parseInt(lines[2]) || 0;
                    if (window.cpuUsage !== newCpu) {
                        window.cpuUsage = newCpu;
                        window.animCpu = newCpu;
                    }
                    if (window.memUsage !== newMem) {
                        window.memUsage = newMem;
                        window.animMem = newMem;
                    }
                    if (window.diskUsage !== newDisk) {
                        window.diskUsage = newDisk;
                        window.animDisk = newDisk;
                    }
                    window.powerProfile = lines[3];
                    
                    let upParts = lines[4].split("h ");
                    if (upParts.length === 2) {
                        window.upHours = parseInt(upParts[0]) || 0;
                        window.upMins = parseInt(upParts[1].replace("m", "")) || 0;
                    }

                    if (!window.isDraggingVol) {
                        let volParts = (lines[5] || "0 on").trim().split(" ");
                        window.sysVolume = parseInt(volParts[0]) || 0;
                        window.sysMuted = (volParts[1] === "off");
                    }
                }
            }
        }
    }
    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true;
        onTriggered: sysPoller.running = true
    }

    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0; to: Math.PI * 2; duration: 90000; loops: Animation.Infinite; running: true
    }

    property real introMain: 0
    property real introTop: 0
    property real introCore: 0
    property real introSliders: 0
    property real introActions: 0
    property real introProfiles: 0

    ParallelAnimation {
        running: true
        NumberAnimation { target: window; property: "introMain"; from: 0; to: 1.0; duration: 800; easing.type: Easing.OutQuart }
        SequentialAnimation {
            PauseAnimation { duration: 100 }
            NumberAnimation { target: window; property: "introTop"; from: 0; to: 1.0; duration: 800; easing.type: Easing.OutBack; easing.overshoot: 1.0 }
        }
        SequentialAnimation {
            PauseAnimation { duration: 250 }
            NumberAnimation { target: window; property: "introCore"; from: 0; to: 1.0; duration: 900; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
        }
        SequentialAnimation {
            PauseAnimation { duration: 350 }
            NumberAnimation { target: window; property: "introSliders"; from: 0; to: 1.0; duration: 800; easing.type: Easing.OutQuart }
        }
        SequentialAnimation {
            PauseAnimation { duration: 450 }
            NumberAnimation { target: window; property: "introActions"; from: 0; to: 1.0; duration: 800; easing.type: Easing.OutExpo }
        }
        SequentialAnimation {
            PauseAnimation { duration: 550 }
            NumberAnimation { target: window; property: "introProfiles"; from: 0; to: 1.0; duration: 850; easing.type: Easing.OutBack; easing.overshoot: 0.8 }
        }
    }

    ParallelAnimation {
        id: exitAnim
        NumberAnimation { target: window; property: "introMain"; to: 0; duration: 400; easing.type: Easing.InQuart }
        NumberAnimation { target: window; property: "introTop"; to: 0; duration: 300; easing.type: Easing.InQuart }
        NumberAnimation { target: window; property: "introCore"; to: 0; duration: 350; easing.type: Easing.InQuart }
        NumberAnimation { target: window; property: "introSliders"; to: 0; duration: 250; easing.type: Easing.InQuart }
        NumberAnimation { target: window; property: "introActions"; to: 0; duration: 200; easing.type: Easing.InQuart }
        NumberAnimation { target: window; property: "introProfiles"; to: 0; duration: 150; easing.type: Easing.InQuart }
    }

    Item {
        anchors.fill: parent
        scale: 0.92 + (0.08 * introMain)
        opacity: introMain
        transform: Translate { y: window.s(15) * (1 - introMain) }

        Rectangle {
            anchors.fill: parent
            radius: window.s(20)
            color: window.base
            border.color: window.surface0
            border.width: 1
            clip: true

            Rectangle {
                width: parent.width * 0.8; height: width; radius: width / 2
                x: (parent.width / 2 - width / 2) + Math.cos(window.globalOrbitAngle * 2) * window.s(150)
                y: (parent.height / 2 - height / 2) + Math.sin(window.globalOrbitAngle * 2) * window.s(100)
                opacity: 0.08
                color: window.blue
                Behavior on color { ColorAnimation { duration: 1000 } }
            }
            
            Rectangle {
                width: parent.width * 0.9; height: width; radius: width / 2
                x: (parent.width / 2 - width / 2) + Math.sin(window.globalOrbitAngle * 1.5) * window.s(-150)
                y: (parent.height / 2 - height / 2) + Math.cos(window.globalOrbitAngle * 1.5) * window.s(-100)
                opacity: 0.06
                color: window.sapphire
                Behavior on color { ColorAnimation { duration: 1000 } }
            }

            Row {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: window.s(25)
                spacing: window.s(6)
                
                transform: Translate { y: window.s(-20) * (1.0 - introTop) }
                opacity: introTop
                
                Rectangle {
                    width: window.s(44); height: window.s(48); radius: window.s(10)
                    color: "#0dffffff"; border.color: "#1affffff"; border.width: 1
                    
                    Rectangle { anchors.fill: parent; radius: window.s(10); color: window.blue; opacity: 0.05; Behavior on color { ColorAnimation { duration: 1000 } } }
                    Column {
                        anchors.centerIn: parent
                        Text { 
                            text: window.upHours.toString().padStart(2, '0')
                            font.pixelSize: window.s(18); font.family: "JetBrains Mono"; font.weight: Font.Black
                            color: window.blue
                            Behavior on color { ColorAnimation { duration: 1000 } }
                            anchors.horizontalCenter: parent.horizontalCenter 
                        }
                        Text { 
                            text: "HR"; font.pixelSize: window.s(8); font.family: "JetBrains Mono"; font.weight: Font.Bold
                            color: window.subtext0; anchors.horizontalCenter: parent.horizontalCenter 
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ":"
                    font.pixelSize: window.s(22); font.family: "JetBrains Mono"; font.weight: Font.Black
                    color: window.blue
                    Behavior on color { ColorAnimation { duration: 1000 } }
                    
                    opacity: uptimePulse
                    property real uptimePulse: 1.0
                    SequentialAnimation on uptimePulse {
                        loops: Animation.Infinite; running: true
                        NumberAnimation { to: 0.2; duration: 800; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                    }
                }

                Rectangle {
                    width: window.s(44); height: window.s(48); radius: window.s(10)
                    color: "#0dffffff"; border.color: "#1affffff"; border.width: 1
                    
                    Rectangle { anchors.fill: parent; radius: window.s(10); color: window.sapphire; opacity: 0.05; Behavior on color { ColorAnimation { duration: 1000 } } }
                    Column {
                        anchors.centerIn: parent
                        Text { 
                            text: window.upMins.toString().padStart(2, '0')
                            font.pixelSize: window.s(18); font.family: "JetBrains Mono"; font.weight: Font.Black
                            color: window.sapphire
                            Behavior on color { ColorAnimation { duration: 1000 } }
                            anchors.horizontalCenter: parent.horizontalCenter 
                        }
                        Text { 
                            text: "MIN"; font.pixelSize: window.s(8); font.family: "JetBrains Mono"; font.weight: Font.Bold
                            color: window.subtext0; anchors.horizontalCenter: parent.horizontalCenter 
                        }
                    }
                }
            }

            Rectangle {
                id: logoutBtn
                anchors.top: parent.top; anchors.right: parent.right
                anchors.margins: window.s(25)
                width: logoutMa.containsMouse ? window.s(44) + usernameText.implicitWidth + window.s(12) : window.s(44)
                height: window.s(44); radius: window.s(14)
                color: logoutMa.containsMouse ? "#1affffff" : "transparent"
                border.color: logoutMa.containsMouse ? "#33ffffff" : "transparent"
                clip: true
                
                transform: Translate { y: window.s(-20) * (1.0 - introTop) }
                opacity: introTop

                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }
                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: window.s(13)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: window.s(12)

                    Text {
                        id: usernameText
                        text: window.currentUserName
                        font.family: "JetBrains Mono"
                        font.weight: Font.Bold
                        font.pixelSize: window.s(14)
                        color: window.text
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: logoutMa.containsMouse ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 250 } }
                    }

                    Text {
                        font.family: "Iosevka Nerd Font"; font.pixelSize: window.s(18)
                        color: logoutMa.containsMouse ? window.red : window.overlay0
                        text: "󰍃"
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }

                MouseArea {
                    id: logoutMa
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { 
                        exitAnim.start();
                        Quickshell.execDetached(["sh", "-c", "loginctl terminate-user $USER"]); 
                        Quickshell.execDetached(["sh", "-c", "echo 'close' > /tmp/qs_widget_state"]); 
                    }
                }
            }

            Item {
                anchors.fill: parent
                z: 1
                
                opacity: introCore
                transform: Translate { y: window.s(25) * (1 - introCore) }
                scale: 0.9 + (0.1 * introCore)

                Column {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: window.s(-40)
                    spacing: window.s(20)

                    Repeater {
                        model: ListModel {
                            ListElement { label: "CPU"; icon: "󰻠"; value: "cpuUsage"; animValue: "animCpu"; colorName: "blue" }
                            ListElement { label: "RAM"; icon: "󰍛"; value: "memUsage"; animValue: "animMem"; colorName: "green" }
                            ListElement { label: "DISK"; icon: "󰋊"; value: "diskUsage"; animValue: "animDisk"; colorName: "peach" }
                        }
                        
                        delegate: Row {
                            spacing: window.s(16)
                            
                            Text {
                                text: icon
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: window.s(28)
                                color: window[colorName]
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: 400 } }
                            }
                            
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: window.s(4)
                                
                                Row {
                                    spacing: window.s(8)
                                    Text {
                                        text: label
                                        font.family: "JetBrains Mono"
                                        font.weight: Font.Bold
                                        font.pixelSize: window.s(14)
                                        color: window.subtext0
                                    }
                                    Text {
                                        text: window[value] + "%"
                                        font.family: "JetBrains Mono"
                                        font.weight: Font.Black
                                        font.pixelSize: window.s(18)
                                        color: window.text
                                    }
                                }
                                
                                Rectangle {
                                    width: window.s(280)
                                    height: window.s(12)
                                    radius: window.s(6)
                                    color: "#0dffffff"
                                    border.color: "#1affffff"
                                    border.width: 1
                                    
                                    Rectangle {
                                        height: parent.height
                                        width: parent.width * (window[animValue] / 100)
                                        radius: window.s(6)
                                        Behavior on width { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }
                                        
                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop { position: 0.0; color: window[colorName]; Behavior on color { ColorAnimation { duration: 300 } } }
                                            GradientStop { position: 1.0; color: Qt.lighter(window[colorName], 1.2); Behavior on color { ColorAnimation { duration: 300 } } }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: window.s(25)
                spacing: window.s(15)

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: window.s(70)
                    radius: window.s(14)
                    color: "#05ffffff"
                    border.color: "#1affffff"
                    border.width: 1

                    opacity: introSliders
                    transform: Translate { y: window.s(20) * (1.0 - introSliders) }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: window.s(14)
                        spacing: window.s(12)

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: window.s(15)

                            Rectangle {
                                Layout.preferredWidth: window.s(32)
                                Layout.preferredHeight: window.s(32)
                                radius: window.s(16)
                                color: volIconMa.containsMouse ? "#1affffff" : "transparent"
                                border.color: volIconMa.containsMouse ? window.profileStart : "transparent"
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: window.sysMuted || window.sysVolume === 0 ? "󰖁" : (window.sysVolume > 50 ? "󰕾" : "󰖀")
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: window.s(22)
                                    color: window.sysMuted ? window.overlay0 : window.profileStart
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                                MouseArea {
                                    id: volIconMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        volSyncDelay.stop();
                                        window.isDraggingVol = true; 
                                        window.sysMuted = !window.sysMuted;
                                        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
                                        volSyncDelay.restart();
                                    }
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                height: window.s(18)
                                
                                Timer {
                                    id: volCmdThrottle
                                    interval: 50
                                    property int targetPct: -1
                                    onTriggered: {
                                        if (targetPct >= 0) {
                                            if (targetPct > 0 && window.sysMuted) {
                                                window.sysMuted = false;
                                                Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "0"]);
                                            }
                                            Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", targetPct + "%"]);
                                            targetPct = -1;
                                        }
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: window.s(9)
                                    color: "#0dffffff"
                                    border.color: "#1affffff"
                                    border.width: 1
                                    clip: true

                                    Rectangle {
                                        height: parent.height
                                        width: parent.width * (window.sysVolume / 100)
                                        radius: window.s(9)
                                        opacity: window.sysMuted ? 0.5 : (volMa.containsMouse ? 1.0 : 0.85)
                                        Behavior on opacity { NumberAnimation { duration: 200 } }
                                        Behavior on width { enabled: !window.isDraggingVol; NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }

                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop { position: 0.0; color: window.sysMuted ? window.surface2 : window.profileStart; Behavior on color { ColorAnimation { duration: 300 } } }
                                            GradientStop { position: 1.0; color: window.sysMuted ? Qt.lighter(window.surface2, 1.15) : window.profileEnd; Behavior on color { ColorAnimation { duration: 300 } } }
                                        }
                                    }
                                }
                                MouseArea {
                                    id: volMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: (mouse) => { volSyncDelay.stop(); window.isDraggingVol = true; updateVol(mouse.x); }
                                    onPositionChanged: (mouse) => { if (pressed) updateVol(mouse.x); }
                                    onReleased: { volSyncDelay.restart(); }
                                    
                                    function updateVol(mx) {
                                        let pct = Math.max(0, Math.min(100, Math.round((mx / width) * 100)));
                                        window.sysVolume = pct;
                                        volCmdThrottle.targetPct = pct;
                                        if (!volCmdThrottle.running) volCmdThrottle.start();
                                    }
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: window.s(75)
                    spacing: window.s(12)
                    
                    Repeater {
                        model: ListModel {
                            ListElement { cmd: "bash ~/.config/hypr/scripts/lock.sh"; icon: ""; baseColor: "mauve"; weight: 1.0 }
                            ListElement { cmd: "bash ~/.config/hypr/scripts/lock.sh & systemctl suspend"; icon: "ᶻ 𝗓 𐰁"; baseColor: "blue"; weight: 1.0 }
                            ListElement { cmd: "systemctl reboot"; icon: "󰑓"; baseColor: "yellow"; weight: 2.5 }
                            ListElement { cmd: "systemctl poweroff -i"; icon: ""; baseColor: "red"; weight: 3.5 }
                        }
                        
                        delegate: Rectangle {
                            id: actionCapsule
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: window.s(14)

                            opacity: introActions
                            transform: Translate { y: window.s(30) * (1.0 - introActions) + (index * window.s(12) * (1.0 - introActions)) }
                            
                            property color c1: window[baseColor] || window.surface1
                            property color c2: Qt.lighter(c1, 1.2)

                            color: actionMa.containsMouse ? "#1affffff" : "#0dffffff"
                            border.color: actionMa.containsMouse ? c1 : "#1affffff"
                            border.width: actionMa.containsMouse ? 2 : 1
                            Behavior on color { ColorAnimation { duration: 200 } }
                            Behavior on border.color { ColorAnimation { duration: 200 } }
                            
                            scale: actionMa.pressed ? (0.98 - (0.01 * weight)) : (actionMa.containsMouse ? 1.08 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutQuart } }

                            property real fillLevel: 0.0
                            property bool triggered: false
                            property real flashOpacity: 0.0
                            
                            Canvas {
                                id: actionWaveCanvas
                                anchors.fill: parent
                                
                                property real wavePhase: 0.0
                                NumberAnimation on wavePhase {
                                    running: actionCapsule.fillLevel > 0.0 && actionCapsule.fillLevel < 1.0
                                    loops: Animation.Infinite
                                    from: 0; to: Math.PI * 2; duration: 800
                                }
                                onWavePhaseChanged: requestPaint()
                                Connections { target: actionCapsule; function onFillLevelChanged() { actionWaveCanvas.requestPaint() } }
                                
                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);
                                    if (actionCapsule.fillLevel <= 0.001) return;
                                    
                                    var r = window.s(14); 
                                    var fillY = height * (1.0 - actionCapsule.fillLevel);
                                    ctx.save();
                                    ctx.beginPath();
                                    ctx.moveTo(r, 0);
                                    ctx.lineTo(width - r, 0);
                                    ctx.arcTo(width, 0, width, r, r);
                                    ctx.lineTo(width, height - r);
                                    ctx.arcTo(width, height, width - r, height, r);
                                    ctx.lineTo(r, height);
                                    ctx.arcTo(0, height, 0, height - r, r);
                                    ctx.lineTo(0, r);
                                    ctx.arcTo(0, 0, r, 0, r);
                                    ctx.closePath();
                                    ctx.clip(); 
                                    
                                    ctx.beginPath();
                                    ctx.moveTo(0, fillY);
                                    if (actionCapsule.fillLevel < 0.99) {
                                        var waveAmp = window.s(10) * Math.sin(actionCapsule.fillLevel * Math.PI); 
                                        var cp1y = fillY + Math.sin(wavePhase) * waveAmp;
                                        var cp2y = fillY + Math.cos(wavePhase + Math.PI) * waveAmp;
                                        ctx.bezierCurveTo(width * 0.33, cp2y, width * 0.66, cp1y, width, fillY);
                                        ctx.lineTo(width, height);
                                        ctx.lineTo(0, height);
                                    } else {
                                        ctx.lineTo(width, 0);
                                        ctx.lineTo(width, height);
                                        ctx.lineTo(0, height);
                                    }
                                    ctx.closePath();
                                    
                                    var grad = ctx.createLinearGradient(0, 0, 0, height);
                                    grad.addColorStop(0, actionCapsule.c1.toString());
                                    grad.addColorStop(1, actionCapsule.c2.toString());
                                    ctx.fillStyle = grad;
                                    ctx.fill();
                                    ctx.restore();
                                }
                            }

                            Rectangle {
                                anchors.fill: parent; radius: window.s(14); color: "#ffffff"
                                opacity: actionCapsule.flashOpacity
                                PropertyAnimation on opacity { id: cardFlashAnim; to: 0; duration: 500; easing.type: Easing.OutExpo }
                            }

                            Text { 
                                anchors.centerIn: parent
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: window.s(24)
                                color: actionMa.containsMouse ? window.text : window.subtext0
                                text: icon
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            Item {
                                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                                height: actionCapsule.height * actionCapsule.fillLevel
                                clip: true
                                
                                Text { 
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: (actionCapsule.height / 2) - (height / 2) - (actionCapsule.height - parent.height)
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: window.s(24)
                                    color: window.crust
                                    text: icon 
                                }
                            }

                            MouseArea {
                                id: actionMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: actionCapsule.triggered ? Qt.ArrowCursor : Qt.PointingHandCursor
                                
                                onPressed: { 
                                    if (!actionCapsule.triggered) { 
                                        drainAnim.stop(); 
                                        fillAnim.start(); 
                                    }
                                }
                                onReleased: {
                                    if (!actionCapsule.triggered && actionCapsule.fillLevel < 1.0) { 
                                        fillAnim.stop(); 
                                        drainAnim.start(); 
                                    }
                                }
                            }

                            NumberAnimation {
                                id: fillAnim; target: actionCapsule; property: "fillLevel"; to: 1.0
                                duration: (550 * weight) * (1.0 - actionCapsule.fillLevel); easing.type: Easing.InSine
                                onFinished: {
                                    actionCapsule.triggered = true; actionCapsule.flashOpacity = 0.6; cardFlashAnim.start();
                                    exitAnim.start(); exitTimer.start();
                                }
                            }
                            
                            NumberAnimation {
                                id: drainAnim; target: actionCapsule; property: "fillLevel"; to: 0.0
                                duration: 1500 * actionCapsule.fillLevel; easing.type: Easing.OutQuad
                            }

                            Timer {
                                id: exitTimer; interval: 500 
                                onTriggered: { Quickshell.execDetached(["sh", "-c", cmd]); Quickshell.execDetached(["sh", "-c", "echo 'close' > /tmp/qs_widget_state"]); }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: window.s(54)
                    radius: window.s(14)
                    color: "#0dffffff" 
                    border.color: "#1affffff"
                    border.width: 1

                    opacity: introProfiles
                    transform: Translate { y: window.s(20) * (1.0 - introProfiles) }
                    
                    Rectangle {
                        id: sliderPill
                        width: (parent.width - window.s(2)) / 3 
                        height: parent.height - window.s(2)
                        y: window.s(1)
                        radius: window.s(10)
                        x: {
                            if (window.powerProfile === "performance") return window.s(1);
                            if (window.powerProfile === "balanced") return width + window.s(1);
                            return (width * 2) + window.s(1);
                        }
                        
                        Behavior on x { NumberAnimation { duration: 400; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                        
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: window.profileStart; Behavior on color { ColorAnimation{duration:400} } }
                            GradientStop { position: 1.0; color: window.profileEnd; Behavior on color { ColorAnimation{duration:400} } }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        spacing: 0
                        
                        Repeater {
                            model: ListModel {
                                ListElement { name: "performance"; icon: "󰓅"; label: "Perform" } 
                                ListElement { name: "balanced"; icon: "󰗑"; label: "Balance" }   
                                ListElement { name: "power-saver"; icon: "󰌪"; label: "Saver" } 
                            }
                            
                            delegate: Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                
                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: window.s(8)
                                    Text {
                                        font.family: "Iosevka Nerd Font"; font.pixelSize: window.s(18)
                                        color: window.powerProfile === name ? window.crust : (profileMa.containsMouse ? window.text : window.subtext0)
                                        text: icon
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
                                    Text {
                                        font.family: "JetBrains Mono"; font.weight: Font.Black; font.pixelSize: window.s(13)
                                        color: window.powerProfile === name ? window.crust : (profileMa.containsMouse ? window.text : window.subtext0)
                                        text: label
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
                                }
                                
                                MouseArea {
                                    id: profileMa
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { Quickshell.execDetached(["powerprofilesctl", "set", name]); sysPoller.running = true; }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
