import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import "../../components"
import "../../core"

Item {
    id: root

    // Ширина теперь плавно следует за реальным размером контента
    implicitWidth: animatedContent.width
    implicitHeight: 30

    // Dynamic Island integration
    opacity: IslandState.isActive ? 0.0 : 1.0
    scale: IslandState.isActive ? 0.95 : 1.0
    Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutQuad } }
    Behavior on scale { NumberAnimation { duration: 500; easing.type: Easing.OutBack } }

    Behavior on implicitWidth { 
        NumberAnimation { 
            duration: 600
            easing.type: Easing.OutQuint 
        } 
    }

    property string activeTitle: WindowState.activeTitle
    property string activeClass: WindowState.activeClass

    // ─── Состояния для анимации ──────────────────────────────────────
    property string displayedTitle: activeTitle
    property string displayedClass: activeClass
    
    // Вспомогательные свойства для эффектов
    property real contentOpacity: 1.0
    property real contentBlur: 0.0
    property real contentScale: 1.0
    property real contentY: 0.0

    onActiveTitleChanged: titleTransition.restart()
    onActiveClassChanged: titleTransition.restart()

    // ─── Контейнер с контентом ──────────────────────────────────────
    Item {
        id: animatedContent
        width: contentRow.implicitWidth
        height: 30
        anchors.verticalCenter: parent.verticalCenter
        
        opacity: root.contentOpacity
        scale: root.contentScale
        y: root.contentY

        layer.enabled: root.contentBlur > 0.01
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 24
            blur: root.contentBlur
        }

        Row {
            id: contentRow
            spacing: 12
            anchors.verticalCenter: parent.verticalCenter

            // Иконка (Nerd Font)
            AppText {
                id: nerdIcon
                visible: root.hasIcon && root.displayedIconType === "nerd"
                text: root.displayedIconValue
                color: Theme.textDark
                font {
                    pixelSize: 18
                    family: Theme.fontIcon
                }
                anchors.verticalCenter: parent.verticalCenter
            }

            // Иконка (Image)
            Image {
                id: imageIcon
                visible: root.hasIcon && root.displayedIconType === "image"
                source: visible ? "/home/fish/.config/quickshell/assets/app-icons/" + root.displayedIconValue : ""
                width: 20
                height: 20
                fillMode: Image.PreserveAspectFit
                anchors.verticalCenter: parent.verticalCenter
                smooth: true
                mipmap: true
            }

            // Текст заголовка
            AppText {
                id: titleText
                visible: !root.hasIcon 
                anchors.verticalCenter: parent.verticalCenter

                text: root.displayedTitle
                color: Theme.textDark
                font {
                    pixelSize: 13
                    weight: Font.DemiBold
                }

                width: Math.min(350, implicitWidth)
                elide: Text.ElideRight
            }
        }
    }

    // ─── Продвинутая анимация ─────────────────────────────────────────
    SequentialAnimation {
        id: titleTransition

        // Фаза 1: Очень мягкое, «ленивое» исчезновение
        ParallelAnimation {
            NumberAnimation { target: root; property: "contentOpacity"; to: 0.0; duration: 500; easing.type: Easing.InOutQuint }
            NumberAnimation { target: root; property: "contentBlur"; to: 1.0; duration: 500; easing.type: Easing.InOutQuint }
            NumberAnimation { target: root; property: "contentScale"; to: 0.96; duration: 600; easing.type: Easing.InOutQuint }
            NumberAnimation { target: root; property: "contentY"; to: 6; duration: 600; easing.type: Easing.InOutQuint }
        }

        ScriptAction {
            script: {
                root.displayedTitle = root.activeTitle
                root.displayedClass = root.activeClass
            }
        }
        
        PauseAnimation { duration: 100 }

        // Фаза 2: Глубокое и плавное всплытие
        ParallelAnimation {
            NumberAnimation { target: root; property: "contentOpacity"; to: 1.0; duration: 600; easing.type: Easing.OutQuint }
            NumberAnimation { target: root; property: "contentBlur"; to: 0.0; duration: 800; easing.type: Easing.OutQuint }
            NumberAnimation { target: root; property: "contentY"; from: -6; to: 0; duration: 850; easing.type: Easing.OutExpo }
            NumberAnimation { 
                target: root; 
                property: "contentScale"; 
                from: 1.05; 
                to: 1.0; 
                duration: 900; 
                easing.type: Easing.OutElastic; 
                easing.amplitude: 0.3; 
                easing.period: 1.0 
            }
        }
    }

    // ─── Маппинг иконок и логика ──────────────────────────────────
    readonly property var iconMap: ({
        "zen-alpha":      { type: "nerd", icon: "󰖟" },
        "zen":            { type: "nerd", icon: "󰖟" },
        "firefox":        { type: "nerd", icon: "󰖟" },
        "chromium":       { type: "nerd", icon: "󰖟" },    
        "google-chrome":  { type: "nerd", icon: "󰖟" },    
        "kitty":          { type: "nerd", icon: "󰞷" },
        "Alacritty":      { type: "nerd", icon: "󰞷" },    
        "foot":           { type: "nerd", icon: "󰞷" },    
        "org.gnome.Nautilus": { type: "nerd", icon: "󰉋" }, 
        "thunar":         { type: "nerd", icon: "󰉋" },    
        "Thunar":         { type: "nerd", icon: "󰉋" },    
        "telegram-desktop": { type: "image", icon: "telegram.png" },  
        "discord":        { type: "nerd", icon: "󰙯" },    
        "code":           { type: "nerd", icon: "󰨞" },    
        "Code":           { type: "nerd", icon: "󰨞" },
        "Spotify":        { type: "nerd", icon: "󰓇" },    
        "spotify":        { type: "nerd", icon: "󰓇" },
        "Steam":          { type: "nerd", icon: "󰓓" },    
        "steam":          { type: "nerd", icon: "󰓓" },
        "mpv":            { type: "nerd", icon: "󰐊" },
        "obsidian":       { type: "image", icon: "obsidian.png" },
        "Obsidian":       { type: "image", icon: "obsidian.png" },
    })

    readonly property var titleIconMap: [
        { pattern: "YouTube",    type: "nerd",  icon: "󰗃" },     
        { pattern: "Telegram",   type: "image", icon: "telegram.png" },
        { pattern: "Gemini",     type: "image", icon: "gemini.png" },
        { pattern: "Antigravity",type: "image", icon: "antigravity.png" },
        { pattern: "ChatGPT",    type: "nerd",  icon: "󰧑" },     
        { pattern: "GitHub",     type: "nerd",  icon: "󰊤" },      
        { pattern: "Reddit",     type: "nerd",  icon: "󰑍" },     
    ]

    function getAppInfo(wclass, wtitle) {
        for (let i = 0; i < titleIconMap.length; i++) {
            if (wtitle && wtitle.indexOf(titleIconMap[i].pattern) !== -1) {
                return { type: titleIconMap[i].type, icon: titleIconMap[i].icon };
            }
        }
        if (wclass && iconMap[wclass]) return iconMap[wclass];
        return null;
    }

    property var displayedInfo: getAppInfo(displayedClass, displayedTitle)
    property bool hasIcon: displayedInfo !== null
    property string displayedIconType: hasIcon ? displayedInfo.type : ""
    property string displayedIconValue: hasIcon ? displayedInfo.icon : ""
}
