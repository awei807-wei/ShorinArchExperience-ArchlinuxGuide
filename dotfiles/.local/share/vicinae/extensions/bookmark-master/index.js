const React = require("react");
const fs = require("node:fs");
const path = require("node:path");
const { execFile } = require("node:child_process");
const { List, ActionPanel, Action, Icon, showToast, Toast, useNavigation, Form } = require("@vicinae/api");

const BROWSER_PATHS = [
    path.join(process.env.HOME, ".config/thorium/Default/Bookmarks"),
    path.join(process.env.HOME, ".config/microsoft-edge/Default/Bookmarks"),
    path.join(process.env.HOME, ".config/google-chrome/Default/Bookmarks")
];
const NOTES_PATH = path.join(__dirname, "notes.json");

function getBookmarksPath() {
    return BROWSER_PATHS.find(candidate => fs.existsSync(candidate));
}

function parseBookmarks(node, folder = "", results = []) {
    if (node.type === "url") {
        const rawName = node.name || "";
        const match = rawName.match(/(.*)\s*\[v:(.*)\]$/);
        const displayName = match ? match[1].trim() : rawName;
        const note = match ? match[2].trim() : "";
        results.push({ id: node.id, name: displayName, rawName: rawName, url: node.url, folder: folder, note: note });
    } else if (node.type === "folder" && node.children) {
        const currentFolder = folder ? `${folder}/${node.name}` : node.name;
        node.children.forEach(child => parseBookmarks(child, currentFolder, results));
    }
    return results;
}

function readBookmarks(bookmarksPath) {
    const data = JSON.parse(fs.readFileSync(bookmarksPath, "utf8"));
    const items = [];
    Object.values(data.roots || {}).forEach(root => {
        if (root && typeof root === "object") parseBookmarks(root, "", items);
    });
    return items;
}

function buildNotesSnapshot(items) {
    const notes = {};
    [...items]
        .sort((a, b) => a.url.localeCompare(b.url) || String(a.id).localeCompare(String(b.id)))
        .forEach(item => {
            if (item.note) notes[item.url] = item.note;
        });
    return notes;
}

function syncNotesSnapshot(items) {
    const nextContent = `${JSON.stringify(buildNotesSnapshot(items), null, 2)}\n`;
    const currentContent = fs.existsSync(NOTES_PATH) ? fs.readFileSync(NOTES_PATH, "utf8") : "";
    if (currentContent === nextContent) return false;

    const temporaryPath = `${NOTES_PATH}.tmp`;
    try {
        fs.writeFileSync(temporaryPath, nextContent, "utf8");
        fs.renameSync(temporaryPath, NOTES_PATH);
    } finally {
        if (fs.existsSync(temporaryPath)) fs.unlinkSync(temporaryPath);
    }
    return true;
}

function saveNoteToBrowser(url, newNote) {
    try {
        const bookmarksPath = getBookmarksPath();
        if (!bookmarksPath) return false;
        const data = JSON.parse(fs.readFileSync(bookmarksPath, "utf8"));
        let found = false;
        function updateNode(node) {
            if (node.type === "url" && node.url === url) {
                const cleanName = (node.name || "").replace(/\s*\[v:.*\]$/, "");
                node.name = newNote ? `${cleanName} [v:${newNote}]` : cleanName;
                found = true;
                return true;
            }
            if (node.children) {
                for (const child of node.children) { if (updateNode(child)) return true; }
            }
            return false;
        }
        for (const root of Object.values(data.roots)) { if (typeof root === "object" && updateNode(root)) break; }
        if (found) {
            fs.writeFileSync(bookmarksPath, JSON.stringify(data, null, 2), "utf8");
            return true;
        }
        return false;
    } catch (error) {
        console.error("更新浏览器书签备注失败:", error);
        return false;
    }
}

function EditNoteForm({ bookmark, onSave }) {
    const { pop } = useNavigation();
    return React.createElement(Form, {
        actions: React.createElement(ActionPanel, null, React.createElement(Action.SubmitForm, { title: "保存并同步", onSubmit: (values) => { onSave(values.note); pop(); } }))
    }, React.createElement(Form.Description, { text: `备注将寄生在书签标题中，随账号同步。` }), React.createElement(Form.TextField, { id: "note", title: "备注内容", defaultValue: bookmark.note || "" }));
}

function Command() {
    const [items, setItems] = React.useState([]);
    const [searchText, setSearchText] = React.useState("");
    const bookmarksVersion = React.useRef("");
    const { push } = useNavigation();

    const refreshBookmarks = React.useCallback(({ force = false, reportErrors = true } = {}) => {
        const bookmarksPath = getBookmarksPath();
        if (!bookmarksPath) {
            const error = new Error("未找到 Thorium、Edge 或 Chrome 的书签文件");
            console.error(error.message);
            if (reportErrors) showToast({ style: Toast.Style.Failure, title: "加载书签失败", message: error.message });
            return;
        }

        try {
            const fileStat = fs.statSync(bookmarksPath);
            const nextVersion = `${bookmarksPath}:${fileStat.mtimeMs}:${fileStat.size}`;
            if (!force && bookmarksVersion.current === nextVersion) return;

            const latestItems = readBookmarks(bookmarksPath);
            setItems(latestItems);
            bookmarksVersion.current = nextVersion;

            try {
                syncNotesSnapshot(latestItems);
            } catch (error) {
                console.error("更新 notes.json 失败:", error);
                if (reportErrors) showToast({ style: Toast.Style.Failure, title: "备注镜像更新失败", message: error.message });
            }
        } catch (error) {
            console.error("加载浏览器书签失败:", error);
            if (reportErrors) showToast({ style: Toast.Style.Failure, title: "加载书签失败", message: error.message });
        }
    }, []);

    React.useEffect(() => { refreshBookmarks({ force: true }); }, [refreshBookmarks]);

    const handleSearchTextChange = React.useCallback((value) => {
        setSearchText(value);
        refreshBookmarks({ reportErrors: false });
    }, [refreshBookmarks]);

    const handleSaveNote = (url, newNote) => {
        if (saveNoteToBrowser(url, newNote)) { showToast({ title: "同步成功" }); refreshBookmarks({ force: true }); }
        else { showToast({ style: Toast.Style.Failure, title: "同步失败" }); }
    };
    const search = searchText.toLowerCase();
    const filteredItems = items.filter(it => !search || it.name.toLowerCase().includes(search) || it.url.toLowerCase().includes(search) || it.note.toLowerCase().includes(search))
        .sort((a, b) => {
            if (!search) return a.name.localeCompare(b.name);
            const aMatch = a.note.toLowerCase().includes(search), bMatch = b.note.toLowerCase().includes(search);
            return aMatch === bMatch ? a.name.localeCompare(b.name) : (aMatch ? -1 : 1);
        });
    return React.createElement(List, { onSearchTextChange: handleSearchTextChange, searchBarPlaceholder: "搜索书签或备注...", throttle: true },
        filteredItems.map(it => React.createElement(List.Item, {
            key: it.url + it.id, title: it.name, subtitle: it.url, accessories: it.note ? [{ text: it.note, icon: Icon.Tag }] : [],
            actions: React.createElement(ActionPanel, null,
                React.createElement(Action, {
                    title: "在 Thorium 中打开",
                    icon: Icon.Globe,
                    onAction: () => {
                        execFile("thorium-browser", [it.url], (error) => {
                            if (error) {
                                showToast({
                                    style: Toast.Style.Failure,
                                    title: "无法启动 Thorium",
                                    message: error.message,
                                });
                            }
                        });
                        setTimeout(() => {
                            execFile("niri", ["msg", "-j", "windows"], (error, stdout) => {
                                if (error) {
                                    console.error("读取 niri 窗口列表失败:", error);
                                    return;
                                }
                                try {
                                    const windows = JSON.parse(stdout);
                                    const browserWin = windows.find(w => w.app_id && w.app_id.toLowerCase() === "thorium-browser");
                                    if (browserWin) {
                                        execFile("niri", ["msg", "action", "focus-window", "--id", String(browserWin.id)]);
                                    }
                                } catch (error) {
                                    console.error("解析 niri 窗口列表失败:", error);
                                }
                            });
                        }, 150);
                    },
                }),
                React.createElement(Action, { title: "编辑备注", icon: Icon.Pencil, onAction: () => push(React.createElement(EditNoteForm, { bookmark: it, onSave: (val) => handleSaveNote(it.url, val) })) })
            )
        }))
    );
}
module.exports = { default: Command };
