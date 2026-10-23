#!/usr/bin/env bash
# =====================================================================
# 2-check-endpoint-auth-network.sh
# 체크리스트 ②  백엔드 메트릭(실행 건수·지연 시간)이 Mimir에 수집되도록
#               엔드포인트 / 인증 / 네트워크가 설정됐는지 확인
#
# 이 스크립트가 보여주는 것
#   1) 엔드포인트: Mimir Service가 클러스터 내부 주소(ClusterIP)로 열려 있고 파드에 연결돼 있는가
#   2) 네트워크: Mimir가 Ingress로 외부에 노출되지 않았는가
#   3) 인증: 테넌트 헤더(X-Scope-OrgID) 없이 요청하면 거부되고, 있으면 통과하는가
#   4) 네트워크: NetworkPolicy가 있는가 (NP_TEST=1이면 정책 밖에서 실제 접속 시도)
#   5) 백엔드 메트릭 이름이 Mimir에 들어와 있는가
#   6) 코드를 실행하면 실행 건수가 실제로 늘어나는가        ← 핵심 증거
#   7) 지연 시간(히스토그램)이 조회되는가
#
# 사용법:  TENANT=lgtm ./2-check-endpoint-auth-network.sh
#          TRIGGER_CMD="./test-run.sh" ./2-check-endpoint-auth-network.sh   (실행을 자동으로 발생시킬 때)
#          NP_TEST=1 ./2-check-endpoint-auth-network.sh                    (NetworkPolicy 차단 실험 포함)
# 필요 도구: kubectl, curl, jq
# =====================================================================
set -uo pipefail

NS="${NS:-observability}"
MIMIR_SVC="${MIMIR_SVC:-mimir-gateway}"       # Mimir 진입점 Service (Helm mimir-distributed의 gateway)
MIMIR_PORT="${MIMIR_PORT:-80}"
COLLECTOR_SVC="${COLLECTOR_SVC:-otel-collector}"
TENANT="${TENANT:-}"
METRIC_FILTER="${METRIC_FILTER:-execution}"   # 백엔드 메트릭 이름에 들어 있는 단어 (정규식)
COUNTER_METRIC="${COUNTER_METRIC:-}"          # 비우면 자동 탐색
HIST_METRIC="${HIST_METRIC:-}"                # 비우면 자동 탐색 (…_bucket 또는 native histogram)
STATUS_LABEL="${STATUS_LABEL:-status}"        # 성공/실패를 구분하는 라벨 이름
TRIGGER_CMD="${TRIGGER_CMD:-}"                # 코드 실행을 발생시키는 명령 (비우면 직접 실행 후 Enter)
WAIT_SECS="${WAIT_SECS:-90}"
NP_TEST="${NP_TEST:-0}"
NP_TEST_NS="${NP_TEST_NS:-default}"           # 정책 '밖'으로 간주할 네임스페이스

# ---------- 출력 도우미 ----------
PASS=0; FAIL=0; WARN=0
ok()   { printf '  \033[32m[PASS]\033[0m %s\n' "$*"; PASS=$((PASS+1)); }
bad()  { printf '  \033[31m[FAIL]\033[0m %s\n' "$*"; FAIL=$((FAIL+1)); }
warn() { printf '  \033[33m[WARN]\033[0m %s\n' "$*"; WARN=$((WARN+1)); }
info() { printf '  \033[36m[INFO]\033[0m %s\n' "$*"; }
step() { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }
summary() {
  printf '\n\033[1m결과: PASS %d / WARN %d / FAIL %d\033[0m\n' "$PASS" "$WARN" "$FAIL"
  [ "$FAIL" -eq 0 ]
}
for c in kubectl curl jq; do
  command -v "$c" >/dev/null || { echo "필요한 도구가 없습니다: $c"; exit 2; }
done

PF_PIDS=()
cleanup() { for p in "${PF_PIDS[@]}"; do kill "$p" 2>/dev/null; done; }
trap cleanup EXIT
port_forward() {  # $1=네임스페이스 $2=대상 $3=로컬포트 $4=원격포트
  kubectl port-forward -n "$1" "$2" "$3:$4" >"/tmp/pf-$3.log" 2>&1 &
  PF_PIDS+=($!)
  for _ in $(seq 1 30); do
    curl -s -o /dev/null --max-time 1 "http://127.0.0.1:$3/" && return 0
    sleep 0.5
  done
  return 1
}

H=(); [ -n "$TENANT" ] && H=(-H "X-Scope-OrgID: $TENANT")
MIMIR="http://127.0.0.1:19009"
mq()    { curl -sS -G --max-time 10 "${H[@]}" "$MIMIR/prometheus/api/v1/query" --data-urlencode "query=$1"; }
num()   { mq "$1" | jq -r '.data.result[0].value[1] // empty'; }
gt()    { awk -v a="$1" -v b="$2" 'BEGIN{exit !(a>b)}'; }

echo "체크리스트 ② 엔드포인트 / 인증 / 네트워크 + 백엔드 메트릭 수집  (NS=$NS, TENANT=${TENANT:-없음})"

# ---------------------------------------------------------------------
step "1. 엔드포인트: Mimir Service"
# kubectl get svc: Service 정보. ClusterIP는 클러스터 안에서만 쓰는 내부 주소라는 뜻
type=$(kubectl get svc -n "$NS" "$MIMIR_SVC" -o jsonpath='{.spec.type}' 2>/dev/null)
ports=$(kubectl get svc -n "$NS" "$MIMIR_SVC" -o jsonpath='{range .spec.ports[*]}{.port}/{.protocol} {end}' 2>/dev/null)
if [ -z "$type" ]; then
  bad "Service '$MIMIR_SVC'가 없음 (NS=$NS)"
else
  info "내부 주소: http://$MIMIR_SVC.$NS.svc.cluster.local:$MIMIR_PORT  (포트: $ports)"
  info "수신 경로: OTLP → /otlp/v1/metrics,  Remote Write → /api/v1/push,  조회 → /prometheus/api/v1/*"
  info "Collector 설정의 exporter 주소와 이 주소가 같아야 한다 (1번 스크립트 3단계 참고)"
  [ "$type" = "ClusterIP" ] && ok "Service 타입 ClusterIP (클러스터 내부 전용)" \
                            || warn "Service 타입 $type → 노드/외부에서 접근 가능"
fi
# EndpointSlice: Service가 실제로 트래픽을 넘겨줄 파드 IP 목록. 비어 있으면 Service가 파드를 못 찾는 것
eps=$(kubectl get endpointslices -n "$NS" -l "kubernetes.io/service-name=$MIMIR_SVC" \
      -o jsonpath='{.items[*].endpoints[*].addresses[*]}' 2>/dev/null)
[ -n "$eps" ] && ok "Service → 파드 연결됨 ($eps)" || bad "Service에 연결된 파드 IP가 없음"

# ---------------------------------------------------------------------
step "2. 네트워크: Mimir 외부 노출 여부"
# 모든 네임스페이스의 Ingress를 뒤져 백엔드 서비스가 Mimir인 규칙이 있는지 확인
exposed=$(kubectl get ingress -A -o json 2>/dev/null | jq -r --arg s "$MIMIR_SVC" \
  '.items[] | select([.spec.rules[]?.http.paths[]?.backend.service.name] | index($s)) | "\(.metadata.namespace)/\(.metadata.name)"')
[ -z "$exposed" ] && ok "Mimir를 외부로 여는 Ingress 없음 (Grafana만 외부 노출)" \
                  || warn "Mimir가 Ingress로 노출됨: $exposed"

# ---------------------------------------------------------------------
step "3. 인증: 테넌트 헤더 (X-Scope-OrgID)"
if ! port_forward "$NS" "svc/$MIMIR_SVC" 19009 "$MIMIR_PORT"; then
  bad "Mimir port-forward 실패 — 이후 단계를 진행할 수 없음"; summary; exit 1
fi
# 헤더 없이 요청 → 멀티테넌시가 켜져 있으면 401이어야 한다
code0=$(curl -s -o /tmp/mimir-noh.txt -w '%{http_code}' --max-time 5 "$MIMIR/prometheus/api/v1/label/__name__/values")
case "$code0" in
  401)
    ok "헤더 없이 요청 → 401 거부 (멀티테넌시 ON): $(head -c 60 /tmp/mimir-noh.txt)"
    if [ -z "$TENANT" ]; then
      bad "TENANT 환경변수를 지정해야 다음 단계를 확인할 수 있음 (예: TENANT=lgtm)"; summary; exit 1
    fi
    code1=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "${H[@]}" "$MIMIR/prometheus/api/v1/label/__name__/values")
    [ "$code1" = "200" ] && ok "X-Scope-OrgID: $TENANT 헤더로 요청 → 200 허용" || bad "헤더를 넣어도 HTTP $code1"
    # 쓰는 쪽(Collector)에도 같은 헤더가 설정돼 있어야 데이터가 같은 테넌트로 들어간다
    if kubectl get cm -n "$NS" -o json | jq -r '.items[].data // {} | .[]' | grep -qE "X-Scope-OrgID.*$TENANT"; then
      ok "Collector 설정에 X-Scope-OrgID: $TENANT 헤더 있음"
    else
      warn "Collector ConfigMap에서 X-Scope-OrgID: $TENANT 를 찾지 못함 (다른 방식으로 넣었다면 직접 확인)"
    fi
    ;;
  200)
    warn "헤더 없이도 200 → 멀티테넌시 OFF (모든 데이터가 'anonymous' 테넌트). 인증을 테넌트 헤더로 구현했다면 ON이어야 함"
    ;;
  *)
    bad "예상하지 못한 응답 HTTP $code0: $(head -c 120 /tmp/mimir-noh.txt)"
    ;;
esac

# ---------------------------------------------------------------------
step "4. 네트워크: NetworkPolicy"
# NetworkPolicy: "어떤 파드가 이 파드에 접속할 수 있는가"를 정하는 클러스터 내부 방화벽 규칙
if [ "$(kubectl get networkpolicy -n "$NS" --no-headers 2>/dev/null | wc -l)" -gt 0 ]; then
  ok "NetworkPolicy 존재"
  kubectl get networkpolicy -n "$NS" | sed 's/^/        /'
  if [ "$NP_TEST" = "1" ]; then
    info "정책 밖($NP_TEST_NS 네임스페이스)에 임시 curl 파드를 띄워 Mimir 접속 시도 (막혀야 정상)"
    # kubectl run --rm -i: 임시 파드를 실행하고 끝나면 지운다. 접속이 막히면 curl이 000을 출력
    out=$(kubectl run "np-probe-$$" -n "$NP_TEST_NS" --rm -i --restart=Never --quiet \
          --image=curlimages/curl:8.10.1 -- \
          curl -s -o /dev/null -w '%{http_code}' --max-time 5 \
          "http://$MIMIR_SVC.$NS.svc.cluster.local:$MIMIR_PORT/" 2>&1)
    code=$(echo "$out" | grep -oE '^[0-9]{3}' | tail -1)
    if [ "$code" = "000" ]; then ok "정책 밖 파드의 접속 차단됨 (timeout)"
    elif [ -n "$code" ]; then bad "정책 밖 파드도 Mimir에 접속됨 (HTTP $code) → 정책이 Mimir 파드에 적용되지 않음"
    else warn "판단 불가: $(echo "$out" | tail -1 | cut -c1-150)"; fi
  fi
else
  warn "NS=$NS 에 NetworkPolicy 없음 (같은 클러스터의 모든 파드가 Mimir에 접근 가능)"
fi

# ---------------------------------------------------------------------
step "5. 백엔드 메트릭이 Mimir에 들어와 있는가"
names=$(curl -sS -G --max-time 10 "${H[@]}" "$MIMIR/prometheus/api/v1/label/__name__/values" \
        | jq -r '.data[]?' | grep -E "$METRIC_FILTER")
if [ -z "$names" ]; then
  bad "'$METRIC_FILTER'를 포함한 메트릭 이름이 없음 (METRIC_FILTER로 단어를 바꿔 보기)"
  summary; exit 1
fi
ok "백엔드 메트릭 발견:"; echo "$names" | sed 's/^/        /'
# Counter: …_total이 있으면 그것, 없으면 히스토그램 계열(_bucket/_sum/_count, duration/latency)이 아닌 첫 이름
# (OTLP 이름 변환 설정에 따라 _total 접미사가 붙지 않을 수 있다)
if [ -z "$COUNTER_METRIC" ]; then
  COUNTER_METRIC=$(echo "$names" | grep -E '_total$' | head -1)
  [ -z "$COUNTER_METRIC" ] && COUNTER_METRIC=$(echo "$names" \
    | grep -vE '(_bucket|_sum|_count|_created)$' | grep -viE 'duration|latency' | head -1)
fi
# Histogram: 클래식(…_bucket)이 있으면 그것, 없으면 duration/latency가 들어간 이름(native histogram)
if [ -z "$HIST_METRIC" ]; then
  HIST_METRIC=$(echo "$names" | grep -E '_bucket$' | head -1)
  [ -z "$HIST_METRIC" ] && HIST_METRIC=$(echo "$names" \
    | grep -iE 'duration|latency' | grep -vE '(_sum|_count)$' | head -1)
fi
info "실행 건수 Counter: ${COUNTER_METRIC:-없음}   지연 시간 Histogram: ${HIST_METRIC:-없음}"

# ---------------------------------------------------------------------
step "6. 코드를 실행하면 실행 건수가 늘어나는가"
snapshot() {
  mq "sum by ($STATUS_LABEL) ($COUNTER_METRIC)" | jq -c --arg l "$STATUS_LABEL" \
    '[.data.result[]? | {(.metric[$l] // "(라벨없음)"): (.value[1] | tonumber)}] | add // {}'
}
if [ -z "$COUNTER_METRIC" ]; then
  bad "실행 건수 Counter를 찾지 못함 (COUNTER_METRIC으로 직접 지정)"
else
  before=$(snapshot); before_total=$(num "sum($COUNTER_METRIC)"); before_total=${before_total:-0}
  info "실행 전: $before"
  if [ -n "$TRIGGER_CMD" ]; then
    info "실행 발생 명령: $TRIGGER_CMD"
    bash -c "$TRIGGER_CMD" >/tmp/trigger.log 2>&1 || warn "TRIGGER_CMD가 0이 아닌 코드로 종료 (/tmp/trigger.log)"
  elif [ -t 0 ]; then
    read -r -p "  >> 웹 에디터나 테스트 스크립트로 코드를 몇 번 실행한 뒤 Enter를 누르세요 " _
  else
    info "입력이 없는 환경이라 그대로 대기 (그사이 코드를 실행해 주세요)"
  fi
  after_total=$before_total
  for _ in $(seq 1 $((WAIT_SECS / 5))); do
    after_total=$(num "sum($COUNTER_METRIC)"); after_total=${after_total:-0}
    gt "$after_total" "$before_total" && break
    sleep 5
  done
  after=$(snapshot)
  jq -n -r --argjson a "$before" --argjson b "$after" \
    '($a + $b | keys)[] as $k | "        \($k): \($a[$k] // 0) → \($b[$k] // 0)  (+\(($b[$k] // 0) - ($a[$k] // 0)))"'
  if gt "$after_total" "$before_total"; then
    ok "실행 건수 증가: 전체 $before_total → $after_total"
  else
    bad "${WAIT_SECS}초 동안 실행 건수가 늘지 않음 (백엔드 → Collector 구간 확인)"
  fi
fi

# ---------------------------------------------------------------------
step "7. 지연 시간 (Histogram)"
if [ -z "$HIST_METRIC" ]; then
  warn "지연 시간 Histogram을 찾지 못함 (HIST_METRIC으로 직접 지정)"
else
  # histogram_quantile: 버킷 분포로 백분위수를 계산. rate(...[5m]) = 최근 5분 동안의 변화량
  # 클래식 히스토그램은 le(버킷 경계) 라벨로 묶고, native 히스토그램은 버킷이 값 안에 들어 있어 그냥 합친다
  if [[ "$HIST_METRIC" == *_bucket ]]; then agg="sum by (le)"; else agg="sum"; fi
  p50=$(num "histogram_quantile(0.50, $agg (rate(${HIST_METRIC}[5m])))")
  p95=$(num "histogram_quantile(0.95, $agg (rate(${HIST_METRIC}[5m])))")
  unit=""; [[ "$HIST_METRIC" == *_seconds_* ]] && unit="s"; [[ "$HIST_METRIC" == *_milliseconds_* ]] && unit="ms"
  if [ -n "$p95" ] && [ "$p95" != "NaN" ]; then
    ok "최근 5분 지연 시간  p50=${p50}${unit}  p95=${p95}${unit}"
  else
    warn "최근 5분 동안 관측값이 없어 계산 불가 (6번에서 실행이 있었다면 잠시 뒤 재실행)"
  fi
fi

summary
