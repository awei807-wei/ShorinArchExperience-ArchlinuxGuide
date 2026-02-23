const { execSync, spawn } = require("node:child_process");
const { showHUD, showToast, Toast } = require("@vicinae/api");

const SCRIPT = "/home/shiyi/.config/waybar/scripts/longshot-sh/longshot-wf-recorder.sh";

module.exports = {
  default: async function Command() {
    try {
      const child = spawn("bash", [SCRIPT], {
        detached: true,
        stdio: "ignore",
      });
      child.unref();
      await showHUD("长截图已启动");
    } catch (e) {
      await showToast({
        style: Toast.Style.Failure,
        title: "启动失败",
        message: String(e.message),
      });
    }
  },
};