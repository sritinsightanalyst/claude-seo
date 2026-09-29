"""Reference-graph consistency gate.

Runs scripts/consistency_check.py and asserts zero errors: no dead references/
research/script/agent refs, routing-table agreement, and FLOW lock integrity.
Warnings (orphan candidates) are allowed; errors are not. Added after the
2026-07 full review, which found dead ``scripts/presets.py`` invocations that
basename-level checking had masked.
"""
import hashlib
import json
import os
import subprocess
import sys

from scripts import consistency_check

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(REPO, "scripts", "consistency_check.py")


def run_checker():
    proc = subprocess.run([sys.executable, SCRIPT, "--json"],
                          capture_output=True, text=True, cwd=REPO)
    return proc, json.loads(proc.stdout)


def test_no_consistency_errors():
    proc, result = run_checker()
    assert result["errors"] == [], "consistency errors: " + "\n".join(result["errors"])
    assert result["status"] == "PASS"
    assert proc.returncode == 0


def test_checker_scans_whole_tree():
    _, result = run_checker()
    assert result["files_checked"] > 300


def test_flow_lock_accepts_crlf_checkout(tmp_path, monkeypatch):
    prompt_rel = "skills/seo-flow/references/prompts/example.md"
    prompt_path = tmp_path / prompt_rel
    prompt_path.parent.mkdir(parents=True)
    content = b"first line\r\nsecond line\r\n"
    prompt_path.write_bytes(content)

    lock_rel = "skills/seo-flow/references/flow-prompts.lock"
    lock_path = tmp_path / lock_rel
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    expected = hashlib.sha256(content.replace(b"\r\n", b"\n")).hexdigest()
    lock_path.write_text(f"{expected}  {prompt_rel}\n", encoding="utf-8")

    monkeypatch.setattr(consistency_check, "REPO", str(tmp_path))
    monkeypatch.setattr(consistency_check, "LOCK_PATH", lock_rel)
    monkeypatch.setattr(
        consistency_check,
        "read",
        lambda rel: lock_path.read_text(encoding="utf-8") if rel == lock_rel else "",
    )

    assert consistency_check.check_flow_lock({prompt_rel}) == []
