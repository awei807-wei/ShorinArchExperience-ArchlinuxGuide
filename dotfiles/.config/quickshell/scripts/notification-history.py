#!/usr/bin/env python3
"""受限、原子且并发安全的 Quickshell 通知历史存储器。"""

from __future__ import annotations

import argparse
import contextlib
import fcntl
import json
import os
import sys
import tempfile
import time
from pathlib import Path
from typing import Any, Iterator


SCHEMA_VERSION = 1
DEFAULT_MAX_ENTRIES = 200
DEFAULT_MAX_BYTES = 2 * 1024 * 1024
MAX_CORRUPT_BACKUPS = 3
FIELD_LIMITS = {
    "appName": 128,
    "desktopEntry": 128,
    "summary": 256,
    "body": 2048,
    "urgency": 32,
}


class HistoryError(RuntimeError):
    """可安全返回给 QML 的存储错误。"""


def positive_environment_integer(name: str, default: int) -> int:
    raw_value = os.environ.get(name, "")
    if not raw_value:
        return default
    try:
        return max(1, int(raw_value))
    except ValueError as error:
        raise HistoryError(f"环境变量 {name} 不是正整数") from error


MAX_ENTRIES = min(
    DEFAULT_MAX_ENTRIES,
    positive_environment_integer(
        "QUICKSHELL_NOTIFICATION_HISTORY_MAX_ENTRIES", DEFAULT_MAX_ENTRIES
    ),
)
MAX_BYTES = min(
    DEFAULT_MAX_BYTES,
    positive_environment_integer(
        "QUICKSHELL_NOTIFICATION_HISTORY_MAX_BYTES", DEFAULT_MAX_BYTES
    ),
)


def history_path() -> Path:
    override = os.environ.get("QUICKSHELL_NOTIFICATION_HISTORY_PATH")
    if override:
        return Path(override).expanduser()

    state_home = os.environ.get("XDG_STATE_HOME")
    if state_home:
        base = Path(state_home).expanduser()
    else:
        home = os.environ.get("HOME")
        if not home:
            raise HistoryError("HOME 与 XDG_STATE_HOME 均未设置")
        base = Path(home).expanduser() / ".local" / "state"
    return base / "quickshell" / "notifications" / "history.json"


def lock_path(path: Path) -> Path:
    return path.with_suffix(".lock")


def ensure_private_parent(path: Path) -> None:
    parent_existed = path.parent.exists()
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    if not parent_existed:
        os.chmod(path.parent, 0o700)


@contextlib.contextmanager
def exclusive_lock(path: Path) -> Iterator[None]:
    ensure_private_parent(path)
    descriptor = os.open(lock_path(path), os.O_RDWR | os.O_CREAT, 0o600)
    try:
        os.fchmod(descriptor, 0o600)
        fcntl.flock(descriptor, fcntl.LOCK_EX)
        yield
    finally:
        fcntl.flock(descriptor, fcntl.LOCK_UN)
        os.close(descriptor)


def clean_text(value: Any, limit: int) -> str:
    text = "" if value is None else str(value)
    return text.replace("\x00", "")[:limit].strip()


def clean_integer(value: Any, fallback: int) -> int:
    try:
        return int(value)
    except (TypeError, ValueError, OverflowError):
        return fallback


def sanitize_notification(value: Any) -> dict[str, Any] | None:
    if not isinstance(value, dict):
        return None

    now_ms = time.time_ns() // 1_000_000
    return {
        "id": clean_integer(value.get("id"), 0),
        "appName": clean_text(value.get("appName"), FIELD_LIMITS["appName"]),
        "desktopEntry": clean_text(
            value.get("desktopEntry"), FIELD_LIMITS["desktopEntry"]
        ),
        "summary": clean_text(value.get("summary"), FIELD_LIMITS["summary"]),
        "body": clean_text(value.get("body"), FIELD_LIMITS["body"]),
        "urgency": clean_text(value.get("urgency"), FIELD_LIMITS["urgency"])
        or "Normal",
        "timestamp": clean_integer(value.get("timestamp"), now_ms),
    }


def document_bytes(notifications: list[dict[str, Any]]) -> bytes:
    document = {
        "version": SCHEMA_VERSION,
        "notifications": notifications,
    }
    return (
        json.dumps(document, ensure_ascii=False, separators=(",", ":")) + "\n"
    ).encode("utf-8")


def trim_notifications(
    notifications: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    trimmed = notifications[:MAX_ENTRIES]
    while trimmed and len(document_bytes(trimmed)) > MAX_BYTES:
        trimmed.pop()
    return trimmed


def normalized_identity(value: Any) -> str:
    normalized = "" if value is None else str(value).strip().lower()
    if not normalized:
        return ""
    normalized = normalized.replace("\\", "/")
    normalized = normalized.rsplit("/", 1)[-1]
    if normalized.endswith(".desktop"):
        normalized = normalized[:-8]
    return normalized


def notification_source_counts(
    notifications: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    """按规范化来源聚合裁剪后的最终历史，保留首条原始标签。"""

    buckets: list[dict[str, Any]] = []
    indexes: dict[tuple[str, str], int] = {}
    for notification in notifications:
        desktop_entry = notification["desktopEntry"]
        app_name = notification["appName"]
        key = (normalized_identity(desktop_entry), normalized_identity(app_name))
        bucket_index = indexes.get(key)
        if bucket_index is None:
            indexes[key] = len(buckets)
            buckets.append(
                {
                    "desktopEntry": desktop_entry,
                    "appName": app_name,
                    "count": 1,
                }
            )
        else:
            buckets[bucket_index]["count"] += 1
    return buckets


def corrupt_backup_path(path: Path) -> Path:
    stamp = time.strftime("%Y%m%d-%H%M%S", time.localtime())
    candidate = path.with_name(f"{path.stem}.corrupt-{stamp}.json")
    suffix = 2
    while candidate.exists():
        candidate = path.with_name(f"{path.stem}.corrupt-{stamp}-{suffix}.json")
        suffix += 1
    return candidate


def prune_corrupt_backups(path: Path) -> None:
    backups = sorted(
        path.parent.glob(f"{path.stem}.corrupt-*.json"),
        key=lambda item: item.stat().st_mtime_ns,
        reverse=True,
    )
    retained_bytes = 0
    for index, backup in enumerate(backups):
        backup_size = backup.stat().st_size
        should_keep = (
            index < MAX_CORRUPT_BACKUPS
            and retained_bytes + backup_size <= MAX_BYTES
        )
        if should_keep:
            retained_bytes += backup_size
        else:
            backup.unlink()


def read_unlocked(path: Path) -> tuple[list[dict[str, Any]], bool, str]:
    if not path.exists():
        return [], False, ""

    try:
        if path.stat().st_size > MAX_BYTES:
            raise ValueError("历史文件超过容量上限")
        with path.open("r", encoding="utf-8") as source:
            document = json.load(source)
        if not isinstance(document, dict):
            raise ValueError("根节点不是对象")
        if document.get("version") != SCHEMA_VERSION:
            raise ValueError("存储版本不受支持")
        raw_notifications = document.get("notifications")
        if not isinstance(raw_notifications, list):
            raise ValueError("notifications 不是数组")
        notifications = [
            cleaned
            for item in raw_notifications
            if (cleaned := sanitize_notification(item)) is not None
        ]
        os.chmod(path, 0o600)
        return notifications, False, ""
    except (OSError, UnicodeError, json.JSONDecodeError, ValueError) as error:
        backup = corrupt_backup_path(path)
        try:
            os.replace(path, backup)
            os.chmod(backup, 0o600)
            prune_corrupt_backups(path)
        except OSError as backup_error:
            raise HistoryError(f"历史损坏且无法隔离: {backup_error}") from backup_error
        warning = (
            f"历史文件损坏，已隔离为 {backup.name}"
            if backup.exists()
            else "历史文件损坏且超过隔离容量，已安全丢弃"
        )
        return [], True, warning


def write_unlocked(path: Path, notifications: list[dict[str, Any]]) -> None:
    ensure_private_parent(path)
    payload = document_bytes(notifications)
    descriptor, temporary_name = tempfile.mkstemp(
        dir=path.parent,
        prefix=f".{path.stem}-",
        suffix=".tmp",
    )
    temporary_path = Path(temporary_name)
    try:
        os.fchmod(descriptor, 0o600)
        with os.fdopen(descriptor, "wb") as destination:
            destination.write(payload)
            destination.flush()
            os.fsync(destination.fileno())
        os.replace(temporary_path, path)
        os.chmod(path, 0o600)
        directory_descriptor = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory_descriptor)
        finally:
            os.close(directory_descriptor)
    finally:
        if temporary_path.exists():
            temporary_path.unlink()


def read_payload() -> dict[str, Any]:
    line = sys.stdin.readline()
    if not line:
        raise HistoryError("append 缺少 JSON 输入")
    try:
        payload = json.loads(line)
    except json.JSONDecodeError as error:
        raise HistoryError("append 输入不是有效 JSON") from error
    if not isinstance(payload, dict):
        raise HistoryError("append 输入必须是 JSON 对象")
    return payload


def execute(command: str) -> dict[str, Any]:
    path = history_path()
    with exclusive_lock(path):
        notifications, recovered, warning = read_unlocked(path)
        normalized = trim_notifications(notifications)

        if command == "append":
            notification = sanitize_notification(read_payload())
            if notification is None:
                raise HistoryError("append 输入无法转换为通知记录")
            normalized = trim_notifications([notification, *normalized])
        elif command == "clear":
            normalized = []
        elif command not in {"count", "list"}:
            raise HistoryError(f"不支持的命令: {command}")

        needs_write = (
            command in {"append", "clear"}
            or recovered
            or normalized != notifications
            or not path.exists()
        )
        if needs_write:
            write_unlocked(path, normalized)

        result: dict[str, Any] = {
            "ok": True,
            "operation": command,
            "count": len(normalized),
            "sourceCounts": notification_source_counts(normalized),
            "recovered": recovered,
            "warning": warning,
        }
        if command == "list":
            result["notifications"] = normalized
        return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("append", "list", "count", "clear"))
    arguments = parser.parse_args()

    try:
        result = execute(arguments.command)
    except (HistoryError, OSError) as error:
        print(
            json.dumps(
                {
                    "ok": False,
                    "operation": arguments.command,
                    "error": str(error),
                },
                ensure_ascii=False,
                separators=(",", ":"),
            )
        )
        return 1

    print(json.dumps(result, ensure_ascii=False, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
