# ShorinArch Dotfiles

基于 Arch Linux + Niri 合成器的桌面环境配置文件集。

> Forked from [SHORiN-KiWATA/ShorinArchExperience-ArchlinuxGuide](https://github.com/SHORiN-KiWATA/ShorinArchExperience-ArchlinuxGuide)

## 概览

| 类别 | 内容 |
|---|---|
| **合成器** | Niri (滚动式 Wayland 合成器) |
| **状态栏** | Waybar / Waybar Win11 风格 / Quickshell |
| **锁屏** | Quickshell (QML 实现) |
| **启动器** | Fuzzel / Wofi / Ulauncher |
| **终端** | Kitty / Ghostty |
| **主题配色** | Matugen (基于壁纸的 Material You 配色) |
| **通知** | Mako / SwayNC |
| **输入法** | Fcitx5 |
| **Shell** | Fish |
| **截图** | Grim + Slurp + Satty (含长截图工具链) |
| **录屏** | wf-recorder |
| **快照备份** | Snapper + btrfs |

## 目录结构

```
dotfiles/
├── .config/
│   ├── niri/              # Niri 合成器配置 (KDL 模块化)
│   ├── waybar/            # Waybar 状态栏
│   ├── waybar-niri-Win11Like/  # Win11 风格 Waybar
│   ├── quickshell/        # QML 面板 / 锁屏
│   ├── matugen/           # 配色方案与模板
│   ├── scripts/           # 通用脚本 (快照、壁纸、配色切换等)
│   ├── kitty/             # Kitty 终端
│   ├── ghostty/           # Ghostty 终端
│   ├── fish/              # Fish Shell
│   ├── fcitx5/            # 中文输入法
│   ├── fuzzel/            # Fuzzel 启动器
│   ├── wofi/              # Wofi 启动器
│   ├── mako/              # Mako 通知守护进程
│   ├── swaync/            # SwayNC 通知中心
│   ├── swaylock/          # 锁屏
│   ├── wlogout/           # 注销菜单
│   ├── btop/              # 系统监控
│   ├── fastfetch/         # 系统信息
│   ├── yazi/              # 终端文件管理器
│   ├── mpv/               # 视频播放器
│   ├── cava/              # 音频频谱
│   ├── gtk-3.0/ gtk-4.0/ # GTK 主题
│   ├── qt5ct/ qt6ct/      # Qt 主题
│   ├── fontconfig/        # 字体配置
│   └── ...
│   └── wallpapers/        # 壁纸
└── scripts -> .config/scripts/
```

## 截图

![Niri + Win11 风格 Waybar](pictures/waybar-bottom-niri.png)

## 许可

[CC BY-SA 4.0](LICENSE)
