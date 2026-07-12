import os
import subprocess
from datetime import datetime, timedelta

# --- 核心配置 ---
NAS_IP = "10.0.0.104"
NAS_REMOTE = "/mnt/user/115yun"
MOUNT_POINT = "/mnt/nas_vcp_backup"
SOURCE_DIR = "/home/shiyi/Downloads/VCPChat/AppData"
BACKUP_ROOT = f"{MOUNT_POINT}/archive/VCP/vcpchat_daily"
RETENTION_DAYS = 3

WHITELIST = [
    "Notemodules", "avatarimage", "generated_lists",
    "systemPromptPresets", "UserData", "Agents",
    "AgentGroups", "Translatormodules"
]

def run(cmd):
    # 增加调试信息打印
    return subprocess.run(cmd, shell=True, capture_output=True, text=True)

def is_mounted(path):
    return run(f"mountpoint -q {path}").returncode == 0

def mount_nas():
    if not os.path.exists(MOUNT_POINT):
        print(f"[*] 创建挂载点...")
        run(f"sudo mkdir -p {MOUNT_POINT}")
    if is_mounted(MOUNT_POINT):
        return True
    print(f"[*] 正在挂载 NAS...")
    # 增加 mount 成功率的参数
    res = run(f"sudo mount -t nfs {NAS_IP}:{NAS_REMOTE} {MOUNT_POINT} -o nolock,soft,timeo=50,retrans=2")
    return res.returncode == 0

def sync_with_rotation():
    today = datetime.now().strftime("%Y-%m-%d")
    today_dir = f"{BACKUP_ROOT}/{today}"
    latest_link = f"{BACKUP_ROOT}/latest"
    
    print(f"[*] 备份目标: {today_dir}")
    run(f"sudo mkdir -p {BACKUP_ROOT}")
    
    # 构建包含/排除规则
    include_args = " ".join([f"--include='/{d}/***'" for d in WHITELIST])
    # [优化] 使用 -rtv 替代 -a，避免 NFS 上的所有者权限错误 (code 23)
    rsync_filter = f"{include_args} --include='/*' --exclude='**/attachments/***' --exclude='*' "
    
    link_dest_cmd = f"--link-dest={latest_link}" if os.path.exists(latest_link) else ""
    
    print(f"[*] 正在同步数据...")
    # 显式使用 --no-owner --no-group 彻底解决权限报错
    cmd = f"rsync -rtv --no-owner --no-group {link_dest_cmd} {rsync_filter} {SOURCE_DIR}/ {today_dir}/"
    
    sync_res = run(cmd)
    if sync_res.returncode in [0, 24]: # 0是成功，24是同步时文件消失(通常是日志)，也可以接受
        run(f"rm -f {latest_link} && ln -s {today_dir} {latest_link}")
        print("[+] 同步成功！")
        cleanup_old_backups()
    else:
        print(f"[-] 同步失败 (Code {sync_res.returncode})")
        print(f"错误详情: {sync_res.stderr}")

def cleanup_old_backups():
    print(f"[*] 清理旧数据...")
    if not os.path.exists(BACKUP_ROOT): return
    threshold_date = datetime.now() - timedelta(days=RETENTION_DAYS)
    for folder in os.listdir(BACKUP_ROOT):
        folder_path = os.path.join(BACKUP_ROOT, folder)
        if not os.path.isdir(folder_path) or folder == "latest": continue
        try:
            if datetime.strptime(folder, "%Y-%m-%d") < threshold_date:
                print(f"[-] 清除: {folder}")
                run(f"rm -rf {folder_path}")
        except ValueError: continue

def umount_nas():
    print(f"[*] 卸载挂载点...")
    run(f"sudo umount -l {MOUNT_POINT}")

if __name__ == "__main__":
    if (os.path.exists(SOURCE_DIR)):
        if mount_nas():
            try:
               sync_with_rotation()
            finally:
                umount_nas()
        else:
             print("[-] 无法挂载 NAS，请检查网络或 sudo 权限。")
    else:
        pass
