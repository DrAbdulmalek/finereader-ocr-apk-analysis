#!/usr/bin/env bash
# verify.sh — بوابة تحقق المستودع: أسرار + صياغة + مراجع أدلة E##
# الاستخدام: ./scripts/verify.sh [--format=json]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/.."
cd "$ROOT" || exit 1
FAIL=0
JSON="${1:-}"
declare -a CHECKS=()
add() { # status name detail
  CHECKS+=("{\"ok\":$([ "$1" = "OK" ] && echo true || echo false),\"name\":\"$2\",\"detail\":\"$3\"}")
  if [ "$1" != "OK" ]; then FAIL=1; fi
}
say() { printf '%s\n' "$*"; }

# 1) أسرار
TRACKED=$(git ls-files 2>/dev/null || true)
if [ -z "$TRACKED" ]; then
  add OK "secrets" "لا ملفات متعقبة بعد (مستودع جديد)"
else
  MATCHES=$(printf '%s\n' "$TRACKED" | tr '\n' '\0' | xargs -0 -r grep -l -E 'ghp_[A-Za-z0-9]{20,}|m0-[A-Za-z0-9]{20,}|sk-[A-Za-z0-9]{20,}' 2>/dev/null || true)
  if [ -n "$MATCHES" ]; then
    add BAD "secrets" "نمط سر داخل ملفات متعقبة: $(echo "$MATCHES" | head -2 | tr '\n' ' ')"
  else
    add OK "secrets" "لا أنماط أسرار في الملفات المتعقبة"
  fi
fi

# 2) صياغة bash
for sh in init.sh scripts/*.sh; do
  [ -f "$sh" ] || continue
  if bash -n "$sh" 2>/dev/null; then add OK "bash-syntax" "$sh"; else add BAD "bash-syntax" "$sh"; fi
done

# 3) أدلة E## : كل مرجع E## في docs يجب أن يقابله صف في 07-evidence.md
if command -v python3 >/dev/null 2>&1; then
  OUT=$(python3 - <<'PY'
import re, pathlib, sys
docs = pathlib.Path('docs')
ev = (docs / '07-evidence.md').read_text(encoding='utf-8') if (docs / '07-evidence.md').exists() else ''
defined = set(re.findall(r'\|\s*(E\d{2})\s*\|', ev))
used = {}
for md in docs.glob('*.md'):
    for m in re.finditer(r'\bE\d{2}\b', md.read_text(encoding='utf-8', errors='ignore')):
        used.setdefault(m.group(0), []).append(md.name)
missing = {k: v for k, v in used.items() if k not in defined}
if missing:
    print("BAD", "; ".join(f"{k} in {','.join(sorted(set(v)))}" for k, v in sorted(missing.items())))
else:
    print("OK", f"{len(defined)} دليلًا معرفًا، {len(used)} مستخدمًا")
PY
)
  STATUS="${OUT%% *}"; DETAIL="${OUT#* }"
  add "$STATUS" "evidence-refs" "$DETAIL"
else
  add OK "evidence-refs" "python3 غير متاح — فحص متخطى"
fi

# 4) ممنوعات المحتوى (روابط تحميل APK / كود مفكوك بحجمه)
if rg -n "apkpure|apkcombo|apk-download|\.apk\)" docs/ README.md 2>/dev/null >/dev/null; then
  add BAD "content-policy" "رابط تنزيل APK محتمل في الوثائق"
else
  add OK "content-policy" "لا روابط تنزيل APK"
fi

if [ "$JSON" = "--format=json" ]; then
  printf '{"fail":%s,"checks":[%s]}\n' "$FAIL" "$(IFS=,; echo "${CHECKS[*]:-}")"
else
  say "== verify.sh =="
  for c in "${CHECKS[@]:-}"; do
    case "$c" in
      *'"ok":true'*)  printf '  ✅ %s\n' "$c" ;;
      *'"ok":false'*) printf '  ❌ %s\n' "$c" ;;
    esac
  done
  [ "$FAIL" -eq 0 ] && say "النتيجة: PASS" || say "النتيجة: FAIL"
fi
exit "$FAIL"
