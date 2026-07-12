const React = require("react");
const path = require("node:path");
const { execFile } = require("node:child_process");
const { Action, ActionPanel, Form, showToast, Toast } = require("@vicinae/api");
const { PhraseValidationError, normalizeEntry, writePhraseFile } = require("./phrase-store");

const RIME_USER_DIR = process.env.RIME_USER_DIR
    || path.join(process.env.HOME, ".local/share/fcitx5/rime");
const RIME_SHARED_DIR = process.env.RIME_SHARED_DIR || "/usr/share/rime-data";
const RIME_BUILD_DIR = process.env.RIME_BUILD_DIR || path.join(RIME_USER_DIR, "build");
const PHRASE_PATH = process.env.RIME_PHRASE_FILE
    || path.join(RIME_USER_DIR, "custom_phrase_double.txt");

function summarizeError(error) {
    return String(error?.message || error || "未知错误").replace(/\s+/gu, " ").slice(0, 240);
}

function runCommand(command, args, options = {}) {
    return new Promise((resolve, reject) => {
        execFile(command, args, {
            encoding: "utf8",
            maxBuffer: 4 * 1024 * 1024,
            timeout: 120_000,
            ...options,
        }, (error, stdout, stderr) => {
            if (!error) {
                resolve({ stdout, stderr });
                return;
            }

            const detail = String(stderr || stdout || error.message).trim();
            const commandError = new Error(detail || `${command} 执行失败`);
            commandError.cause = error;
            reject(commandError);
        });
    });
}

function desktopEnvironment() {
    const env = { ...process.env };
    if (env.DBUS_SESSION_BUS_ADDRESS) return env;

    const runtimeDirectory = env.XDG_RUNTIME_DIR
        || (typeof process.getuid === "function" ? `/run/user/${process.getuid()}` : "");
    if (runtimeDirectory) {
        env.DBUS_SESSION_BUS_ADDRESS = `unix:path=${path.join(runtimeDirectory, "bus")}`;
    }
    return env;
}

async function deployRime() {
    await runCommand("rime_deployer", [
        "--build",
        RIME_USER_DIR,
        RIME_SHARED_DIR,
        RIME_BUILD_DIR,
    ]);

    try {
        await runCommand("fcitx5-remote", ["-r"], { env: desktopEnvironment(), timeout: 15_000 });
        return { reloadError: null };
    } catch (error) {
        console.error("Rime 已部署，但 Fcitx5 重载失败:", error);
        return { reloadError: error };
    }
}

function validateSubmission(values, setErrors) {
    try {
        return normalizeEntry(values);
    } catch (error) {
        if (error instanceof PhraseValidationError) {
            setErrors((current) => ({ ...current, [error.field]: error.message }));
            return null;
        }
        console.error("校验 Rime 词条失败:", error);
        showToast({ style: Toast.Style.Failure, title: "校验失败", message: summarizeError(error) });
        return null;
    }
}

async function submitPhrase(values, controls) {
    if (controls.submitting.current) return;
    const entry = validateSubmission(values, controls.setErrors);
    if (!entry) return;

    controls.submitting.current = true;
    controls.setErrors({});
    controls.setIsSubmitting(true);
    let writeResult;
    try {
        writeResult = writePhraseFile(PHRASE_PATH, entry);
        showToast({ style: Toast.Style.Animated, title: "词条已保存，正在部署 Rime" });
        const { reloadError } = await deployRime();
        if (reloadError) {
            showToast({
                style: Toast.Style.Failure,
                title: "词条已保存并部署",
                message: `Fcitx5 重载失败：${summarizeError(reloadError)}`,
            });
            return;
        }

        const successTitles = {
            added: "词条已添加并生效",
            updated: "词条已更新并生效",
            unchanged: "词条未变化，已重新部署",
        };
        showToast({ style: Toast.Style.Success, title: successTitles[writeResult.action] });
        controls.setPhrase("");
        controls.setCode("");
    } catch (error) {
        const wasWritten = Boolean(writeResult);
        console.error(wasWritten ? "部署 Rime 失败:" : "写入 Rime 双拼词库失败:", error);
        showToast({
            style: Toast.Style.Failure,
            title: wasWritten ? "词条已保存，但部署失败" : "保存词条失败",
            message: summarizeError(error),
        });
    } finally {
        controls.submitting.current = false;
        controls.setIsSubmitting(false);
    }
}

function Command() {
    const [phrase, setPhrase] = React.useState("");
    const [code, setCode] = React.useState("");
    const [weight, setWeight] = React.useState("100");
    const [errors, setErrors] = React.useState({});
    const [isSubmitting, setIsSubmitting] = React.useState(false);
    const submitting = React.useRef(false);
    const controls = { submitting, setErrors, setIsSubmitting, setPhrase, setCode };

    const fields = [
        { id: "phrase", title: "词条", placeholder: "例如：持续集成", value: phrase, setter: setPhrase, autoFocus: true },
        { id: "code", title: "小鹤双拼码", placeholder: "例如：iixujiig", value: code, setter: setCode },
        { id: "weight", title: "权重", placeholder: "100", value: weight, setter: setWeight },
    ];

    const fieldElements = fields.map(({ setter, ...field }) => React.createElement(Form.TextField, {
        ...field,
        key: field.id,
        error: errors[field.id],
        onChange: (value) => {
            setter(value);
            setErrors((current) => ({ ...current, [field.id]: undefined }));
        },
    }));

    return React.createElement(Form, {
        navigationTitle: "添加 Rime 双拼短语",
        isLoading: isSubmitting,
        actions: React.createElement(
            ActionPanel,
            null,
            React.createElement(Action.SubmitForm, {
                title: "保存并部署",
                onSubmit: (values) => submitPhrase(values, controls),
            }),
        ),
    },
    React.createElement(Form.Description, {
        text: "写入小鹤双拼用户词库；相同词条与编码会更新权重。",
    }),
    ...fieldElements);
}

module.exports = { default: Command };
