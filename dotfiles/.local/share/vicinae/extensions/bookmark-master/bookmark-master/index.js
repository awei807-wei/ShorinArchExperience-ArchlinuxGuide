const React = require("react");
const fs = require("node:fs");
const path = require("node:path");
const { exec } = require("node:child_process");
const { List, ActionPanel, Action, Icon, showToast, Toast, useNavigation, Form } = require("@vicinae/api");

// 自动检测浏览器书签路径（优先级：Thorium > Edge > Chrome）
const BROWSER_PATHS = [
  path.join(process.env.HOME, ".config/thorium/Default/Bookmarks"),
  path.join(process.env.HOME, ".config/microsoft-edge/Default/Bookmarks"),
  path.join(process.env.HOME, ".config/google-chrome/Default/Bookmarks")
];
const BOOKMARKS_PATH = BROWSER_PATHS.find(p => fs.existsSync(p)) || BROWSER_PATHS[0];

function parseBookmarks(node, folder = "", results = []) {
  if (node.type === "url") {
    const rawName = node.name || "";
    const match = rawName.match(/(.*)\s*\[v:(.*)\]$/);
    const displayName = match ? match[1].trim() : rawName;
    const note = match ? match[2].trim() : "";

    results.push({
      id: node.id,
      name: displayName,
      rawName: rawName,
      url: node.url,
      folder: folder,
      note: note
    });
  } else if (node.type === "folder" && node.children) {
    const currentFolder = folder ? `${folder}/${node.name}` : node.name;
    node.children.forEach(child => parseBookmarks(child, currentFolder, results));
  }
  return results;
}

function saveNoteToEdge(url, newNote) {
  try {
    if (!fs.existsSync(BOOKMARKS_PATH)) return false;
    const data = JSON.parse(fs.readFileSync(BOOKMARKS_PATH, "utf8"));
    
    let found = false;
    function updateNode(node) {
      if (node.type === "url" && node.url === url) {
        const cleanName = (node.name || "").replace(/\s*\[v:.*\]$/, "");
        node.name = newNote ? `${cleanName} [v:${newNote}]` : cleanName;
        found = true;
        return true;
      }
      if (node.children) {
        for (const child of node.children) {
          if (updateNode(child)) return true;
        }
      }
      return false;
    }

    for (const root of Object.values(data.roots)) {
      if (typeof root === "object" && updateNode(root)) break;
    }

    if (found) {
      fs.writeFileSync(BOOKMARKS_PATH, JSON.stringify(data, null, 2), "utf8");
      return true;
    }
    return false;
  } catch (e) {
    console.error("写入书签失败:", e);
    return false;
  }
}

function EditNoteForm({ bookmark, onSave }) {
  const { pop } = useNavigation();
  return React.createElement(
    Form,
    {
      actions: React.createElement(
        ActionPanel,
        null,
        React.createElement(Action.SubmitForm, {
          title: "保存并同步",
          onSubmit: (values) => {
            onSave(values.note);
            pop();
          }
        })
      )
    },
    React.createElement(Form.Description, { text: `备注将寄生在书签标题中，随账号同步。` }),
    React.createElement(Form.TextField, { id: "note", title: "备注内容", defaultValue: bookmark.note || "" })
  );
}

function Command() {
  const [items, setItems] = React.useState([]);
  const [searchText, setSearchText] = React.useState("");
  const { push } = useNavigation();

  const loadData = () => {
    try {
      if (fs.existsSync(BOOKMARKS_PATH)) {
        const data = JSON.parse(fs.readFileSync(BOOKMARKS_PATH, "utf8"));
        let allItems = [];
        Object.values(data.roots).forEach(root => {
          if (typeof root === "object") parseBookmarks(root, "", allItems);
        });
        setItems(allItems);
      }
    } catch (e) {
      showToast({ style: Toast.Style.Failure, title: "加载失败" });
    }
  };

  React.useEffect(() => { loadData(); }, []);

  const handleSaveNote = (url, newNote) => {
    if (saveNoteToEdge(url, newNote)) {
      showToast({ title: "同步成功", message: "备注已存入书签标题" });
      loadData();
    } else {
      showToast({ style: Toast.Style.Failure, title: "同步失败", message: "请检查书签文件是否被占用" });
    }
  };

  const search = searchText.toLowerCase();
  const filteredItems = items
    .filter(it => {
      if (!search) return true;
      return it.name.toLowerCase().includes(search) || 
             it.url.toLowerCase().includes(search) || 
             it.note.toLowerCase().includes(search);
    })
    .sort((a, b) => {
      if (!search) return a.name.localeCompare(b.name);
      const aMatch = a.note.toLowerCase().includes(search);
      const bMatch = b.note.toLowerCase().includes(search);
      if (aMatch && !bMatch) return -1;
      if (!aMatch && bMatch) return 1;
      return a.name.localeCompare(b.name);
    });

  return React.createElement(
    List,
    { onSearchTextChange: setSearchText, searchBarPlaceholder: "搜索书签或备注...", throttle: true },
    filteredItems.map(it => React.createElement(List.Item, {
      key: it.url + it.id,
      title: it.name,
      subtitle: it.url,
      accessories: it.note ? [{ text: it.note, icon: Icon.Tag }] : [],
      actions: React.createElement(
        ActionPanel,
        null,
        React.createElement(Action, {
          title: "在 Thorium 中打开",
          icon: Icon.Globe,
          onAction: () => exec(`thorium-browser "${it.url}"`)
        }),
        React.createElement(Action, {
          title: "编辑备注",
          icon: Icon.Pencil,
          onAction: () => push(React.createElement(EditNoteForm, { bookmark: it, onSave: (val) => handleSaveNote(it.url, val) }))
        })
      )
    }))
  );
}

module.exports = { default: Command };
