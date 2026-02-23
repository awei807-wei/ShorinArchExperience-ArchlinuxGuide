const { execSync, spawn } = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");
const { showHUD, getPreferenceValues, showToast, Toast } = require("@vicinae/api");

const PIDFILE = "/tmp/rec2gif.pid";
const TMPVIDEO = "/tmp/rec2gif.mp4";
const OUTPUT_DIR = path.join(process.env.HOME || "/home/shiyi", "Videos", "GIF");

module.exports = {
  default: async function Command() {
    const prefs = getPreferenceValues();
    const fps = prefs.fps || "15";
    const width = prefs.width || "640";

    // 第二次调用：停止 + 转换
    if (fs.existsSync(PIDFILE)) {
      const pid = fs.readFileSync(PIDFILE, "utf8").trim();
      fs.unlinkSync(PIDFILE);

      try { process.kill(Number(pid), "SIGINT"); } catch {}

      // 等 wf-recorder 写完文件
      await new Promise(r => setTimeout(r, 500));

      await showHUD("正在转换 GIF...");

      fs.mkdirSync(OUTPUT_DIR, { recursive: true });
      const ts = new Date().toISOString().replace(/[-:T]/g, "").slice(0, 15);
      const gif = path.join(OUTPUT_DIR, `${ts}.gif`);
      const pal = "/tmp/rec2gif_pal.png";

      try {
        execSync(
          `ffmpeg -y -i "${TMPVIDEO}" -vf "fps=${fps},scale=${width}:-1:flags=lanczos,palettegen=stats_mode=diff" "${pal}"`,
          { stdio: "ignore" }
        );
        execSync(
          `ffmpeg -y -i "${TMPVIDEO}" -i "${pal}" -lavfi "fps=${fps},scale=${width}:-1:flags=lanczos [x]; [x][1:v] paletteuse=dither=bayer:bayer_scale=5" "${gif}"`,
          { stdio: "ignore" }
        );

        try { fs.unlinkSync(TMPVIDEO); } catch {}
        try { fs.unlinkSync(pal); } catch {}

        // 复制文件路径到剪贴板（file URI）
        execSync(`echo -n "file://${gif}" | wl-copy -t text/uri-list`);

        const size = (fs.statSync(gif).size / 1024).toFixed(0);
        await showHUD(`✓ GIF 就绪 (${size}KB) → 剪贴板`);
      } catch (e) {
        await showToast({ style: Toast.Style.Failure, title: "转换失败", message: String(e.message) });
      }
      return;
    }

    // 第一次调用：框选 + 开始录屏
    let geom;
    try {
      geom = execSync("slurp", { encoding: "utf8" }).trim();
    } catch {
      await showHUD("已取消");
      return;
    }

    try { fs.unlinkSync(TMPVIDEO); } catch {}

    const rec = spawn("wf-recorder", ["-g", geom, "-f", TMPVIDEO, "--codec", "libx264", "-p", "preset=ultrafast"], {
      detached: true,
      stdio: "ignore",});
    rec.unref();

    fs.writeFileSync(PIDFILE, String(rec.pid));
    await showHUD("🔴 录屏中... 再次调用停止");
  },
};