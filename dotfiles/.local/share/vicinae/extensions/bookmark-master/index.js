const React = require("react");
const fs = require("node:fs");
const path = require("node:path");
const { List, ActionPanel, Action, Icon, showToast, Toast, useNavigation, Form } = require("@vicinae/api");
const { execSync } = require("node:child_process");

const BOOKMARKS_PATH = path.join(process.env.HOME, ".config/microsoft-edge/Default/Bookmarks");

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

// 使用 Python 脚本修改书签标题，实现“寄生”写入
function saveNoteToEdge(url, newNote) {
  const pyScript = `
import json, os, re
path = os.path.expanduser("~/.config/microsoft-edge/Default/Bookmarks")
with open(path, 'r') as f: data = json.load(f)
def update(node):
    if node.get('type') == 'url' and node.get('url') == '${url}':
        clean = re.sub(r'\\s*\\[v:.*\\]$', '', node.get('name', ''))
        node['name'] = f"{clean} [v:${newNote}]" if '${newNote}' else clean
        return True
    for c in node.get('children', []):
        if update(c): return True
    return False
for r in data.get('roots', {}).values():
    if isinstance(r, dict) and update(r): break
with open(path, 'w') as f: json.dump(data, f, indent=2)
`;
  try {
    execSync(`python3 -c '${pyScript}'`);
    return true;
  } catch (e) {
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
      showToast({ style: Toast.Style.Failure, title: "同步失败" });
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
        React.createElement(Action.OpenInBrowser, { url: it.url }),
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
