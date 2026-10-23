#!/usr/bin/env bash
# =====================================================================
# 1-check-pipeline.sh
# 체크리스트 ①  OTel Collector → Grafana Mimir 데이터 파이프라인 연동 확인
#
# 이 스크립트가 보여주는 것
#   1) Collector, Mimir 파드가 Running/Ready 상태인가
#   2) Mimir 게이트웨이가 조회 요청에 응답하는가
#   3) Collector exporter가 Mimir 엔드포인트(OTLP 또는 Remote Write)를 가리키는가
#   4) 테스트 메트릭을 Collector에 OTLP로 넣으면 Mimir에서 꺼내지는가   ← 핵심 증거
#   5) Collector가 내보내다 실패한 데이터가 없는가 (자체 메트릭 + 로그)
#
# 사용법:  ./1-check-pipeline.sh
#          TENANT=lgtm ./1-check-pipeline.sh   (멀티테넌시를 켰을 때)
# 필요 도구: kubectl, curl, jq
# =====================================================================
set -uo pipefail

NS="${NS:-observability}"                          # Mimir·Collector가 있는 네임스페이스
MIMIR_SVC="${MIMIR_SVC:-mimir-gateway}"            # Mimir 진입점 Service (Helm mimir-distributed의 gateway)
MIMIR_PORT="${MIMIR_PORT:-80}"                     # gateway Service 포트
MIMIR_POD_PREFIX="${MIMIR_POD_PREFIX:-mimir-}"     # Mimir 컴포넌트 파드 이름 접두사
COLLECTOR_CM="${COLLECTOR_CM:-otel-collector-config}"  # Collector 설정 ConfigMap
COLLECTOR_SVC="${COLLECTOR_SVC:-otel-collector}"   # Collector Service 이름 (파드 이름 접두사로도 사용)
COLLECTOR_OTLP_HTTP_PORT="${COLLECTOR_OTLP_HTTP_PORT:-4318}"
COLLECTOR_SELF_METRICS_PORT="${COLLECTOR_SELF_METRICS_PORT:-8888}"
TENANT="${TENANT:-}"                               # 멀티테넌시 ON이면 테넌트 ID (예: lgtm)
WAIT_SECS="${WAIT_SECS:-60}"                       # Mimir에서 테스트 메트릭을 기다릴 최대 시간(초)

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

# ---------- port-forward 도우미 ----------
# kubectl port-forward: 클러스터 안의 Service/Pod 포트를 내 PC의 localhost 포트로 잠깐 이어 주는 터널.
# 스크립트가 끝나면 trap으로 터널을 자동으로 닫는다.
PF_PIDS=()
cleanup() { for p in "${PF_PIDS[@]}"; do kill "$p" 2>/dev/null; done; }
trap cleanup EXIT
port_forward() {  # $1=네임스페이스 $2=대상(svc/xxx, pod/xxx) $3=로컬포트 $4=원격포트
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
mq() { curl -sS -G --max-time 10 "${H[@]}" "$MIMIR/prometheus/api/v1/query" --data-urlencode "query=$1"; }

echo "체크리스트 ① OTel Collector → Mimir 파이프라인 연동  (NS=$NS, TENANT=${TENANT:-없음})"

# ---------------------------------------------------------------------
step "1. 파드 상태"
# kubectl get pods: 파드 목록. READY가 1/1처럼 분자=분모이고 STATUS가 Running이면 정상
pods=$(kubectl get pods -n "$NS" --no-headers 2>/dev/null)
# Mimir는 distributor, ingester, querier 등 여러 컴포넌트 파드로 나뉘어 있어서 전부 확인한다
for prefix in "$MIMIR_POD_PREFIX" "$COLLECTOR_SVC"; do
  lines=$(echo "$pods" | grep -E "^${prefix}")
  if [ -z "$lines" ]; then bad "'$prefix'로 시작하는 파드를 찾지 못함 (NS=$NS)"; continue; fi
  while read -r pname ready status _; do
    # Completed(Job)는 정상 종료라 건너뛴다
    [ "$status" = "Completed" ] && continue
    if [ "$status" = "Running" ] && [ "${ready%/*}" = "${ready#*/}" ]; then
      ok "$pname  READY=$ready  STATUS=$status"
    else
      bad "$pname  READY=$ready  STATUS=$status"
    fi
  done <<<"$lines"
done

# ---------------------------------------------------------------------
step "2. Mimir 응답 확인 (gateway → querier)"
MIMIR_UP=0
if port_forward "$NS" "svc/$MIMIR_SVC" 19009 "$MIMIR_PORT"; then
  # vector(1): 저장된 데이터와 상관없이 항상 1을 돌려주는 PromQL. 조회 경로가 살아 있는지만 본다
  r=$(mq 'vector(1)' | jq -r '.status // empty' 2>/dev/null)
  if [ "$r" = "success" ]; then ok "PromQL vector(1) 조회 성공 (svc/$MIMIR_SVC)"; MIMIR_UP=1; else bad "조회 실패: '$r'"; fi
else
  bad "Mimir port-forward 실패 (svc/$MIMIR_SVC:$MIMIR_PORT) — /tmp/pf-19009.log 확인"
fi

# ---------------------------------------------------------------------
step "3. Collector exporter 설정 (어디로, 어떤 형식으로 보내는가)"
# Collector 설정 파일은 ConfigMap(k8s/observability/otel-collector.yaml)에 들어 있다.
cm="$COLLECTOR_CM"
if ! kubectl get cm -n "$NS" "$cm" >/dev/null 2>&1; then
  bad "ConfigMap '$cm'이 없음 (NS=$NS)"
else
  cfg=$(kubectl get cm -n "$NS" "$cm" -o json | jq -r '.data | to_entries[] | .value')
  info "ConfigMap: $cm  (관련 줄만 표시)"
  echo "$cfg" | grep -n -E 'exporters:|otlphttp|prometheusremotewrite|endpoint:|X-Scope-OrgID|pipelines:|metrics:' | sed 's/^/        /'
  if echo "$cfg" | grep -qE "endpoint:.*${MIMIR_SVC}[.:].*/otlp"; then
    ok "OTLP(otlphttp) 방식으로 Mimir에 보내도록 설정됨"
  elif echo "$cfg" | grep -qE "endpoint:.*${MIMIR_SVC}[.:].*/api/v1/push"; then
    ok "Prometheus Remote Write 방식으로 Mimir에 보내도록 설정됨"
  else
    bad "exporter endpoint에 Mimir 주소(/otlp 또는 /api/v1/push)가 보이지 않음"
  fi
fi

# ---------------------------------------------------------------------
step "4. 테스트 메트릭 왕복 (Collector에 넣고 → Mimir에서 꺼내기)"
CHECK_ID="check-$(date +%s)"
VALUE=$(( $(date +%s) % 100000 ))     # 매번 다른 값 → 예전 데이터와 헷갈리지 않음
NOW_NS="$(date +%s)000000000"         # OTLP 타임스탬프는 나노초 단위
payload=$(cat <<JSON
{"resourceMetrics":[{"resource":{"attributes":[{"key":"service.name","value":{"stringValue":"lgtm-pipeline-check"}}]},
 "scopeMetrics":[{"scope":{"name":"verify-script"},"metrics":[{"name":"lgtm_pipeline_check","gauge":{"dataPoints":[
 {"asDouble":$VALUE,"timeUnixNano":"$NOW_NS","attributes":[{"key":"check_id","value":{"stringValue":"$CHECK_ID"}}]}]}}]}]}]}
JSON
)
if port_forward "$NS" "svc/$COLLECTOR_SVC" 14318 "$COLLECTOR_OTLP_HTTP_PORT"; then
  # 백엔드가 하는 일과 똑같이, Collector의 OTLP/HTTP 수신 주소(/v1/metrics)로 메트릭을 POST
  code=$(curl -s -o /tmp/otlp-resp.txt -w '%{http_code}' --max-time 5 -X POST \
         -H 'Content-Type: application/json' --data "$payload" http://127.0.0.1:14318/v1/metrics)
  if [ "$code" = "200" ]; then
    ok "Collector가 OTLP 메트릭을 받음 (HTTP 200)  check_id=$CHECK_ID  value=$VALUE"
    if [ "$MIMIR_UP" = 1 ]; then
      info "Mimir에 도착할 때까지 최대 ${WAIT_SECS}초 대기 (Collector는 묶어서 보내므로 몇 초 걸림)"
      found=""
      for _ in $(seq 1 $((WAIT_SECS / 5))); do
        found=$(mq "lgtm_pipeline_check{check_id=\"$CHECK_ID\"}" | jq -r '.data.result[0].value[1] // empty')
        [ -n "$found" ] && break
        sleep 5
      done
      if [ -n "$found" ]; then
        ok "Mimir에서 조회됨: lgtm_pipeline_check{check_id=\"$CHECK_ID\"} = $found  (보낸 값 $VALUE)"
      else
        bad "${WAIT_SECS}초 안에 Mimir에서 조회되지 않음 → 아래 5번과 Collector 로그 확인"
      fi
    fi
  else
    bad "Collector 수신 실패 HTTP $code: $(head -c 200 /tmp/otlp-resp.txt)"
  fi
else
  bad "Collector port-forward 실패 (svc/$COLLECTOR_SVC:$COLLECTOR_OTLP_HTTP_PORT) — OTLP HTTP 수신이 켜져 있는지 확인"
fi

# ---------------------------------------------------------------------
step "5. Collector 내보내기 성공/실패 기록"
cpod=$(kubectl get pods -n "$NS" --no-headers -o custom-columns=:metadata.name | grep -E "^${COLLECTOR_SVC}" | head -1)
# Collector는 자기 상태를 :8888/metrics 에 Prometheus 형식으로 공개한다.
if [ -n "$cpod" ] && port_forward "$NS" "pod/$cpod" 18888 "$COLLECTOR_SELF_METRICS_PORT"; then
  m=$(curl -s --max-time 5 http://127.0.0.1:18888/metrics)
  echo "$m" | grep -E '^otelcol_exporter_(sent|send_failed)_metric_points' | sed 's/^/        /'
  sent=$(echo "$m"   | grep -E '^otelcol_exporter_sent_metric_points'        | awk '{s+=$2} END{printf "%d", s}')
  failed=$(echo "$m" | grep -E '^otelcol_exporter_send_failed_metric_points' | awk '{s+=$2} END{printf "%d", s}')
  [ "${sent:-0}" -gt 0 ] && ok "내보낸 메트릭 포인트 누적 $sent개" || warn "내보낸 기록이 0"
  [ "${failed:-0}" -eq 0 ] && ok "내보내기 실패 0" || warn "내보내기 실패 누적 $failed개 (과거 실패일 수 있음 — 로그 확인)"
else
  warn "Collector 자체 메트릭(:$COLLECTOR_SELF_METRICS_PORT) 접근 불가 — 로그만 확인"
fi
if [ -n "$cpod" ]; then
  # kubectl logs --since=10m: 최근 10분 로그만 본다. 전송 실패는 보통 error 레벨로 찍힌다.
  errs=$(kubectl logs -n "$NS" "pod/$cpod" --since=10m 2>/dev/null | grep -i -E '\berror\b|refused|dropping|401|429')
  if [ -z "$errs" ]; then ok "최근 10분 Collector 로그에 에러 없음"
  else warn "최근 10분 Collector 로그에 에러 $(echo "$errs" | wc -l)줄 (마지막 3줄)"; echo "$errs" | tail -3 | cut -c1-200 | sed 's/^/        /'; fi
fi

summary
