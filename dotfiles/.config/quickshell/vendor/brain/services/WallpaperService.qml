pragma Singleton

// Brain_Shell WallpaperService shim — no-op 版。
// 原版联动 awww 壁纸切换；这里只提供信号签名，头像重载逻辑静默挂起。
// 来源：Brain_Shell (MIT) https://github.com/Brainitech/Brain_Shell
import QtQuick

QtObject {
    signal wallpaperApplied(string path)
}
