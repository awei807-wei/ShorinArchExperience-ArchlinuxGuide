const assert = require("node:assert/strict");
const fs = require("node:fs");
const Module = require("node:module");
const test = require("node:test");

function component(name) {
    const value = function MockComponent() {};
    value.displayName = name;
    return value;
}

const ReactMock = {
    createElement(type, props, ...children) {
        return { type, props: { ...props, children } };
    },
    useRef(value) {
        return { current: value };
    },
    useState(value) {
        return [value, () => {}];
    },
};

const Form = component("Form");
Form.Description = component("Form.Description");
Form.TextField = component("Form.TextField");
const Action = component("Action");
Action.SubmitForm = component("Action.SubmitForm");
const ApiMock = {
    Action,
    ActionPanel: component("ActionPanel"),
    Form,
    showToast() {},
    Toast: { Style: { Animated: "animated", Failure: "failure", Success: "success" } },
};

test("Vicinae 命令可加载并渲染三个表单字段", () => {
    const originalLoad = Module._load;
    Module._load = function mockLoad(request, parent, isMain) {
        if (request === "react") return ReactMock;
        if (request === "@vicinae/api") return ApiMock;
        return originalLoad.call(this, request, parent, isMain);
    };

    let extension;
    try {
        delete require.cache[require.resolve("./index")];
        extension = require("./index");
    } finally {
        Module._load = originalLoad;
    }

    assert.equal(typeof extension.default, "function");
    const tree = extension.default();
    assert.equal(tree.type, Form);
    const fields = tree.props.children.filter((child) => child.type === Form.TextField);
    assert.deepEqual(fields.map((field) => field.props.id), ["phrase", "code", "weight"]);
    assert.equal(fields[0].props.autoFocus, true);
    assert.equal(tree.props.navigationTitle, "添加 Rime 双拼短语");
});

test("扩展清单标题无乱码", () => {
    const manifest = JSON.parse(fs.readFileSync(require.resolve("./package.json"), "utf8"));
    assert.equal(manifest.commands[0].title, "添加 Rime 双拼短语");
    assert.doesNotMatch(JSON.stringify(manifest), /�/u);
});
