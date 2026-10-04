#!/usr/bin/env python3
"""session-handoff.py — يجمع حالة الجلسة ويولّد تسليمًا نصيًا (بدون أي أسرار).
الاستخدام: python3 scripts/session-handoff.py [--no-mem0]
"""
import argparse
import datetime
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def run(cmd):
    try:
        out = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, timeout=30)
        return out.stdout.strip() or out.stderr.strip()
    except Exception as exc:  # noqa: BLE001
        return f"ERR: {exc}"


def collect_git_state():
    if not (ROOT / ".git").exists():
        return {"git": "no repo"}
    return {
        "branch": run(["git", "branch", "--show-current"]),
        "head": run(["git", "rev-parse", "--short", "HEAD"]),
        "uncommitted": run(["git", "status", "--porcelain"]).count("\n"),
        "recent_commits": run(["git", "log", "--oneline", "-5"]),
    }


def doc_stats():
    docs = sorted((ROOT / "docs").glob("*.md"))
    return [{"file": d.name, "words": len(d.read_text(encoding="utf-8", errors="ignore").split())} for d in docs]


def save_to_mem0(summary: str) -> str:
    key = os.environ.get("MEM0_API_KEY")
    if not key:
        return "skipped: MEM0_API_KEY not in env"
    try:
        import urllib.request

        body = json.dumps(
            {
                "messages": [{"role": "assistant", "content": summary[:2000]}],
                "user_id": "DrAbdulmalek",
                "metadata": {"repo": "finereader-ocr-apk-analysis"},
            }
        ).encode()
        req = urllib.request.Request(
            "https://api.mem0.ai/v1/memories/",
            data=body,
            headers={"Authorization": f"Token {key}", "Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=30) as resp:
            return f"status {resp.status}"
    except Exception as exc:  # noqa: BLE001
        return f"failed: {type(exc).__name__}"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--no-mem0", action="store_true", help="عدم الحفظ في Mem0")
    args = ap.parse_args()

    state = collect_git_state()
    stats = doc_stats()
    total_words = sum(s["words"] for s in stats)
    now = datetime.datetime.now().isoformat(timespec="seconds")

    lines = [
        "# Session Handoff (auto)",
        f"- **when**: {now}",
        f"- **branch**: {state.get('branch')}",
        f"- **head**: {state.get('head')} | uncommitted: {state.get('uncommitted')}",
        f"- **docs**: {len(stats)} ملفًا، {total_words} كلمة",
        f"- **feature_list**: {json.dumps([f['id'] + ':' + f['status'] for f in json.loads((ROOT / 'feature_list.json').read_text(encoding='utf-8'))['features']])}",
        "",
        "## recent commits",
        "```",
        state.get("recent_commits", ""),
        "```",
    ]
    text = "\n".join(lines) + "\n"

    handoff = ROOT / "session-handoff.md"
    existing = handoff.read_text(encoding="utf-8") if handoff.exists() else ""
    handoff.write_text(existing + "\n---\n\n" + text, encoding="utf-8")

    print(text)
    if not args.no_mem0:
        result = save_to_mem0(
            f"جلسة {ROOT.name} ({now}): فرع {state.get('branch')}، {len(stats)} وثائق تحليل FineReader OCR "
            f"بمجموع {total_words} كلمة. آخر commits: {state.get('recent_commits')[:150]}"
        )
        print(f"Mem0: {result}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
