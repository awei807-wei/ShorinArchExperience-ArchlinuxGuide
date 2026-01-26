import { App, Astal, Gdk, Gtk } from "astal/gtk3";
import style from "./style.scss";
import Bar from "./widget/Bar";

App.start({
  css: style,
  main() {
    const monitors = App.get_monitors();
    monitors.map(Bar);
  },
});