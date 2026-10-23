#!/usr/bin/env bash
# ft_lgtm POST /api/run 분기 실험.
# 실험마다 Rust 코드를 보내고, 응답의 status가 예상과 같은지 확인한다.
#
# 사용법:
#   ./run-experiments.sh                      기본 4개 (success compile_error timeout runtime_error)
#   ./run-experiments.sh timeout exit_code    고른 실험만
#   ./run-experiments.sh --list               실험 목록
#   API_URL=http://localhost:8080/api/run ./run-experiments.sh   다른 주소로 보낼 때 (make dev 등)
#
# 실행할 때마다 결과가 IPFS에 업로드된다 (run.go의 share).

set -euo pipefail

API_URL="${API_URL:-http://lgtm.local/api/run}"

# 실험 이름 -> 보낼 Rust 코드
declare -A CODE=(
  [success]='fn main() { println!("hello"); }'
  [compile_error]='fn main() { let x: i32 = "hello"; }'
  [timeout]='fn main() { println!("start"); loop {} }'
  [runtime_error]='fn main() { println!("before"); panic!("boom"); }'
  # 선택 실험: 다른 코드 경로를 탄다
  [sleep_timeout]='fn main() { std::thread::sleep(std::time::Duration::from_secs(30)); }'
  [exit_code]='fn main() { std::process::exit(42); }'
)

# 실험 이름 -> 예상 status
declare -A EXPECT=(
  [success]=success
  [compile_error]=compile_error
  [timeout]=timeout
  [runtime_error]=runtime_error
  [sleep_timeout]=timeout
  [exit_code]=runtime_error
)

ORDER=(success compile_error timeout runtime_error sleep_timeout exit_code)
DEFAULT=(success compile_error timeout runtime_error)

# 응답 JSON을 읽어 주요 필드를 출력한다. 마지막 줄은 요약표용 "status|exitCode|durationMs".
# argv: 예상 status, 응답 본문
PRINT_RESULT='
import json, sys
expected, raw = sys.argv[1], sys.argv[2]
try:
    r = json.loads(raw)
except ValueError:
    print("  응답이 JSON이 아니다:", raw.strip()[:300])
    print("-|-|-")
    sys.exit(0)

def short(s, lines=3):
    parts = (s or "").splitlines()
    text = "\n               ".join(parts[:lines])
    if len(parts) > lines:
        text += "\n               ... (%d줄 더)" % (len(parts) - lines)
    return repr(s) if len(parts) <= 1 else text

mark = "OK" if r.get("status") == expected else "다름"
print("  status     : %s  [%s]" % (r.get("status"), mark))
print("  exitCode   : %s" % r.get("exitCode"))
print("  durationMs : %s" % r.get("durationMs"))
print("  stdout     : %s" % short(r.get("stdout")))
print("  stderr     : %s" % short(r.get("stderr")))
print("  traceId    : %s" % r.get("traceId", "(없음)"))
print("  cid        : %s" % (r.get("cid") or "(없음 - 로그 터미널에서 ipfs upload failed 확인)"))
print("%s|%s|%s" % (r.get("status"), r.get("exitCode"), r.get("durationMs")))
'

if [[ "${1:-}" == "--list" ]]; then
  for name in "${ORDER[@]}"; do
    printf '%-14s 예상=%-14s %s\n' "$name" "${EXPECT[$name]}" "${CODE[$name]}"
  done
  exit 0
fi

if (($# > 0)); then
  names=("$@")
else
  names=("${DEFAULT[@]}")
fi

for name in "${names[@]}"; do
  if [[ -z "${CODE[$name]+x}" ]]; then
    echo "모르는 실험: $name (--list로 목록 확인)" >&2
    exit 2
  fi
done

summary=()
mismatch=0

for name in "${names[@]}"; do
  code="${CODE[$name]}"
  expected="${EXPECT[$name]}"
  echo "=== $name (예상: $expected)"
  echo "  code       : $code"

  # Rust 코드의 따옴표를 JSON에 맞게 이스케이프한다.
  body=$(python3 -c 'import json, sys; print(json.dumps({"code": sys.argv[1]}))' "$code")

  if ! resp=$(curl -sS --max-time 60 -X POST "$API_URL" \
      -H 'Content-Type: application/json' -d "$body"); then
    echo "  요청 실패 (make status로 pod 상태 확인)"
    summary+=("$name|$expected|-|-|-|요청 실패")
    mismatch=$((mismatch + 1))
    echo
    continue
  fi

  out=$(python3 -c "$PRINT_RESULT" "$expected" "$resp")
  echo "$out" | sed '$d'
  IFS='|' read -r got exit_code duration <<<"$(echo "$out" | tail -n 1)"

  if [[ "$got" == "$expected" ]]; then
    result=OK
  else
    result=다름
    mismatch=$((mismatch + 1))
  fi
  summary+=("$name|$expected|$got|$exit_code|$duration|$result")
  echo
done

echo "=== 요약"
{
  echo "실험|예상|status|exitCode|durationMs|결과"
  printf '%s\n' "${summary[@]}"
} | column -t -s '|'

exit $((mismatch > 0 ? 1 : 0))