const React = require("react");
const fs = require("node:fs");
const path = require("node:path");
const {
  List, ActionPanel, Action, Icon, showToast, Toast, useNavigation, Form
} = require("@vicinae/api");

const BOOKMARKS_PATH = path.join(process.env.HOME, ".config/microsoft-edge/Default/Bookmarks");
const NOTES_PATH = path.join(process.env.HOME, ".local/share/vicinae/extensions/bookmark-master/notes.json");

function loadNotes() {
  try {
    if (fs.existsSync(NOTES_PATH)) {
      return JSON.parse(fs.readFileSync(NOTES_PATH, "utf8"));
    }
  } catch (e) { console.error(e); }
  return {};
}

function saveNotes(notes) {
  try {
    fs.writeFileSync(NOTES_PATH, JSON.stringify(notes, null, 2));
  } catch (e) { showToast({ style: Toast.Style.Failure, title: "保存失败", message: e.message }); }
}

function parseBookmarks(node, folder = "", results = []) {
  if (node.type === "url") {
    results.push({
      id: node.id,
      name: node.name,
      url: node.url,
      folder: folder
    });
  } else if (node.type === "folder" && node.children) {
    const currentFolder = folder ? `${folder}/${node.name}` : node.name;
    node.children.forEach(child => parseBookmarks(child, currentFolder, results));
  }
  return results;
}

function EditNoteForm({ bookmark, currentNote, onSave }) {
  const { pop } = useNavigation();
  return React.createElement(
    Form,
    {
      actions: React.createElement(
        ActionPanel,
        null,
        React.createElement(Action.SubmitForm, {
          title: "保存备注",
          onSubmit: (values) => {
            onSave(values.note);
            pop();
          }
        })
      )
    },
    React.createElement(Form.Description, { text: `为书签添加备注: ${bookmark.name}` }),
    React.createElement(Form.TextField, { id: "note", title: "备注内容", defaultValue: currentNote || "" })
  );
}

function Command() {
  const [items, setItems] = React.useState([]);
  const [notes, setNotes] = React.useState({});
  const [searchText, setSearchText] = React.useState("");
  const { push } = useNavigation();

  React.useEffect(() => {
    try {
      if (fs.existsSync(BOOKMARKS_PATH)) {
        const data = JSON.parse(fs.readFileSync(BOOKMARKS_PATH, "utf8"));
        let allItems = [];
        Object.values(data.roots).forEach(root => {
          if (typeof root === "object") parseBookmarks(root, "", allItems);
        });
        setItems(allItems);
      }
      setNotes(loadNotes());
    } catch (e) {
      showToast({ style: Toast.Style.Failure, title: "加载书签失败", message: e.message });
    }
  }, []);

  const handleSaveNote = (url, newNote) => {
    const updatedNotes = { ...notes, [url]: newNote };
    setNotes(updatedNotes);
    saveNotes(updatedNotes);
    showToast({ title: "备注已更新" });
  };

  const search = searchText.toLowerCase();
  const filteredItems = items
    .map(it => ({ ...it, note: notes[it.url] || "" }))
    .filter(it => {
      if (!search) return true;
      return (
        it.name.toLowerCase().includes(search) ||
        it.url.toLowerCase().includes(search) ||
        it.folder.toLowerCase().includes(search) ||
        it.note.toLowerCase().includes(search)
      );
    })
    .sort((a, b) => {
      if (!search) return a.name.localeCompare(b.name);

      const aNoteMatch = a.note.toLowerCase().includes(search);
      const bNoteMatch = b.note.toLowerCase().includes(search);

      // 优先级 1: 备注匹配优先
      if (aNoteMatch && !bNoteMatch) return -1;
      if (!aNoteMatch && bNoteMatch) return 1;

      // 优先级 2: 字符集排序
      if (aNoteMatch && bNoteMatch) {
        return a.note.localeCompare(b.note);
      }
      return a.name.localeCompare(b.name);
    });

  return React.createElement(
    List,
    {
      onSearchTextChange: setSearchText,
      searchBarPlaceholder: "搜索书签、路径或自定义备注...",
      throttle: true
    },
    filteredItems.map(it => {
      return React.createElement(List.Item, {
        key: it.url + it.id,
        title: it.name,
        subtitle: it.url,
        accessories: it.note ? [{ text: it.note, icon: Icon.Tag, tooltip: "自定义备注" }] : [],
        actions: React.createElement(
          ActionPanel,
          null,
          React.createElement(Action.OpenInBrowser, { url: it.url }),
          React.createElement(Action, {
            title: "编辑备注",
            icon: Icon.Pencil,
            shortcut: { modifiers: ["cmd"], key: "e" },
            onAction: () => push(React.createElement(EditNoteForm, {
              bookmark: it,
              currentNote: it.note,
              onSave: (val) => handleSaveNote(it.url, val)
            }))
          }),
          React.createElement(Action.CopyToClipboard, { title: "复制 URL", content: it.url })
        )
      });
    })
  );
}

module.exports = { default: Command };
