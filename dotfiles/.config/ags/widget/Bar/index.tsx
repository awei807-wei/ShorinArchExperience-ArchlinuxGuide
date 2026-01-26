import { App, Astal, Gtk, Gdk } from "astal/gtk3";
import { Variable, bind, exec, execAsync, subprocess } from "astal";
import Workspaces from "./Workspaces";
import Tray from "gi://AstalTray";

// 时间 - 双排显示
const timeStr = Variable("").poll(1000, () => {
  const now = new Date();
  const hours = String(now.getHours()).padStart(2, "0");
  const minutes = String(now.getMinutes()).padStart(2, "0");
  return `${hours}:${minutes}`;
});

const dateStr = Variable("").poll(60000, () => {
  const now = new Date();
  const month = String(now.getMonth() + 1).padStart(2, "0");
  const day = String(now.getDate()).padStart(2, "0");
  const weekdays = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"];
  const weekday = weekdays[now.getDay()];
  return `${month}-${day} ${weekday}`;
});

const btStatus = Variable("off").poll(3000, () => {
  try {
    const output = exec("bluetoothctl show");
    return output.includes("Powered: yes") ? "on" : "off";
  } catch { return "off"; }
});

const toggleBluetooth = () => {
  try {
    const output = exec("bluetoothctl show");
    const isOn = output.includes("Powered: yes");
    execAsync(isOn ? "bluetoothctl power off" : "bluetoothctl power on");
  } catch { execAsync("bluetoothctl power on"); }
};

const wifiStatus = Variable("off").poll(3000, () => {
  try {
    const output = exec("nmcli -t -f TYPE,STATE device");
    return output.includes("wifi:connected") ? "on" : "off";
  } catch { return "off"; }
});

const volume = Variable({ vol: 50, muted: false, icon: "󰕾" }).poll(1000, () => {
  try {
    const output = exec("wpctl get-volume @DEFAULT_AUDIO_SINK@");
    const match = output.match(/Volume:\s*([\d.]+)/);
    const vol = match ? Math.round(parseFloat(match[1]) * 100) : 50;
    const muted = output.includes("[MUTED]");
    let icon = muted ? "󰖁" : vol > 66 ? "󰕾" : vol > 33 ? "󰖀" : "󰕿";
    return { vol, muted, icon };
  } catch { return { vol: 50, muted: false, icon: "󰕾" }; }
});

const adjustVolume = (delta: number) => {
  const direction = delta > 0 ? "+" : "-";
  execAsync(`wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%${direction} -l 1.0`);
  const current = volume.get();
  const newVol = delta > 0 ? Math.min(100, current.vol + 1) : Math.max(0, current.vol - 1);
  let icon = current.muted ? "󰖁" : newVol > 66 ? "󰕾" : newVol > 33 ? "󰖀" : "󰕿";
  volume.set({ vol: newVol, muted: current.muted, icon });
};

const battery = Variable({ percent: 100, icon: "󰁹", charging: false }).poll(5000, () => {
  try {
    const capacity = exec("cat /sys/class/power_supply/BAT0/capacity").trim();
    const status = exec("cat /sys/class/power_supply/BAT0/status").trim();
    const percent = parseInt(capacity) || 100;
    const charging = status === "Charging";
    let icon = charging ? "󰂄" : percent > 80 ? "󰁹" : percent > 60 ? "󰂁" : percent > 40 ? "󰁿" : percent > 20 ? "󰁻" : "󰂃";
    return { percent, icon, charging };
  } catch { return { percent: 100, icon: "󰁹", charging: false }; }
});

let prevIdle = 0, prevTotal = 0;
const cpuUsage = Variable(0).poll(2000, () => {
  try {
    const output = exec("cat /proc/stat");
    const line = output.split("\n")[0];
    const parts = line.split(/\s+/).slice(1).map(Number);
    const idle = parts[3] + parts[4];
    const total = parts.reduce((a, b) => a + b, 0);
    const diffIdle = idle - prevIdle;
    const diffTotal = total - prevTotal;
    prevIdle = idle;
    prevTotal = total;
    if (diffTotal === 0) return 0;
    return Math.round((1 - diffIdle / diffTotal) * 100);
  } catch { return 0; }
});

// 内存使用率
const memUsage = Variable(0).poll(3000, () => {
  try {
    const output = exec("cat /proc/meminfo");
    const lines = output.split("\n");
    let total = 0, available = 0;
    for (const line of lines) {
      if (line.startsWith("MemTotal:")) {
        total = parseInt(line.split(/\s+/)[1]);
      } else if (line.startsWith("MemAvailable:")) {
        available = parseInt(line.split(/\s+/)[1]);
      }
    }
    if (total === 0) return 0;
    return Math.round(((total - available) / total) * 100);
  } catch { return 0; }
});

// Cava 输出 - 直接显示
const cavaOutput = Variable("");
subprocess({
  cmd: ["/home/shiyi/.config/ags/scripts/cava.sh"],
  out: (line) => cavaOutput.set(line),
  err: () => {},
});

const tray = Tray.get_default();

// 斐波那契黄金比例计算
function calcFibonacciSizes(screenWidth: number) {
  const U = screenWidth / 89;
  return {
    barHeight: Math.round(U * 2),
    barPaddingTop: Math.round(U * 0.5),
    barPaddingX: Math.round(U * 0.5),
    islandPaddingY: Math.round(U * 0.2),
    islandPaddingX: Math.round(U * 0.5),
    islandRadius: Math.round(U * 0.5),
    islandSpacing: Math.round(U * 0.3),
    moduleSpacing: Math.round(U * 0.8),
    modulePadding: Math.round(U * 0.2),
    iconSize: Math.round(U * 0.8),
    textSize: Math.round(U * 0.55),
    clockSize: Math.round(U * 0.6),
    clockDateSize: Math.round(U * 0.4),
    launcherSize: Math.round(U * 1),
    circleSize: Math.round(U * 1.2),
    circleIconSize: Math.round(U * 0.5),
    circleThickness: Math.round(U * 0.15),
    wsBtnWidth: Math.round(U * 1.1),
    wsBtnActiveWidth: Math.round(U * 2.2),
    wsBtnHeight: Math.round(U * 1),
    wsBtnRadius: Math.round(U * 0.4),
    wsBtnSpacing: Math.round(U * 0.3),
    cavaSize: Math.round(U * 0.65),
    trayIconSize: Math.round(U * 0.8),
    powerIconSize: Math.round(U * 0.9),
  };
}

function generateDynamicCSS(s: ReturnType<typeof calcFibonacciSizes>) {
  return `
    .bar {
      min-height: ${s.barHeight}px;
      padding: ${s.barPaddingTop}px ${s.barPaddingX}px ${Math.round(s.barPaddingTop * 0.4)}px ${s.barPaddingX}px;
    }
    .island, .island-left, .island-center, .island-right-system, .island-right-tray, .island-right-power {
      padding: ${s.islandPaddingY}px ${s.islandPaddingX}px;border-radius: ${s.islandRadius}px;
      min-height: ${s.barHeight - s.islandPaddingY * 2}px;
    }
    .module {
      font-size: ${s.iconSize}px;
      padding: 0px ${Math.round(s.modulePadding * 0.5)}px;
    }
    .module-text {
      font-size: ${s.textSize}px;
    }
    .module-btn {
      padding: ${Math.round(s.modulePadding * 0.5)}px ${s.modulePadding}px;
      border-radius: ${Math.round(s.islandRadius * 0.6)}px;
    }
    .launcher {
      font-size: ${s.launcherSize}px;
    }
    .clock-time {
      font-size: ${s.clockSize}px;font-weight: 600;
    }
    .clock-date {
      font-size: ${s.clockDateSize}px;
      opacity: 0.7;
    }
    .circular-progress {
      min-width: ${s.circleSize}px;
      min-height: ${s.circleSize}px;
      font-size: ${s.circleThickness}px;
    }
    .circular-icon {
      font-size: ${s.circleIconSize}px;
    }
    .cava-spectrum {
      font-size: ${s.cavaSize}px;
    }
    .tray-item icon {
      font-size: ${s.trayIconSize}px;
      min-width: ${s.trayIconSize}px;
      min-height: ${s.trayIconSize}px;
    }
    .ws-btn {
      min-width: ${s.wsBtnWidth}px;
      min-height: ${s.wsBtnHeight}px;
      border-radius: ${s.wsBtnRadius}px;
    }
    .ws-btn.active {
      min-width: ${s.wsBtnActiveWidth}px;
      border-radius: ${Math.round(s.wsBtnRadius * 1.2)}px;
    }
    .ws-btn label {
      font-size: ${s.textSize}px;
    }
    .power-icon {
      font-size: ${s.powerIconSize}px;
    }`;
}

export default function Bar(gdkmonitor: Gdk.Monitor) {
  const geometry = gdkmonitor.get_geometry();
  const screenWidth = geometry.width;
  const sizes = calcFibonacciSizes(screenWidth);
  const dynamicCSS = generateDynamicCSS(sizes);

  const LeftIsland = () => (
    <box className="island island-left" valign={Gtk.Align.CENTER} css={`padding: ${sizes.islandPaddingY}px ${sizes.islandPaddingX}px;`}>
      <Workspaces sizes={sizes} />
    </box>
  );

  // 双排时钟组件
  const ClockWidget = () => (
    <box orientation={Gtk.Orientation.VERTICAL} valign={Gtk.Align.CENTER}>
      <label className="clock-time" label={bind(timeStr)} css={`font-size: ${sizes.clockSize}px;`} />
      <label className="clock-date" label={bind(dateStr)} css={`font-size: ${sizes.clockDateSize}px;`} />
    </box>
  );

  const CenterIsland = () => (
    <box className="island island-center" spacing={sizes.moduleSpacing} valign={Gtk.Align.CENTER}>
      <eventbox className="module-btn" onClick={toggleBluetooth} valign={Gtk.Align.CENTER}>
        <label className={bind(btStatus).as(s => s === "on" ? "module" : "module disabled")} label={bind(btStatus).as(s => s === "on" ? "󰂯" : "󰂲")} css={`font-size: ${sizes.iconSize}px;`} /></eventbox>
      <eventbox className="module-btn" onClick={() => execAsync("kitty -e nmtui")} valign={Gtk.Align.CENTER}>
        <label className={bind(wifiStatus).as(s => s === "on" ? "module" : "module disabled")} label={bind(wifiStatus).as(s => s === "on" ? "󰤨" : "󰤮")} css={`font-size: ${sizes.iconSize}px;`} />
      </eventbox>
      <eventbox className="module-btn" onClick={() => execAsync("fuzzel")} valign={Gtk.Align.CENTER}>
        <label className="launcher" label="󰣇" css={`font-size: ${sizes.launcherSize}px;`} />
      </eventbox>
      <ClockWidget />
    </box>
  );

  const CavaSpectrum = () => (
    <label className="cava-spectrum" label={bind(cavaOutput)} css={`font-size: ${sizes.cavaSize}px;`} />
  );

  const RightIslandSystem = () => (
    <box className="island island-right-system" spacing={sizes.moduleSpacing} valign={Gtk.Align.CENTER}>
      <CavaSpectrum />
      <eventbox className="module-btn" onClick={() => execAsync("pavucontrol")} onScroll={(_, event) => adjustVolume(event.delta_y < 0 ? 1 : -1)} valign={Gtk.Align.CENTER}>
        <box spacing={Math.round(sizes.modulePadding * 2)} valign={Gtk.Align.CENTER}>
          <label className={bind(volume).as(v => v.muted ? "module muted" : "module")} label={bind(volume).as(v => v.icon)} css={`font-size: ${sizes.iconSize}px;`} />
          <label className="module-text" label={bind(volume).as(v => `${v.vol}%`)} css={`font-size: ${sizes.textSize}px;`} />
        </box>
      </eventbox>
      <circularprogress
        className={bind(memUsage).as(m => m >= 85 ? "circular-progress memory-high" : "circular-progress memory")}
        value={bind(memUsage).as(m => m / 100)}
        rounded={false}
        css={`min-width: ${sizes.circleSize}px; min-height: ${sizes.circleSize}px; font-size: ${sizes.circleThickness}px;`}
      >
        <label className="circular-icon" label="󱤓" css={`font-size: ${sizes.circleIconSize}px;`} />
      </circularprogress>
      <circularprogress
        className={bind(cpuUsage).as(c => c >= 90 ? "circular-progress cpu-high" : "circular-progress cpu")}
        value={bind(cpuUsage).as(c => c / 100)}
        rounded={false}
        css={`min-width: ${sizes.circleSize}px; min-height: ${sizes.circleSize}px; font-size: ${sizes.circleThickness}px;`}
      >
        <label className="circular-icon" label="󰻠" css={`font-size: ${sizes.circleIconSize}px;`} />
      </circularprogress>
      <circularprogress
        className={bind(battery).as(b => b.charging ? "circular-progress battery-charging" : b.percent <= 20 ? "circular-progress battery-low" : "circular-progress battery")}
        value={bind(battery).as(b => b.percent / 100)}
        rounded={false}
        css={`min-width: ${sizes.circleSize}px; min-height: ${sizes.circleSize}px; font-size: ${sizes.circleThickness}px;`}
      >
        <label className="circular-icon" label={bind(battery).as(b => b.icon)} css={`font-size: ${sizes.circleIconSize}px;`} />
      </circularprogress>
    </box>
  );

  function TrayItem({ item }: { item: Tray.TrayItem }) {
    return (
      <menubutton className="tray-item" tooltipMarkup={bind(item, "tooltipMarkup")} usePopover={false} actionGroup={bind(item, "actionGroup").as(ag => ["dbusmenu", ag])} menuModel={bind(item, "menuModel")}>
        <icon gicon={bind(item, "gicon")} css={`font-size: ${sizes.trayIconSize}px; min-width: ${sizes.trayIconSize}px; min-height: ${sizes.trayIconSize}px;`} /></menubutton>
    );
  }

  const RightIslandTray = () => (
    <box className="island island-right-tray" spacing={Math.round(sizes.modulePadding * 2)} valign={Gtk.Align.CENTER}>
      {bind(tray, "items").as(items => items.map(item => <TrayItem item={item} />))}
    </box>
  );

  // 电源菜单岛屿
  const RightIslandPower = () => (
    <box className="island island-right-power" valign={Gtk.Align.CENTER}>
      <eventbox className="module-btn" onClick={() => execAsync("wlogout")} valign={Gtk.Align.CENTER}>
        <label className="power-icon" label="⏻" css={`font-size: ${sizes.powerIconSize}px;`} />
      </eventbox>
    </box>
  );

  return (
    <window
      className="Bar"
      gdkmonitor={gdkmonitor}
      exclusivity={Astal.Exclusivity.EXCLUSIVE}
      anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.LEFT | Astal.WindowAnchor.RIGHT}
      css={dynamicCSS}
    >
      <centerbox className="bar" css={`min-height: ${sizes.barHeight}px; padding: ${sizes.barPaddingTop}px ${sizes.barPaddingX}px ${Math.round(sizes.barPaddingTop * 0.4)}px ${sizes.barPaddingX}px;`}>
        <box halign={Gtk.Align.START}><LeftIsland /></box>
        <box halign={Gtk.Align.CENTER}><CenterIsland /></box>
        <box halign={Gtk.Align.END} spacing={sizes.islandSpacing}><RightIslandSystem /><RightIslandTray /><RightIslandPower /></box>
      </centerbox>
    </window>
  );
}
