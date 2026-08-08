#!/usr/bin/env python3
"""notification-history.py 的独立回归测试。"""

from __future__ import annotations

import json
import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("notification-history.py")


class NotificationHistoryTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.history_path = Path(self.tempdir.name) / "state" / "history.json"
        self.environment = os.environ.copy()
        self.environment["QUICKSHELL_NOTIFICATION_HISTORY_PATH"] = str(self.history_path)

    def tearDown(self) -> None:
        self.tempdir.cleanup()

    def run_command(
        self,
        command: str,
        payload: dict[str, object] | None = None,
        environment: dict[str, str] | None = None,
    ) -> dict[str, object]:
        completed = subprocess.run(
            ["python3", str(SCRIPT), command],
            input=(json.dumps(payload) + "\n") if payload is not None else None,
            text=True,
            capture_output=True,
            check=False,
            env=environment or self.environment,
        )
        self.assertEqual(completed.returncode, 0, completed.stderr or completed.stdout)
        return json.loads(completed.stdout)

    @staticmethod
    def snapshot(index: int, body: str = "正文") -> dict[str, object]:
        return {
            "id": index,
            "appName": f"应用-{index}",
            "desktopEntry": f"app-{index}.desktop",
            "summary": f"标题-{index}",
            "body": body,
            "urgency": "Normal",
            "timestamp": 1_720_000_000_000 + index,
        }

    def test_append_list_order_and_field_limits(self) -> None:
        first = self.snapshot(1, "a" * 3000)
        first["appName"] = "应用" * 100
        first["summary"] = "标题" * 200
        self.run_command("append", first)
        self.run_command("append", self.snapshot(2))

        result = self.run_command("list")
        entries = result["notifications"]
        self.assertEqual([item["id"] for item in entries], [2, 1])
        self.assertEqual(len(entries[1]["appName"]), 128)
        self.assertEqual(len(entries[1]["summary"]), 256)
        self.assertEqual(len(entries[1]["body"]), 2048)

    def test_source_counts_follow_final_history_for_all_operations(self) -> None:
        first = self.snapshot(1)
        first["appName"] = "QQ"
        first["desktopEntry"] = "QQ.desktop"
        second = self.snapshot(2)
        second["appName"] = "QQ"
        second["desktopEntry"] = "/usr/share/applications/qq.desktop"
        unknown = self.snapshot(3)
        unknown["appName"] = "Notification"
        unknown["desktopEntry"] = "Unknown.desktop"

        append_result = self.run_command("append", first)
        self.assertEqual(append_result["sourceCounts"][0]["count"], 1)
        self.run_command("append", second)
        self.run_command("append", unknown)

        count_result = self.run_command("count")
        self.assertEqual(count_result["count"], 3)
        self.assertEqual(len(count_result["sourceCounts"]), 2)
        qq_source = next(
            item for item in count_result["sourceCounts"] if item["appName"] == "QQ"
        )
        self.assertEqual(qq_source["count"], 2)
        self.assertEqual(
            qq_source["desktopEntry"], "/usr/share/applications/qq.desktop"
        )

        list_result = self.run_command("list")
        self.assertEqual(list_result["sourceCounts"], count_result["sourceCounts"])

        clear_result = self.run_command("clear")
        self.assertEqual(clear_result["count"], 0)
        self.assertEqual(clear_result["sourceCounts"], [])

    def test_entry_limit_keeps_newest_items(self) -> None:
        environment = self.environment | {
            "QUICKSHELL_NOTIFICATION_HISTORY_MAX_ENTRIES": "3",
        }
        for index in range(6):
            self.run_command("append", self.snapshot(index), environment)

        result = self.run_command("list", environment=environment)
        self.assertEqual([item["id"] for item in result["notifications"]], [5, 4, 3])

    def test_byte_limit_never_exceeds_file_cap(self) -> None:
        environment = self.environment | {
            "QUICKSHELL_NOTIFICATION_HISTORY_MAX_BYTES": "1200",
        }
        for index in range(8):
            self.run_command("append", self.snapshot(index, str(index) * 350), environment)

        result = self.run_command("list", environment=environment)
        entries = result["notifications"]
        self.assertGreater(len(entries), 0)
        self.assertLess(len(entries), 8)
        self.assertEqual(entries[0]["id"], 7)
        self.assertLessEqual(self.history_path.stat().st_size, 1200)

    def test_corrupt_file_is_quarantined_and_rebuilt(self) -> None:
        self.history_path.parent.mkdir(parents=True)
        self.history_path.write_text("{broken", encoding="utf-8")

        result = self.run_command("count")
        self.assertEqual(result["count"], 0)
        self.assertTrue(result["recovered"])
        self.assertEqual(json.loads(self.history_path.read_text(encoding="utf-8"))["notifications"], [])
        backups = list(self.history_path.parent.glob("history.corrupt-*.json"))
        self.assertEqual(len(backups), 1)

    def test_corrupt_backups_are_bounded(self) -> None:
        self.history_path.parent.mkdir(parents=True)
        for _ in range(5):
            self.history_path.write_text("{broken", encoding="utf-8")
            self.run_command("count")

        backups = list(self.history_path.parent.glob("history.corrupt-*.json"))
        self.assertEqual(len(backups), 3)

    def test_oversized_corrupt_file_is_discarded(self) -> None:
        environment = self.environment | {
            "QUICKSHELL_NOTIFICATION_HISTORY_MAX_BYTES": "256",
        }
        self.history_path.parent.mkdir(parents=True)
        self.history_path.write_text("x" * 512, encoding="utf-8")

        result = self.run_command("count", environment=environment)
        self.assertTrue(result["recovered"])
        self.assertIn("安全丢弃", result["warning"])
        self.assertEqual(list(self.history_path.parent.glob("history.corrupt-*.json")), [])
        self.assertLessEqual(self.history_path.stat().st_size, 256)

    def test_clear_persists_empty_history(self) -> None:
        self.run_command("append", self.snapshot(1))
        result = self.run_command("clear")

        self.assertEqual(result["count"], 0)
        self.assertEqual(self.run_command("list")["notifications"], [])
        self.assertTrue(self.history_path.exists())

    def test_history_and_lock_are_private(self) -> None:
        self.run_command("append", self.snapshot(1))
        history_mode = stat.S_IMODE(self.history_path.stat().st_mode)
        lock_mode = stat.S_IMODE(self.history_path.with_suffix(".lock").stat().st_mode)
        self.assertEqual(history_mode, 0o600)
        self.assertEqual(lock_mode, 0o600)

    def test_existing_parent_permissions_are_not_changed(self) -> None:
        self.history_path.parent.mkdir(parents=True, mode=0o755)
        self.history_path.parent.chmod(0o755)
        self.run_command("count")
        self.assertEqual(stat.S_IMODE(self.history_path.parent.stat().st_mode), 0o755)

    def test_concurrent_appends_do_not_lose_updates(self) -> None:
        processes: list[subprocess.Popen[str]] = []
        for index in range(20):
            process = subprocess.Popen(
                ["python3", str(SCRIPT), "append"],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                env=self.environment,
            )
            assert process.stdin is not None
            process.stdin.write(json.dumps(self.snapshot(index)) + "\n")
            process.stdin.close()
            processes.append(process)

        for process in processes:
            process.wait(timeout=10)
            stdout = process.stdout.read() if process.stdout else ""
            stderr = process.stderr.read() if process.stderr else ""
            if process.stdout:
                process.stdout.close()
            if process.stderr:
                process.stderr.close()
            self.assertEqual(process.returncode, 0, stderr or stdout)

        result = self.run_command("list")
        self.assertEqual(len(result["notifications"]), 20)
        self.assertEqual({item["id"] for item in result["notifications"]}, set(range(20)))


if __name__ == "__main__":
    unittest.main(verbosity=2)
