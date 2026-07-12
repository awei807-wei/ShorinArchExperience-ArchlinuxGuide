const fs = require("node:fs");
const path = require("node:path");

class PhraseValidationError extends Error {
    constructor(field, message) {
        super(message);
        this.name = "PhraseValidationError";
        this.field = field;
    }
}

function normalizeEntry(values) {
    const phrase = String(values.phrase ?? "").trim();
    if (!phrase) {
        throw new PhraseValidationError("phrase", "请输入词条");
    }
    if (/[\t\r\n]/u.test(phrase)) {
        throw new PhraseValidationError("phrase", "词条不能包含制表符或换行");
    }

    const code = String(values.code ?? "").trim().toLowerCase();
    if (!code) {
        throw new PhraseValidationError("code", "请输入小鹤双拼码");
    }
    if (!/^[a-z]+$/u.test(code)) {
        throw new PhraseValidationError("code", "双拼码只能包含连续的英文字母");
    }

    const weightText = String(values.weight ?? "").trim();
    if (!/^\d+$/u.test(weightText)) {
        throw new PhraseValidationError("weight", "权重必须是整数");
    }
    const weight = Number(weightText);
    if (!Number.isSafeInteger(weight) || weight < 1 || weight > 1_000_000) {
        throw new PhraseValidationError("weight", "权重范围为 1–1000000");
    }

    return { phrase, code, weight };
}

function parsePhraseLine(line) {
    const fields = line.split("\t");
    if (fields.length < 2) return null;

    return {
        phrase: fields[0].trim(),
        code: fields[1].trim().toLowerCase(),
    };
}

function upsertPhraseContent(currentContent, values) {
    const entry = normalizeEntry(values);
    const serializedEntry = `${entry.phrase}\t${entry.code}\t${entry.weight}`;
    const lines = String(currentContent ?? "").replace(/\r\n?/gu, "\n").split("\n");

    while (lines.at(-1) === "") lines.pop();

    let found = false;
    const nextLines = [];
    for (const line of lines) {
        const parsed = parsePhraseLine(line);
        const matches = parsed?.phrase === entry.phrase && parsed.code === entry.code;
        if (!matches) {
            nextLines.push(line);
            continue;
        }

        if (!found) {
            nextLines.push(serializedEntry);
            found = true;
        }
    }

    if (!found) nextLines.push(serializedEntry);

    const nextContent = `${nextLines.join("\n")}\n`;
    const action = !found ? "added" : nextContent === currentContent ? "unchanged" : "updated";
    return { action, content: nextContent, entry };
}

function writePhraseFile(filePath, values) {
    const exists = fs.existsSync(filePath);
    const currentContent = exists ? fs.readFileSync(filePath, "utf8") : "";
    const result = upsertPhraseContent(currentContent, values);
    if (result.action === "unchanged") return result;

    const mode = exists ? fs.statSync(filePath).mode & 0o777 : 0o644;
    const temporaryPath = path.join(
        path.dirname(filePath),
        `.${path.basename(filePath)}.${process.pid}.${Date.now()}.tmp`,
    );

    try {
        fs.writeFileSync(temporaryPath, result.content, { encoding: "utf8", mode, flag: "wx" });
        fs.chmodSync(temporaryPath, mode);
        fs.renameSync(temporaryPath, filePath);
    } finally {
        if (fs.existsSync(temporaryPath)) fs.unlinkSync(temporaryPath);
    }

    return result;
}

module.exports = {
    PhraseValidationError,
    normalizeEntry,
    upsertPhraseContent,
    writePhraseFile,
};
