#!/usr/bin/env bash
# =====================================================================
# 3-check-grafana-datasource.sh
# 체크리스트 ③  Mimir(Prometheus 타입) 데이터 소스가 Grafana에 프로비저닝으로 사전 등록됐는지 확인
#
# 이 스크립트가 보여주는 것
#   1) Grafana 파드 안 프로비저닝 폴더에 데이터 소스 YAML이 있는가
#   2) Grafana API에 데이터 소스가 등록돼 있고, readOnly=true 인가
#      (UI에서 손으로 만든 것은 false, 설정 파일로 만든 것만 true → 프로비저닝 증거)
#   3) Grafana → Mimir 연결 테스트(Save & test와 같은 동작)가 성공하는가
#   4) Grafana를 통해 PromQL을 실행하면 데이터가 나오는가
#   5) (RESTART_TEST=1) Grafana를 재시작해도 데이터 소스가 그대로 다시 생기는가
#
# 사용법:  ./3-check-grafana-datasource.sh
#          GRAFANA_URL=http://grafana.lgtm.local ./3-check-grafana-datasource.sh   (Ingress로 접속)
#          RESTART_TEST=1 ./3-check-grafana-datasource.sh                          (재시작 실험 포함)
# 필요 도구: kubectl, curl, jq
# =====================================================================
set -uo pipefail

NS="${NS:-observability}"                       # Grafana가 있는 네임스페이스
GRAFANA_DEPLOY="${GRAFANA_DEPLOY:-grafana}"
GRAFANA_SVC="${GRAFANA_SVC:-grafana}"
GRAFANA_SVC_PORT="${GRAFANA_SVC_PORT:-80}"      # Helm grafana 차트의 Service 포트
GRAFANA_URL="${GRAFANA_URL:-}"                  # 지정하면 port-forward 대신 이 주소 사용
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASSWORD="${GRAFANA_PASSWORD:-}"        # 비우면 Secret에서 읽기 시도 → 실패 시 admin
GRAFANA_SECRET="${GRAFANA_SECRET:-grafana}"
DS_UID="${DS_UID:-mimir}"                       # 프로비저닝 YAML의 uid
PROV_DIR="${PROV_DIR:-/etc/grafana/provisioning/datasources}"
TENANT="${TENANT:-}"                            # 멀티테넌시 ON이면 Grafana에도 같은 헤더가 있어야 함
DEFAULT_QUERY='count({__name__=~".+"})'        # 저장된 시계열 개수
QUERY="${QUERY:-$DEFAULT_QUERY}"                 # Grafana를 통해 실행할 PromQL
RESTART_TEST="${RESTART_TEST:-0}"

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
cleanup() { for p in "${PF_PIDS[@]}"; do kill "$p" 2>/dev/null; done; PF_PIDS=(); }
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
connect_grafana() {
  if [ -n "$GRAFANA_URL" ]; then G="$GRAFANA_URL"; return 0; fi
  G="http://127.0.0.1:13000"
  port_forward "$NS" "svc/$GRAFANA_SVC" 13000 "$GRAFANA_SVC_PORT"
}
gapi() { curl -sS --max-time 15 -u "$GRAFANA_USER:$GRAFANA_PASSWORD" "$@"; }

# 비밀번호: Helm 차트는 Secret(grafana)의 admin-password 키에 넣어 둔다
if [ -z "$GRAFANA_PASSWORD" ]; then
  GRAFANA_PASSWORD=$(kubectl get secret -n "$NS" "$GRAFANA_SECRET" -o jsonpath='{.data.admin-password}' 2>/dev/null | base64 -d 2>/dev/null)
  GRAFANA_PASSWORD="${GRAFANA_PASSWORD:-admin}"
fi

echo "체크리스트 ③ Grafana 데이터 소스 프로비저닝  (NS=$NS, uid=$DS_UID)"

# ---------------------------------------------------------------------
step "1. 프로비저닝 파일 (Grafana 파드 안)"
# kubectl exec: 실행 중인 파드 안에서 명령을 실행. Grafana는 시작할 때 이 폴더의 YAML을 읽어 데이터 소스를 만든다.
# 비밀번호·토큰·헤더 값은 화면에 보이지 않게 가린다.
prov=$(kubectl exec -n "$NS" "deploy/$GRAFANA_DEPLOY" -- sh -c \
  "ls -1 $PROV_DIR; for f in $PROV_DIR/*.y*ml; do echo \"--- \$f\"; cat \"\$f\"; done" 2>&1)
if echo "$prov" | grep -qiE "uid:[[:space:]]*\"?$DS_UID\"?"; then
  ok "$PROV_DIR 에 uid=$DS_UID 데이터 소스 정의가 있음"
  echo "$prov" | sed -E 's/((password|Password|token|httpHeaderValue[0-9]*)[[:space:]]*:[[:space:]]*).*/\1****/' | sed 's/^/        /'
else
  bad "$PROV_DIR 에서 uid=$DS_UID 정의를 찾지 못함"
  echo "$prov" | head -20 | sed 's/^/        /'
fi

# ---------------------------------------------------------------------
step "2. Grafana에 등록된 데이터 소스"
if ! connect_grafana; then bad "Grafana 접속 실패 (svc/$GRAFANA_SVC:$GRAFANA_SVC_PORT, GRAFANA_SVC_PORT 확인)"; summary; exit 1; fi
health=$(gapi "$G/api/health" | jq -r '.database // empty')
[ "$health" = "ok" ] && ok "Grafana 동작 중 ($G)" || warn "Grafana /api/health 응답 이상"

ds=$(gapi "$G/api/datasources/uid/$DS_UID")
if [ "$(echo "$ds" | jq -r '.uid // empty' 2>/dev/null)" != "$DS_UID" ]; then
  bad "uid=$DS_UID 데이터 소스가 없음 (로그인 실패일 수도 있음: $(echo "$ds" | head -c 120))"
  summary; exit 1
fi
echo "$ds" | jq -r '"        name=\(.name)  type=\(.type)  access=\(.access)  url=\(.url)  isDefault=\(.isDefault)  readOnly=\(.readOnly)"'
[ "$(echo "$ds" | jq -r .type)" = "prometheus" ] && ok "type=prometheus (Mimir는 Prometheus 호환 API)" \
                                               || bad "type이 prometheus가 아님"
[ "$(echo "$ds" | jq -r .access)" = "proxy" ] && ok "access=proxy (Grafana 서버가 클러스터 안에서 대신 조회)" \
                                            || warn "access가 proxy가 아님 → 브라우저가 내부 DNS를 못 찾을 수 있음"
[ "$(echo "$ds" | jq -r .readOnly)" = "true" ] && ok "readOnly=true → UI가 아니라 프로비저닝으로 등록됨" \
                                             || bad "readOnly=false → UI에서 수동 등록된 데이터 소스로 보임"
hdr=$(echo "$ds" | jq -r '.jsonData.httpHeaderName1 // empty')
if [ -n "$TENANT" ]; then
  [ "$hdr" = "X-Scope-OrgID" ] && ok "테넌트 헤더 설정됨 (httpHeaderName1=X-Scope-OrgID)" \
                              || bad "TENANT=$TENANT 인데 데이터 소스에 X-Scope-OrgID 헤더가 없음"
elif [ -n "$hdr" ]; then
  info "커스텀 헤더 설정: $hdr"
fi

# ---------------------------------------------------------------------
step "3. 연결 테스트 (UI의 Save & test와 같은 동작)"
h=$(gapi "$G/api/datasources/uid/$DS_UID/health")
st=$(echo "$h" | jq -r '.status // empty')
msg=$(echo "$h" | jq -r '.message // empty')
[ "$st" = "OK" ] && ok "health: $msg" || bad "health 실패: ${msg:-$h}"

# ---------------------------------------------------------------------
step "4. Grafana를 통해 PromQL 실행"
info "query: $QUERY"
# /api/ds/query: 대시보드·Explore가 내부적으로 쓰는 조회 API. 브라우저 → Grafana → Mimir 경로를 그대로 탄다.
body=$(jq -n --arg uid "$DS_UID" --arg q "$QUERY" \
  '{from:"now-15m", to:"now", queries:[{refId:"A", datasource:{uid:$uid, type:"prometheus"}, expr:$q, instant:true, range:false}]}')
res=$(gapi -X POST -H 'Content-Type: application/json' --data "$body" "$G/api/ds/query")
err=$(echo "$res" | jq -r '.results.A.error // empty')
vals=$(echo "$res" | jq -c '[.results.A.frames[]?.data.values[-1][]?]')
if [ -n "$err" ]; then
  bad "조회 에러: $err"
elif [ "$vals" != "[]" ] && [ -n "$vals" ]; then
  ok "Grafana → Mimir 조회 성공, 결과 값: $vals"
else
  warn "에러는 없지만 결과가 비어 있음 (최근 15분 데이터가 없거나 QUERY를 바꿔 보기)"
fi

# ---------------------------------------------------------------------
if [ "$RESTART_TEST" = "1" ]; then
  step "5. 재시작 후에도 데이터 소스가 다시 생기는가"
  # rollout restart: Deployment의 파드를 새로 띄운다. 프로비저닝한 데이터 소스는 시작할 때 YAML에서 다시 만들어진다.
  kubectl rollout restart -n "$NS" "deploy/$GRAFANA_DEPLOY" >/dev/null
  # rollout status: 새 파드가 Ready가 될 때까지 기다린다.
  if kubectl rollout status -n "$NS" "deploy/$GRAFANA_DEPLOY" --timeout=180s >/dev/null; then
    cleanup
    connect_grafana
    for _ in $(seq 1 30); do [ "$(gapi "$G/api/health" 2>/dev/null | jq -r '.database // empty')" = "ok" ] && break; sleep 2; done
    ro=$(gapi "$G/api/datasources/uid/$DS_UID" | jq -r '.readOnly // empty')
    [ "$ro" = "true" ] && ok "재시작 후에도 uid=$DS_UID 데이터 소스 존재 (readOnly=true)" \
                       || bad "재시작 후 데이터 소스가 없음"
  else
    bad "Grafana 재시작이 180초 안에 끝나지 않음"
  fi
fi

summary
