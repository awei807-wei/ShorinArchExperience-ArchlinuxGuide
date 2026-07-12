const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");
const {
    PhraseValidationError,
    normalizeEntry,
    upsertPhraseContent,
    writePhraseFile,
} = require("./phrase-store");

test("规范化词条、双拼码和权重", () => {
    assert.deepEqual(normalizeEntry({
        phrase: "  持续集成  ",
        code: " IIXUJIIG ",
        weight: "0100",
    }), {
        phrase: "持续集成",
        code: "iixujiig",
        weight: 100,
    });
});

test("拒绝不合法的表单字段", () => {
    for (const [values, field] of [
        [{ phrase: "", code: "ab", weight: "100" }, "phrase"],
        [{ phrase: "词条", code: "ab cd", weight: "100" }, "code"],
        [{ phrase: "词条", code: "ab", weight: "1.5" }, "weight"],
        [{ phrase: "词条", code: "ab", weight: "0" }, "weight"],
    ]) {
        assert.throws(
            () => normalizeEntry(values),
            (error) => error instanceof PhraseValidationError && error.field === field,
        );
    }
});

test("追加新词条时保留注释和原有顺序", () => {
    const current = "# Rime custom phrase\n已有词条\tyyct\t80\n";
    const result = upsertPhraseContent(current, { phrase: "持续集成", code: "iixujiig", weight: "100" });

    assert.equal(result.action, "added");
    assert.equal(
        result.content,
        "# Rime custom phrase\n已有词条\tyyct\t80\n持续集成\tiixujiig\t100\n",
    );
});

test("更新首个匹配项并清理重复项", () => {
    const current = [
        "# 保留",
        "持续集成\tIIXUJIIG\t20",
        "其他词条\tqtct\t50",
        "持续集成\tiixujiig\t30",
        "",
    ].join("\n");
    const result = upsertPhraseContent(current, { phrase: "持续集成", code: "iixujiig", weight: "100" });

    assert.equal(result.action, "updated");
    assert.equal(
        result.content,
        "# 保留\n持续集成\tiixujiig\t100\n其他词条\tqtct\t50\n",
    );
});

test("内容完全一致时不重复写入", () => {
    const current = "持续集成\tiixujiig\t100\n";
    const result = upsertPhraseContent(current, { phrase: "持续集成", code: "iixujiig", weight: "100" });

    assert.equal(result.action, "unchanged");
    assert.equal(result.content, current);
});

test("使用同目录临时文件完成原子替换并保留权限", (context) => {
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), "rime-phrase-store-"));
    context.after(() => fs.rmSync(directory, { recursive: true, force: true }));
    const filePath = path.join(directory, "custom_phrase_double.txt");
    fs.writeFileSync(filePath, "已有词条\tyyct\t80\n", { encoding: "utf8", mode: 0o640 });

    const result = writePhraseFile(filePath, { phrase: "持续集成", code: "iixujiig", weight: "100" });

    assert.equal(result.action, "added");
    assert.equal(fs.statSync(filePath).mode & 0o777, 0o640);
    assert.equal(
        fs.readFileSync(filePath, "utf8"),
        "已有词条\tyyct\t80\n持续集成\tiixujiig\t100\n",
    );
    assert.deepEqual(fs.readdirSync(directory), ["custom_phrase_double.txt"]);
});

test("词条未变化时不替换原文件", (context) => {
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), "rime-phrase-store-"));
    context.after(() => fs.rmSync(directory, { recursive: true, force: true }));
    const filePath = path.join(directory, "custom_phrase_double.txt");
    fs.writeFileSync(filePath, "潮鸣\ticmk\t100\n", "utf8");
    const inodeBefore = fs.statSync(filePath).ino;

    const result = writePhraseFile(filePath, { phrase: "潮鸣", code: "ICMK", weight: "100" });

    assert.equal(result.action, "unchanged");
    assert.equal(fs.statSync(filePath).ino, inodeBefore);
    assert.deepEqual(fs.readdirSync(directory), ["custom_phrase_double.txt"]);
});
