#!/usr/bin/env bash
# init.sh — بوابة بداية الجلسة لمستودع تحليل FineReader APK
# الاستخدام: ./init.sh [--quick]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1
FAIL=0
say() { printf '%s\n' "$*"; }
gate() { if [ "$1" -eq 0 ]; then say "  ✅ $2"; else say "  ❌ $2"; FAIL=1; fi }

say "== init.sh — فحص بداية الجلسة =="

# 1) git نظيف التتبع
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  gate 0 "داخل مستودع git"
  DIRTY=$(git status --porcelain | wc -l | tr -d ' ')
  if [ "$DIRTY" != "0" ]; then say "    ملاحظة: $DIRTY ملفًا غير ملتزم (مقبول في بداية جلسة)"; fi
  BR=$(git branch --show-current)
  if [ "$BR" = "main" ] || [ "$BR" = "master" ]; then
    say "    ⚠️ أنت على $BR — التطوير يجب أن يكون على فرع feat/* أو docs/*"
  else
    say "    فرع العمل: $BR"
  fi
else
  gate 1 "ليس داخل مستودع git"
fi

# 2) بنية الملفات الإلزامية
for f in README.md AGENTS.md NOTICE.md LICENSE progress.md feature_list.json \
         docs/01-hawiya-al-tabaq.md docs/02-engine-architecture.md \
         docs/03-ocr-pipeline-ar-en.md docs/04-online-recognition-service.md \
         docs/05-features-catalog.md docs/06-lessons-for-our-projects.md \
         docs/07-evidence.md scripts/verify.sh; do
  [ -f "$f" ] && gate 0 "موجود: $f" || gate 1 "مفقود: $f"
done

# 3) لا أسرار في الملفات المتعقبة
TRACKED=$(git ls-files 2>/dev/null || true)
if [ -z "$TRACKED" ]; then
  gate 0 "لا ملفات متعقبة بعد (مستودع جديد)"
else
  MATCHES=$(printf '%s\n' "$TRACKED" | tr '\n' '\0' | xargs -0 -r grep -l -E 'ghp_[A-Za-z0-9]{20,}|m0-[A-Za-z0-9]{20,}|sk-[A-Za-z0-9]{20,}' 2>/dev/null || true)
  if [ -n "$MATCHES" ]; then
    gate 1 "اكتشاف نمط سر في ملفات متعقبة!"
    printf '%s\n' "$MATCHES"
  else
    gate 0 "لا أنماط أسرار في الملفات المتعقبة"
  fi
fi

# 4) روابط docs الداخلية (تخطى مع --quick)
QUICK="${1:-}"
if [ "$QUICK" != "--quick" ] && command -v python3 >/dev/null 2>&1; then
  python3 - <<'PY'
import re, sys, pathlib
root = pathlib.Path('.')
bad = 0
for md in root.rglob('*.md'):
    if '.git' in md.parts: continue
    text = md.read_text(encoding='utf-8', errors='ignore')
    for m in re.finditer(r'\]\(([^)#]+?\.md)\)', text):
        target = m.group(1).strip()
        if target.startswith('http'): continue
        if not (md.parent / target).exists():
            print(f"    رابط مكسور: {md} -> {target}"); bad += 1
sys.exit(1 if bad else 0)
PY
  gate $? "روابط markdown الداخلية"
else
  say "  ⏭️ فحص الروابط متخطى (--quick)"
fi

# 5) Mem0 (اختياري)
if [ -n "${MEM0_API_KEY:-}" ]; then
  say "  ✅ MEM0_API_KEY متوفر في البيئة — الذاكرة عبر الجلسات جاهزة"
else
  say "  ⏭️ MEM0_API_KEY غير متوفر — جلسة بلا ذاكرة (مقبول)"
fi

say ""
if [ "$FAIL" -eq 0 ]; then say "النتيجة: PASS — الجلسة جاهزة."; exit 0; else say "النتيجة: FAIL — أصلح ❌ قبل العمل."; exit 1; fi
