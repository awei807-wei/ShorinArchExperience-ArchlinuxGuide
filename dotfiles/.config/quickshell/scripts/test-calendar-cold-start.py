#!/usr/bin/env python3
"""使用临时 HOME 和可控假下载器验证日历冷启动，不接触真实任务或缓存。"""

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


REPO = Path(__file__).resolve().parents[1]
HOLIDAY_FIXTURE = """#!/usr/bin/env python3
import datetime
import json
import os
from pathlib import Path
import sys
import time

home = Path(os.environ["HOME"])
if sys.argv[1] == "refresh":
    raise SystemExit(0)
deadline = time.monotonic() + 4
while not (home / "release-holidays").exists():
    if time.monotonic() > deadline:
        raise SystemExit("测试节假日数据未释放")
    time.sleep(0.005)
year = int(sys.argv[2])
today = datetime.date.today()
days = []
if year == today.year:
    days.append({"date": today.isoformat(), "name": "测试休息日", "isOffDay": True})
print(json.dumps({"year": year, "days": days}, ensure_ascii=False))
"""


def prepare_home(home):
    """准备假下载器和无个人数据的 Home 素材。"""
    script = home / ".config/scripts/quickshell-holidays.sh"
    script.parent.mkdir(parents=True)
    script.write_text(HOLIDAY_FIXTURE, encoding="utf-8")
    script.chmod(0o700)
    avatar = home / "avatar.svg"
    avatar.write_text('<svg xmlns="http://www.w3.org/2000/svg" width="72" height="72">'
                      '<circle cx="36" cy="36" r="36" fill="#8fb3c5"/></svg>', encoding="utf-8")
    wallpaper = home / ".cache/quickshell/wallpaper-state.json"
    wallpaper.parent.mkdir(parents=True)
    wallpaper.write_text(json.dumps({
        "source": str(avatar), "avatar": str(avatar), "updatedAt": "测试素材",
    }), encoding="utf-8")
    # 在异步壁纸状态加载前，ProfileCard 会先读取此缺省路径。
    (home / ".curr_wall_static.jpg").symlink_to(avatar)
    library = home / "Downloads/VCPChat/AppData/songlist.json"
    library.parent.mkdir(parents=True)
    library.write_text("[]", encoding="utf-8")


def test_environment(home, panel):
    """隔离缓存与持久数据；完整面板检查使用 Wayland。"""
    environment = dict(os.environ)
    environment.update({
        "HOME": str(home),
        "XDG_CONFIG_HOME": str(home / ".config"),
        "XDG_CACHE_HOME": str(home / ".cache"),
        "XDG_DATA_HOME": str(home / ".local/share"),
        "QUICKSHELL_TEST_MODE": "1",
        "QT_QPA_PLATFORM": os.environ.get("QT_QPA_PLATFORM", "wayland" if panel else "offscreen"),
        "QT_QPA_PLATFORMTHEME": "generic",
    })
    return environment


def main():
    """运行隔离检查；--panel 验证完整 Home 页与真实开合状态。"""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--panel", action="store_true", help="在 Wayland 会话验证完整中岛面板")
    args = parser.parse_args()
    entry = "center-panel-cold-start-check.qml" if args.panel else "calendar-cold-start-check.qml"
    with tempfile.TemporaryDirectory(prefix="quickshell-calendar-check-") as directory:
        home = Path(directory)
        prepare_home(home)
        try:
            result = subprocess.run(
                ["quickshell", "--no-color", "-p", str(REPO / entry)],
                cwd=REPO, env=test_environment(home, args.panel), timeout=10, check=False,
            )
        except subprocess.TimeoutExpired:
            print("日历冷启动检查超时", file=sys.stderr)
            return 1
        return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
