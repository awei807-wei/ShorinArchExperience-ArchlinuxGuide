import { Gtk } from "astal/gtk3";
import { Variable, bind, exec, execAsync } from "astal";

// 工作区状态
const focusedIdx = Variable(1);
const workspaceCount = Variable(5);

// 轮询更新状态
setInterval(() => {
  try {
    const output = exec("niri msg -j workspaces");
    const wsList = JSON.parse(output);
    const sorted = wsList.sort((a: any, b: any) => a.idx - b.idx);
    const focusedWs = sorted.find((ws: any) => ws.is_focused);
    
    if (focusedWs) {
      focusedIdx.set(focusedWs.idx);
    }
    workspaceCount.set(sorted.length);
  } catch (e) {}
}, 300);

// 切换工作区
const focusWorkspace = (idx: number) => {
  execAsync(`niri msg action focus-workspace ${idx}`);
};

// 尺寸类型
interface FibSizes {
  wsBtnWidth: number;
  wsBtnActiveWidth: number;
  wsBtnHeight: number;
  wsBtnRadius: number;
  wsBtnSpacing: number;
  textSize: number;
}

// 单个按钮组件
function WsButton({ idx, sizes }: { idx: number; sizes: FibSizes }) {
  return (
    <button
      className={bind(focusedIdx).as(f => 
        idx === f ? "ws-btn active" : "ws-btn"
      )}
      visible={bind(workspaceCount).as(c => idx <= c)}
      onClicked={() => focusWorkspace(idx)}
      valign={Gtk.Align.CENTER}
      halign={Gtk.Align.CENTER}css={bind(focusedIdx).as(f => 
        idx === f 
          ? `min-width: ${sizes.wsBtnActiveWidth}px; min-height: ${sizes.wsBtnHeight}px; border-radius: ${Math.round(sizes.wsBtnRadius * 1.2)}px;`
          : `min-width: ${sizes.wsBtnWidth}px; min-height: ${sizes.wsBtnHeight}px; border-radius: ${sizes.wsBtnRadius}px;`
      )}
    >
      <label 
        label={String(idx)} 
        valign={Gtk.Align.CENTER}
        halign={Gtk.Align.CENTER}
        css={`font-size: ${sizes.textSize}px;`}
      />
    </button>
  );
}

// 主组件
export default function Workspaces({ sizes }: { sizes: FibSizes }) {
  return (
    <box className="workspaces-container" spacing={sizes.wsBtnSpacing} valign={Gtk.Align.CENTER}>
      {[1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map(i => (
        <WsButton idx={i} sizes={sizes} />
      ))}
    </box>
  );
}