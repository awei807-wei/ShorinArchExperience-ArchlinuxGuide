# fd-rdd（Vicinae 本地扩展）

本扩展提供一个 Vicinae 命令视图，用于通过本机 `fd-rdd` HTTP API 搜索文件并直接打开。

## 安装（Linux）

Vicinae 会扫描本地扩展目录：

`~/.local/share/vicinae/extensions/`

将本目录安装为一个扩展包（目录名建议为 `fd-rdd`）：

```bash
mkdir -p ~/.local/share/vicinae/extensions
ln -s "$(pwd)" ~/.local/share/vicinae/extensions/fd-rdd
```

然后重启 Vicinae（或在设置里触发扩展重新加载，如有）。

## 使用

1. 在 Vicinae 设置里找到扩展命令 `fd-rdd Search`
2. 给该命令设置 alias=`fd`
3. 回到 Root Search，输入 `fd` 后按空格进入命令视图
4. 在命令视图输入查询词（支持通配符，例如 `(*test*.md)*`）
5. 回车打开选中的文件

## 配置

- `fd_rdd_port`：fd-rdd 监听端口（默认 `6060`）

