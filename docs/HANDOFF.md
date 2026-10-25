# HANDOFF

피처 블록은 이 줄 아래에 최신이 위로 오도록 추가한다.

<!-- 피처 블록 템플릿
## F-Mx-xx <이름> (브랜치 feat/mx-xx-<이름>)
### 한 일
### 된 것
### 안 된 것
### 다음 단계
-->

## F-M6-xx readme-fixes (브랜치 docs/readme-fixes)

README.md 문구만 바꿨다. 코드, Makefile, scripts, manifest는 바꾸지 않았다. Helm 관련은 범위 밖으로 두었다.

### 한 일
- Security model 첫 문단: "published on IPFS forever" → "User code is untrusted. Its output is pinned on our IPFS node, and once someone else has fetched it, it cannot be reliably taken back." 근거: backend가 `/api/v0/add?pin=true`로 올리고(`backend/internal/ipfs/client.go`), Kubo 데이터는 PVC다(`k8s/ipfs/kubo.yaml` volumeClaimTemplates).
- Demo walkthrough 2번: "scraped" → "reach Mimir (the backend pushes them to the Collector every 5 s)". Collector receiver는 otlp뿐이고 prometheus scrape는 없다. backend `metricExportInterval = 5 * time.Second`. batch 기본값 숫자는 쓰지 않았다(`batch: {}`, 기본값 미확인). README에서 scrape는 이 1곳뿐이었다.
- 한도 단위 통일: Output 10 KiB(`OutputLimit = 10240`), Request body 64 KiB(`maxBodyBytes = 64 * 1024`), Memory 10 MiB(`10 << 20`). Security 표, 표 아래 acceptance 문장, Demo 1번, Use of AI 섹션.
- 테스트 입력값: `m2-03-wasmtime-exec.sh`의 `vec![0u8; 100_000_000]`은 100,000,000 B라 "100 MB"를 유지했다. 출력 케이스는 1024 B × 1024줄 = 1,048,576 B라 "1 MB" → "1 MiB"로 바꿨다.
- IPFS and NAT Diagnosing: 괄호 안을 S1~S9와 1:1로 바꾸고 S5(test file add + pin + provide)를 넣었다. 앞 문장의 "adds a small test file"은 S5와 겹쳐서 지웠다.

### 된 것
- 로컬 grep: 수정 후 README에 `scrap` 0건. kB/KB/MB 표기는 "100 MB allocation" 1건만 남았다(의도한 것).

### 안 된 것
- `scripts/verify/m6-01-readme.sh` VM 실행: 못 했다. lgtm-vm(192.168.64.8)이 ping과 ssh 22 모두 timeout이었고, lock도 잡지 않았다. 바꾼 줄에는 make 타겟, 경로, 버전 문자열이 없어서 영향은 없을 것으로 보지만 확인하지는 않았다.

### 다음 단계
- VM이 다시 뜨면 `m6-01-readme.sh`를 실행한다.
- Helm 설치 제거 여부 결정(별도 피처). 지금 helm은 `scripts/setup/install.sh`에서 설치하고 `m0-01` verify에서 버전만 확인한다. `helm install/upgrade/template` 호출은 0건이다.

## F-M6-07 comment-cleanup (브랜치 chore/m6-07-comment-cleanup)

코드 주석과 dashboard description만 바꿨다. 코드, 설정 값, 스크립트 로직, 테스트 단언은 바꾸지 않았다. VM 검증은 하지 않았다(사용자 지시: 주석만 변경). 확인은 로컬 diff로 했다.

### 한 일
- `scripts/verify/m6-07-comment-cleanup.sh`를 먼저 커밋했다(236a293). (a) origin/main 대비 주석도 빈 줄도 아닌 +/- 줄을 목록으로 출력한다(사람이 확인). (b) k8s ConfigMap data 블록(`key: |`) 내용이 바뀌지 않았는지 본다. (c) 주석과 dashboard description에 남은 피처 ID / PRD 번호 / 개발 기록 참조 / 날짜를 센다. (a)(b)는 git이 없거나 diff가 없으면 SKIP하고, (c)는 이후에도 쓰는 검사다. Makefile VERIFY_ALL에는 넣지 않았다(Makefile 로직을 바꾸지 않기 위해).
- 유형별 정리 (주석 부분만 센 값. before는 origin/main에 `CHECK_ROOT`로 돌린 (c), after는 0):

| 유형 | before | after |
|---|---|---|
| 피처 ID (`F-Mx-yy`) | 75 | 0 |
| PRD 번호 (`PRD x.y`, SEC-/TR-/IP-/INF-/FE-/BE-, dashboard description 2건 포함) | 63 | 0 |
| 개발 기록 참조 (HANDOFF, spike, 타임라인, 검증에서, 실측은. 허용 목록 제외) | 7 | 0 |
| 날짜 | 4 | 0 |

- 그 밖의 정리:
  - 변경 이력 3건을 지웠다: compiler.yaml "SEC-10 변경(PRD 변경)", grafana.yaml "PRD 14장 해소", handler.go "PRD 6.2 변경".
  - 측정 로그를 압축했다. backend.yaml resources 4줄을 2줄로 줄이고 "동시 20건 peak 약 70MB"만 남겼다. import-images.sh의 cold 측정 기록은 이유 문장만 남겼다.
  - PRD 번호가 내용을 대신하던 곳은 내용으로 바꿨다(TR-03 → `code.*` attribute, TR-04 → `exec.*` attribute, "PRD 8.3: compile → rustc" → "span 트리: compile → rustc").
- 낡은 주석 2건:
  - `execute/compiler_client.go`: "backend 메모리 limit(128Mi)" → 512Mi (k8s/app/backend.yaml 실제 값).
  - Makefile 1행 "미구현 타겟은 TODO <피처ID> 출력": TODO 타겟이 0개(`grep TODO Makefile`은 1행뿐)라 문장을 지웠다.
- 주석의 숫자를 실제 값과 대조했다(preStop 10s, Shutdown 60s, grace 75s, maxQueueWait 45s, compiler 20s, ipfs 10s, 10MiB, 10240, 64KB, 64KiB, 2Gi/256Mi, 512Mi/64Mi, telemetry Shutdown 10s, reboot-check 180, wait-dashboards 150, POLL_MAX 120). 불일치는 128Mi 1건뿐이었다.
- 주석 처리된 코드 블록은 0건이었다(grep으로 확인). Go 공개 식별자의 doc 주석은 Go 관례라 유지했다.

### 남긴 것과 이유
- 허용 목록 ((c)의 ALLOW): m3-03의 HANDOFF(스크립트가 실제로 docs/HANDOFF.md를 검사), m6-05의 HANDOFF(경로 예외), m6-04의 "타임라인"(스크립트 안 진단 루프 이름).
- 보안과 순서 설명은 번호만 빼고 내용을 유지했다:
  - wasmexec sandbox 설명(capability 0, 10MiB, epoch, fd_write shadowing)
  - deny-list 한계
  - compiler/kubo NetworkPolicy
  - 사용자 입력을 span/로그에 넣지 않는 이유(errors.go, failspan.go, handler.go step)
  - exemplar는 root span End 전에 기록(handler.go writeResult, metrics.go RecordExecution)
  - 슬롯 반환 시점(handler.go ServeHTTP)
  - preStop + Shutdown + grace 순서(backend.yaml, cmd/api/main.go)
- tempo.yaml 상단의 `local_blocks` 설명은 m5-03이 검사하므로 유지했다.
- verify 스크립트 사이 참조(m1-01, m2-04 등)는 실제 파일 이름이라 유지했다.

### 건드리지 않은 ConfigMap data 블록 안 주석 (바꾸면 ConfigMap이 바뀌어 pod가 재시작된다)
- k8s/ipfs/kubo.yaml `001-lgtm-config.sh: |` 블록 (9~26행)
- k8s/observability/loki.yaml `loki.yaml: |` 블록 29, 41행 (41행에 `PRD 8.5`가 남아 있음)
- k8s/observability/mimir.yaml `mimir.yaml: |` 블록 11~82행 (76행에 `PRD 8.5`가 남아 있음)
- collector/grafana/tempo의 data 블록에는 `#` 주석이 없다.
- dashboards/lgtm-traces.json Longest 패널 description의 "(실측 1회)"는 PRD 번호가 아니라서 이번 범위(description은 PRD 번호만)에 넣지 않았다.

### 된 것 (VM 미실행, 주석만 변경, 로컬 diff 확인)
- m6-07 (a): 주석이 아닌 변경 줄은 4쌍뿐이다. dashboards description 2쌍(승인된 변경)과 코드 끝 주석 2쌍(kubo.yaml `readOnlyRootFilesystem: true # ...`, m5-03 `POLL_MAX = 120  # ...`)이다. 두 줄 모두 코드 부분은 같아서 되돌린 줄은 없다.
- m6-07 (b): k8s 9개 파일 모두 data 블록 변경 없음. (c): 4개 유형 모두 0건, RESULT 모두 통과.
- 로컬 `bash -n`: scripts/*.sh 41개, 실패 0. 로컬 `gofmt -l .`(backend/): 출력 없음.
- 위 실행은 모두 macOS에서 했다(m6-07은 `uname` shim으로 Linux 검사를 우회). CLAUDE.md 기준으로는 VM 검증이 아니다.

### 안 된 것
- VM에서 m6-07, go vet / go test, `make build deploy`, `kubectl diff`, m1-03 / m2-01 / m2-03 / m6-04 / m5-02 / m5-03을 돌리지 않았다(사용자 지시. 작업 중 ssh lgtm-vm도 timeout이었다).
- 236a293 커밋 메시지의 "(c) 실패"는 정리 전 origin/main에 로컬로 (c)를 돌린 결과(before 개수가 0이 아님)다. VM에서 확인한 값은 아니다.

### 다음 단계
- 다음 VM 작업 때 `make build deploy`를 돌려 wait-dashboards 통과를 확인하고, m6-07과 m5-02/m5-03을 1회 돌린다(dashboards description이 바뀌어 grafana-dashboards ConfigMap이 바뀐다).

## F-M6-02 fresh-vm (브랜치 feat/m6-02-fresh-vm)

진행 방식 변경(사용자 지시): 개발 VM은 쓰지 않는다. 검증은 사용자가 새 VM(192.168.64.8) 콘솔에서 하고, Claude Code는 이 VM에 ssh로 접속하지 않는다. 로컬(macOS)에서는 bash -n, shellcheck, make -n, hosts.sh 임시 파일 테스트만 했다(검증으로 치지 않음).

### 한 일
- m6-02-fresh-vm.sh를 먼저 커밋했다(cab1ee2). 검사 항목: 폰트, fclean/re 구현, `all` 순서, 대기 600s, inbrowser.link, 출제자 문구 정확 일치, make -n, VERIFY_ALL, 재부팅 내성 설정.
- install.sh: `install_fonts`(fonts-noto-cjk, 이미 있으면 `[skip]`)를 추가했다. `docker_ok`에 `systemctl is-enabled --quiet docker`를 넣었다. 지금까지 `enable --now`는 설치 경로에서만 실행돼서, docker가 설치돼 있지만 disabled인 VM은 `[skip]`되고 재부팅 후 docker가 올라오지 않았다.
- Makefile:
  - `all: sudo-auth install hosts cluster build deploy`로 바꿨다.
  - `sudo-auth`를 추가했다: root이거나 `sudo -n true`가 되면 그냥 넘어가고, sudo가 없으면 안내 후 실패, 아니면 `sudo -v`.
  - `fclean`(sudo-auth → clean → `lgtm-(backend|compiler|frontend):*` rmi → `hosts.sh --remove`)과 `re`(recipe 안에서 fclean 다음 all)를 구현했다.
  - VERIFY_ALL 맨 앞에 m0-01과 m0-02, 끝에 m6-02를 넣었다.
- **계획과 다른 점**: 계획은 `install`, `hosts` 단독 실행에도 sudo-auth를 prerequisite로 붙이기로 했지만 붙이지 않았다. 붙이면 m0-01(`make install`)과 m0-02(`make hosts`)가 긴 `make verify` 도중 타임스탬프가 만료된 시점에 비밀번호를 묻고 멈춘다. 둘 다 이미 설치된 상태에서는 sudo를 부르지 않으므로 없어도 된다. sudo-auth는 `all`과 `fclean`에만 붙어 있다.
- cluster.sh: 대기 상한을 `WAIT_TIMEOUT=600` 하나로 맞췄다(create --timeout, node Ready, traefik 생성 poll, traefik rollout, 오류 문구).
- hosts.sh: `--remove`를 추가했다(블록만 제거, 블록이 없으면 `[skip]`).
- m0-01: fonts-noto-cjk와 docker enabled 검사를 추가했고, `[skip]` 기대값을 4줄에서 5줄로 바꿨다.
- m0-02:
  - (4) 호스트별 경로 `lgtm.local/`, `grafana.lgtm.local/api/health`, `ipfs.lgtm.local/ipfs/bafkqaaa`가 200이고 본문 3개가 서로 다른지 본다.
  - (8) observability, ipfs, lgtm의 모든 컨테이너(init 포함)에 cpu/memory request와 limit이 있는지 본다.
- FE: `PUBLIC_IPFS = 'https://inbrowser.link/ipfs/'`, 링크 텍스트, ResultView.test.tsx 기대값을 바꿨다.
- README:
  - Instructions: 사전 조건, sudo 함정, 시작 직후 비밀번호 1회, 폰트, 소요 시간 `TBD`, fclean/re, 재부팅 확인 방법을 적었다.
  - IPFS and NAT: 출제자 문장과 inbrowser.link(동작 미측정)를 적었다.
  - Make targets: fclean, re 행을 추가했다.
- scripts/tools/reboot-check.sh를 새로 만들었다: 부팅 후 N초(기본 180) 안에 pod가 전부 Running(+Ready) 또는 Completed가 되고 `curl --resolve lgtm.local:80:127.0.0.1`이 200이면 PASS.

### 된 것
- 로컬 정적 검사만 했다. 변경한 스크립트는 `bash -n`과 `shellcheck -S warning`에서 문제가 없었다(rc 0). `make -n all/sudo-auth/install/hosts/fclean/re/verify/clean`도 모두 됐다. hosts.sh는 임시 파일로 추가 → skip → 제거 → skip을 확인했다.
- 클러스터 PC VirtualBox(amd64) VM에서 2부 Step 1~7 통과(사용자 실행, 2026-10-25). 그 VM의 첫 make는 625359a 이전 main으로 실행했고, git pull 후 625359a로 make, make verify(m0-01/m0-02/m6-02 포함), 재부팅 확인, make 재실행, make re까지 통과.

### 안 된 것 (사용자가 새 VM에서 실행 → 결과 대기)
- 빈 VM에서 625359a로 첫 make는 미확인(최종 리허설에서 확인 예정)
- inbrowser.link 링크로 CID가 실제로 열리는지 확인하지 않음 (캠퍼스 NAT 환경이라 열리지 않는 것이 예상 동작)
- k3d 노드 컨테이너 restart policy의 실제 값은 기록하지 않음 (m6-02 검사 9는 always 또는 unless-stopped인지만 확인)

### 다음 단계
- 사용자 결과로 README의 소요 시간과 재부팅 결과 `TBD`를 채우고, Known limitations의 "Full `make verify` on a fresh VM" 줄을 갱신한다.

## F-M6-06 backend-refactor (브랜치 feat/m6-06-backend-refactor)

backend/ Go 코드 구조만 바꿨다. 응답, span, metric, 로그 문구와 속성 키, 큐 슬롯 반환 시점은 그대로다. 테스트 파일은 고치지 않았다.

### 무엇을 어디로 옮겼나
| 무엇 | 전 | 후 |
|---|---|---|
| `"http://ipfs.lgtm.local/ipfs/"` 리터럴 | handler.go ServeHTTP 본문 | `execute.ipfsGatewayURL` 상수 (handler.go). upload_test.go:149의 리터럴은 단언이라 그대로 |
| `userError` | execute/compiler_client.go | execute/errors.go |
| `uploadError`, `execFailure` | execute/handler.go | execute/errors.go |
| `failClass` | `(*handler).failClass` (handler.go) | 패키지 함수 `failClass` (errors.go). handler 필드를 쓰지 않아서 |
| SpanMessage 규칙 | 주석으로만 있었음 | errors.go 상단 주석 + `var _ telemetry.Classified = (*userError)(nil)` 등 세 타입의 컴파일 타임 단언. execute에 인터페이스를 새로 선언하지 않고 기존 `telemetry.Classified`를 기준으로 삼음(계획 승인됨) |
| `classRe`, `classFromHeader` | compiler_client.go | 그대로 (compiler 응답 파싱이라서) |
| ServeHTTP 본문 (110줄) | handler.go | `readRequest` / `acquireSlot` / `compile` / (기존) `execute` / `upload` / `writeResult`로 나눔. ServeHTTP는 25줄 |
| env 기본값 읽기 (`os.Getenv` + 빈 값 체크) | cmd/api 3곳, cmd/compiler 2곳 | `httpserver.Getenv(key, def)` (backend/internal/httpserver) |
| 서버 시작 + signal 대기 + Shutdown + ErrServerClosed 처리 + listening/shutdown/stopped 로그 | cmd/api, cmd/compiler 각각 | `httpserver.Run(ctx, log, name, addr, handler, shutdownTimeout, listenAttrs...)`. 상한은 api 60s(상수 `shutdownTimeout`, 근거 주석은 cmd/api에 둠), compiler 20s. 순서는 Shutdown → "<name> stopped" 로그 → 호출자의 `tel.Shutdown()` flush로 같음 |
| compiler `cleanWorkDir` 호출 시점 | 시작 시 1회 (telemetry.Setup 뒤, NewRunner·서버 시작 전). Shutdown 뒤 정리는 없음 | 같은 위치 (httpserver.Run 전) |

### 된 것
- VM docker(`golang:1.27.3-trixie`)에서 `gofmt -l` / `go vet ./...` / `go test -count=1 ./...`를 돌렸다. 기준선과 커밋 4개 각각에서 모두 통과했다.
- `git diff origin/main -- '*_test.go'` 결과 0줄 (단언 변경 0건).
- `make build deploy`를 돌린 뒤 m1-03, m1-04, m2-01, m2-03, m2-04, m3-02, m5-01, m6-04 verify가 전부 ALL PASS.

### 안 된 것
- `make clean && make`와 전체 verify는 돌리지 않았다 (지시에 따름: backend 코드만 바뀌었고 Makefile/k8s 변경이 없음. 전체는 F-M6-02 새 VM에서 돌린다).
- httpserver 패키지에는 단위 테스트를 추가하지 않았다. 기동과 shutdown은 m1-03, m2-01, m6-04가 확인한다.

### 추가 제안 (이번 범위 밖, 하지 않음)
- `/healthz` 핸들러가 cmd 2곳에 중복 → `httpserver.Healthz`
- 400/413/429 JSON 응답 쓰기(Content-Type + WriteHeader + Encode)가 중복 → writeJSON helper
- `otelhttp.NewHandler(... WithSpanNameFormatter ...)` 패턴이 execute.NewHandler와 cmd/compiler에 중복
- `"rust"` 리터럴이 handler, files, InitMetrics에 흩어져 있음 → 상수
- compiler_client.go의 internal_error 문구가 한국어이고 응답 message에 그대로 노출됨 (바꾸면 동작이 달라지므로 별도 피처)

### 다음 단계
- PR 리뷰 후 merge. 전체 verify는 F-M6-02에서.

## F-M6-05 repo-layout (브랜치 feat/m6-05-repo-layout)

F-M6-05에서 경로가 바뀌었다. **아래 과거 블록 본문의 경로는 고치지 않았다.** 옛 경로는 이 대응표로 읽는다.

### 옛 경로 → 새 경로 대응표
| 옛 경로 | 새 경로 |
|---|---|
| `HANDOFF.md` | `docs/HANDOFF.md` |
| `images.txt` | `k8s/images.txt` |
| `scripts/install.sh`, `cluster.sh`, `hosts.sh` | `scripts/setup/` |
| `scripts/build.sh`, `build-frontend.sh`, `image-tag.sh` | `scripts/build/` |
| `scripts/with-docker.sh` | `scripts/lib/with-docker.sh` (지시는 build/였으나 공용 래퍼라 lib/로, 계획 승인됨) |
| `scripts/prefetch-images.sh`, `import-images.sh`, `check-images.sh` | `scripts/images/` |
| `scripts/wait-backend.sh`, `wait-ingress.sh`, `wait-dashboards.sh` | `scripts/wait/` |
| `scripts/load.sh`, `ipfs-check.sh` | `scripts/tools/` |
| `scripts/verify/mX-NN.sh` | `scripts/verify/mX-NN-<브랜치 이름>.sh` (m0-01-skeleton-install … m6-04-stability, 신규 m6-05-repo-layout) |
| `scripts/verify/lib-pf.sh` | 그대로 |
| `dashboards/.gitkeep`, `frontend/.gitkeep`, `k8s/.gitkeep`, `k8s/dummy/` | 삭제 |

### 한 일
- git mv로 이동해 이력을 유지했다. 경로 문자열은 Makefile, scripts/ 전체, README.md, CLAUDE.md, k8s/images.txt 주석에서 고쳤다.
- 자기 위치 기준 경로를 한 단계 깊게 고쳤다: `cd "$(dirname …)/../.."`(build, build-frontend, cluster, prefetch, import, check-images), ipfs-check `ROOT`, image-tag `/../../$dir`, install `../lib/with-docker.sh`.
- Makefile에서 한 일:
  - `VERIFY_M1`과 `VERIFY_ALL`을 전체 이름으로 바꾸고 끝에 `m6-05-repo-layout`을 추가했다.
  - deploy의 `-n dummy delete … dummy-*` 줄과 그 주석을 제거했다. k8s/dummy는 이미 apply되지 않고 있었다.
- verify 검사 변경 (계획 승인됨):
  - m0-01: `.gitkeep` 존재 검사를 제거하고, 파일 검사를 `docs/HANDOFF.md`로 바꿨다.
  - m0-02: `OUR_NS="dummy"`와 8번 검사(dummy namespace resources)를 제거했다. m0-01과 m0-02는 `make verify`에 포함되지 않는다.
- 주석 수정 (동작 변경 없음, 사용자 지시):
  - `backend/internal/execute/files.go:22`의 `scripts/verify/m3-02.sh`를 `m3-02-ipfs-upload.sh`로 바꿨다.
  - `k8s/app/backend.yaml:65`의 `dummy(k8s/dummy)`를 `frontend (k8s/app/frontend.yaml)`로 바꿨다.
- 신규 `scripts/verify/m6-05-repo-layout.sh`를 추가했다. 먼저 실패 상태로 커밋했다(643d68e). 검사 항목은 루트 파일 목록, .gitkeep 0개, k8s/dummy 없음, 옛 경로 0건(Makefile, README, CLAUDE.md, scripts, backend, k8s, frontend Dockerfile), Makefile이 참조하는 스크립트와 VERIFY_ALL 스크립트의 존재다.

### 된 것 / 안 된 것
- 검증표 참고.
- 고치지 않은 것:
  - 과거 HANDOFF 블록 본문
  - m3-01과 m4-02의 dummy 부재 검사 (`k8s/dummy/*.yaml` 없음, `dummy-*` 리소스 없음). 계속 통과하므로 유지했고, m6-05의 `k8s/dummy` 검사에서 이 두 파일만 예외로 둔다.
- files.go 주석 변경으로 backend 소스 hash가 바뀌어서, backend와 compiler 이미지 태그가 바뀌었다(`src-99f734e63e98` → `src-2711ced6eb57`). image-tag.sh는 backend/ 아래 모든 파일 내용을 입력으로 쓴다. 그래서 이 PR을 배포하면 backend와 compiler pod가 한 번 재시작된다. backend.yaml 주석만으로는 재시작되지 않는다(검증표).

### 다음 단계
- 다른 브랜치나 worktree(예: `../ft_lgtm_fe`)에서 옛 경로로 작업 중이면 rebase 시 경로 충돌이 난다. 위 대응표로 옮긴다.

### 검증표
| 주장 | 확인 방법 | 결과 |
|---|---|---|
| m6-05는 구현 전 실패 | 643d68e 시점 VM `bash scripts/verify/m6-05-repo-layout.sh` | 확인(VM): exit 1, `RESULT: 10 건 실패` |
| backend.yaml 주석 변경만으로는 live 객체가 바뀌지 않음 | `make clean` 전 기존 클러스터에서, 배포 중인 이미지(`src-99f734e63e98`)로 새 backend.yaml을 렌더링해 `kubectl diff -f -` | 확인(VM): `kubectl diff exit=0` (차이 없음) |
| 새 구조로 처음부터 빌드/배포 | VM `make clean && make` | 확인(VM): `MAKE_EXIT=0` |
| 전체 verify (m6-05 포함) | VM `make verify`, 로그 `~/lgtm-logs/m6-05-verify-all.log` | 확인(VM): `VERIFY_EXIT=0`, `verify: ALL PASS`. m6-05는 PASS 43건, `RESULT: 모두 통과` |
| 재배포 시 backend 재시작 없음 | `make deploy` 재실행 전후 backend deployment generation과 pod 이름 비교 | 확인(VM): gen 3 → 3, pod `backend-965449c4b-ld8nz` 동일. kubectl 출력은 `deployment.apps/backend configured`였으나 generation이 그대로라 spec 변경은 없음 |
| m0-01 (make verify 밖) | VM `bash scripts/verify/m0-01-skeleton-install.sh` 1회 | 확인(VM): exit 0, `RESULT: 모두 통과` |
| m0-02 (make verify 밖) | 실행 안 함. 4번 검사(세 호스트 본문이 서로 다름)는 이 피처와 무관한 기존 검사 | 해당 없음 |

## F-M6-01 readme (브랜치 feat/m6-01-readme)

### 한 일
- `README.md`(영어, 신규): 첫 줄 이탤릭 + Description / Instructions / Architecture(Mermaid 2개) / Technical choices / Security model / Observability / IPFS and NAT / Demo walkthrough / Make targets / Known limitations / Resources(`### Use of AI`). 출처는 PRD 1·2·4·5·7~11장, HANDOFF, Makefile, images.txt, k8s/, 코드(제한값은 `wasmexec.go`, `runner.go`, `compiler.yaml` 로 대조). 스크린샷 없음, 코드·manifest·Makefile 동작·PRD 변경 없음.
- `docs/evidence/ipfs-check-utm-bridged-20261023.txt`(사용자가 실행한 `make ipfs-check` 출력), `docs/evidence/ipfs-check-utm-shared-20261023.txt`(VM `~/lgtm-logs/m3-03-run3.log` 를 그대로 복사, 헤더 1줄만 추가). README 의 IPFS and NAT 표가 링크한다.
- `scripts/verify/m6-01.sh`(먼저 실패 상태로 커밋 7129ab7) + `Makefile` `VERIFY_ALL` 끝에 `m6-01`(목록만, 동작 변경 아님).

### README 에서 정한 표현 (사용자 지시)
- UTM Bridged `first_blocked=router`, Shared `first_blocked=utm` 은 둘 다 **추정(inferred)** 으로 쓰고 `docs/evidence/` 로 근거를 단다. Bridged 에서도 public gateway 0/5.
- ipfs.io: 종료 날짜를 쓰지 않는다(공지가 ipfs.io 를 명시하지 않음). curl 429, 브라우저 흉내 403, "service worker gateway 로 전환 중, 브라우저 동작은 측정 안 함" 만 쓴다.
- Use of AI: Claude Code 는 git/HANDOFF/CLAUDE.md 로 확인한 사실만(`4d34bde` 기준 non-merge 93개 중 trailer 89개, trailer 없는 4개는 `d86043d` 와 CLAUDE.md 규칙 수정 3개, merge 21개; 모두 명령으로 센 값). claude.ai chat 사용은 사용자 제공 문장이며 git 으로 확인 불가라고 README 에 명시.

### 된 것 / 안 된 것
- 검증표 참고.
- 남은 자리표시: `【login】` 은 `taebkim` 으로 교체됨, `【F-M6-04 결과】` 는 F-M6-04 블록 기준으로 채움(배포 직후 504 는 해소로 Make targets 아래 "Rolling restarts" 한 단락으로 이동, `make verify` 전체는 F-M6-02 에서 확인 예정이라 Known limitations 에 1줄), `【사람이 직접 한 작업·검토 범위】` 는 사용자 제공 문단으로 교체됨(Use of AI 의 "What the author did", git 으로 확인 불가라고 README 에 표시).
- README 의 "호스트 PC 접속" 은 옵션 안내이며 verify 대상이 아니다. 사용자 확인: Mac 에서 UTM Shared VM IP(192.168.64.x)로 ssh 접속됨. 호스트 브라우저 접속(호스트 /etc/hosts 수정)은 확인하지 않았고 README 에 그렇게 적었다.
- 이미지/버전 번호가 바뀌면 README Technical choices 표도 고쳐야 한다(m6-01.sh 가 불일치를 FAIL 로 잡는다).

### 다음 단계
- F-M6-02 에서 `make verify` 전체를 확인한 뒤 README Known limitations 의 해당 줄을 갱신.
- origin/main(F-M6-04) merge 완료: Makefile `VERIFY_ALL` 에 `m6-04 m6-01` 둘 다, HANDOFF 에 두 블록 모두 남김.

### 검증표
| 주장 | 확인 방법 | 결과 |
|---|---|---|
| README 없이 m6-01.sh 는 실패하는 상태로 먼저 커밋 | 커밋 7129ab7 (스크립트는 README 없으면 `FAIL: README.md 없음` 후 exit 1) | 코드로 확인(실행은 안 함) |
| m6-01.sh ALL PASS: 첫 줄 문구, 필수 섹션 3개 + `### Use of AI`, README 의 make 타겟이 Makefile 에 존재, 저장소 경로/링크 존재(`docs/evidence/` 포함), 버전이 images.txt / Makefile / go.mod / package.json 과 일치 | VM `lgtm-vm` 에서 `bash scripts/verify/m6-01.sh` 1회, 로그 `~/lgtm-logs/m6-01-verify.log` | 확인(VM): exit 0, PASS 52건, FAIL 0, `m6-01: ALL PASS` |
| 남은 자리표시 3개 | 같은 로그 INFO | 이 시점(merge 전) 3개. 이후 모두 채워 0개 (아래 merge 후 행) |
| README 의 URL 3개와 make 명령이 실제와 일치 | URL 은 `scripts/hosts.sh` 의 host 3개와 `k8s/app/frontend.yaml` ingress host 대조, make 명령은 m6-01.sh 3번 검사 | URL: 사람이 대조(스크립트는 URL 을 검사하지 않음). make: 확인(VM) |
| README 의 숫자(93 / 89 / 4 / 21) | `git log 4d34bde --no-merges` / `--merges` + `grep -c '^Co-Authored-By: Claude'` | 확인(macOS 의 git 명령 출력. 저장소 이력이라 호스트 무관) |
| `make verify` 전체 | 실행 안 함: 이 피처는 문서 + verify 목록 추가뿐. VM 에서는 m6-01 만 1회 | 해당 없음 |
| origin/main(F-M6-04) merge 후 m6-01.sh ALL PASS, 자리표시 0개 | VM `bash scripts/verify/m6-01.sh`, 로그 `~/lgtm-logs/m6-01-verify3.log` | 확인(VM): exit 0, PASS 52건. 같은 날 첫 실행(`m6-01-verify2.log`)은 README 의 `192.168.64.x` 를 버전 `192.168.64` 로 오인해 FAIL 1건 → 스크립트의 버전 정규식이 `.x` 뒤를 제외하도록 수정 후 재실행 통과 |
| Makefile `VERIFY_ALL` 에 m6-04 와 m6-01 둘 다, HANDOFF 에 두 블록 | merge conflict 해결 후 `grep` / 파일 확인 | 확인(macOS 파일 내용) |

## F-M6-04 stability (브랜치 feat/m6-04-stability)

### 한 일
- `scripts/verify/m6-04.sh`(신규, 먼저 실패 상태로 커밋 28150e2) + Makefile VERIFY_ALL 끝에 `m6-04`. backend/compiler 는 rollout restart 중 POST /api/execute 60건(1초 간격, HTTP 200 + status=success), frontend 는 GET 30건. backend 는 재시작 때 처리 중이던 loop {} 1건이 끝까지 완료(200, timeout)되는지도 본다. 실패 시 pod/endpoint 타임라인 + 이벤트를 DIAG 로 출력. 백그라운드 타임라인 루프를 `wait` 하다 19분 멈추던 버그를 고쳤다(REQ_PIDS 만 wait, BG_PIDS 는 종료 때 kill).
- `k8s/app/backend.yaml`, `frontend.yaml`: `lifecycle.preStop.sleep.seconds: 10`. backend `terminationGracePeriodSeconds: 75`, frontend 30.
- `backend/cmd/api/main.go`: SIGTERM 후 `srv.Shutdown` 상한 10s → 60s (큐 대기 상한 45s + 처리 ≈ 15s). 큐 크기·timeout·대기 상한 값은 바꾸지 않았다.
- `scripts/verify/m2-04.sh`: increase() 불일치 시 `sum by (status)` 진단 출력 추가, 증가량 계산을 "현재 합계 - 기준 시각(T_BASE) 합계" 로 변경(구간에 counter reset 이 있으면 기존 increase()).

### 원인
1. **재시작 직후 504 (PRD 12장)**: Traefik 이 endpoint 제거를 늦게 반영해, 종료 중이거나 이미 사라진 old pod IP 로 요청을 보낸다. 연결 거부(502)가 아니라 SYN 이 버려져 정확히 30초 뒤 504 로 끝났다. 수정 전 m6-04 타임라인: backend r12(요청 시각이 old pod deletionTimestamp 직후), frontend r7(endpoint ready=false 로 바뀐 바로 그 시점) 이 각각 time_total 30.0s 504. "새 pod 가 Ready 전에 요청을 받음" 은 아니었다(새 pod 는 ready=true 가 된 뒤). compiler 는 Traefik 을 거치지 않아(ClusterIP) 수정 전에도 60건 통과라 변경하지 않았다.
2. **m2-04 executions 12/11**: 실행이 하나 더 들어온 것이 아니다. 진단 출력이 `timeout 10.71 + success 1.07 = 11.78`(rejected 도 10 → 11.27)로, 실제 증가 11 을 `increase()` 가 구간 가장자리로 외삽한 값이었고 11.5 를 넘으면 반올림해 12 가 됐다. 간헐이었던 것은 외삽 크기가 11.5 경계 근처였기 때문이다. 처음 가설("대기 중 끊김" 요청이 슬롯에서 실행됨)은 아니다: 그 검사(섹션 8)는 executions 검사(섹션 6) 뒤에 실행된다. 이전 HANDOFF(F-M5-03)의 `internal_error` 1건 귀속 불가 기록은 이 원인과 무관해 보이지만 확인하지 못했다.

### 된 것 (VM Debian 13, ssh lgtm-vm, 실제 실행)
- m6-04.sh: 수정 전 FAIL(backend 1/60, frontend 1/30 이 504 30s) → 수정 후 2회 연속 ALL PASS.
- m2-03 → m2-04: 수정 후 3회 연속 PASS. (수정 전에는 3회 모두 FAIL, 진단으로 원인 확인.)
- m5-02, m2-01: 각 1회 ALL PASS.
- PRD 12장 리스크(배포 직후 첫 요청 504): **해소로 본다.** 단 m6-04 2회 PASS 기준이고 Traefik 반영 지연의 상한은 측정하지 않았다(preStop 10s 는 여유값). 확인한 범위 밖: replicas 2 이상, 노드 부하가 큰 상황.

### 검증표
| 주장 | 확인 방법 | 결과 |
|---|---|---|
| 수정 전 rollout 중 504 재현 | `bash scripts/verify/m6-04.sh` (수정 전 코드) | 확인됨: backend r12, frontend r7 504 (30.0s), compiler 60/60 통과 |
| 수정 후 non-200 0건 | m6-04.sh 2회 | 확인됨: ALL PASS ×2 |
| m2-04 원인은 외삽 | 진단 출력 `sum by (status)(increase(...))` | 확인됨: 합계 11.78 (실제 11) |
| m2-04 수정 | m2-03 → m2-04 ×3 | 확인됨: 6회 모두 rc=0 |
| 영향받는 verify | m5-02, m2-01 각 1회 | 확인됨: ALL PASS |
| 전체 verify | 미실행 | **미실행, 이유: F-M6-02 에서 실행. 영향받는 verify: m6-04, m2-03, m2-04, m5-02, m2-01** |

### 안 된 것
- `make verify` 전체는 실행하지 않았다(다음 피처 F-M6-02 가 새 VM 에서 전체 실행). 완료 기준의 전체 exit 0 은 여기서 확인하지 않았다.
- README.md 의 【F-M6-04 결과】: origin/main 에 F-M6-01 이 merge 되어 있지 않고 README.md 도 없어 채우지 않았다.
- compiler 쪽 SIGTERM/preStop 은 수정 전 통과해서 손대지 않았다. keep-alive 가 끊기는 상황이 간헐적으로 나타나면 추가 필요.

### 다음 단계
- F-M6-01 merge 후 README 【F-M6-04 결과】 채우기, F-M6-02 에서 `make verify` 전체 확인.

## F-M5-03 dashboard-traces (브랜치 feat/m5-03-dashboard-traces)

### 한 일
- `dashboards/lgtm-traces.json`(신규): uid `lgtm-traces`, title `LGTM Traces`, refresh 5s. F-M5-02 provisioning(`make deploy` → ConfigMap → `wait-dashboards.sh`)을 그대로 썼고 코드·datasource 설정은 바꾸지 않았다. 패널 5개:
  - Trace duration over time (exemplar): Mimir `histogram_quantile(0.95, sum by (le) (rate(lgtm_execution_duration_seconds_bucket[$__rate_interval])))`, exemplar ON
  - Mean duration (exemplar): `sum(rate(_sum[$__rate_interval])) / sum(rate(_count[$__rate_interval]))` + bucket 쿼리(B, 선 숨김)를 exemplar 용으로 겹침
  - Longest duration: Tempo TraceQL metrics `{ name = "POST /api/execute" } | max_over_time(duration)`
  - Slowest executions: Tempo TraceQL `{ name = "POST /api/execute" }`, limit 200, table, sortBy `Duration` 내림차순. Longest 바로 옆(오른쪽)
  - 실패 trace(권장): `{ name = "POST /api/execute" && span.lgtm.status != "success" }` table
- Mimir 쿼리의 rate 구간은 Dashboard 1 과 같은 `[$__rate_interval]` 로 통일했다.
- `k8s/observability/tempo.yaml` 상단 주석만 3.x 기준으로 정정(설정 값·ConfigMap 내용 불변; 주석은 data 블록 밖).
- `scripts/verify/m5-03.sh`(먼저 실패 상태로 커밋 e992bba) + `Makefile` VERIFY_ALL 끝에 `m5-03`.

### PRD 해소 / 변경
- **PRD 14장 해소: Longest = TraceQL metrics, Tempo 설정 변경 없음, 실측 지연 약 50초(1회).** Tempo 3.1.0 은 `local_blocks` 가 제거됐고(3.0) TraceQL metrics 는 live-store/RF1 블록을 읽어 추가 설정 없이 동작한다. PRD 8.6 의 "local-blocks processor 필요" 문구와 다르다. 메모리는 쿼리 전 70Mi → 후 72Mi(limit 512Mi).
- **PRD 변경: 8.6 Slowest 의 `duration > 1s` 조건 제거. 이유: 정상 실행이 대부분 1초 미만이라 조건이 있으면 표가 비기 때문.** 대신 limit 200 + Duration 내림차순 정렬.

### 된 것
- 4개 필수 패널 쿼리가 `/api/ds/query` 로 non-empty, Slowest 정렬 정의가 응답 field 와 일치, duration 시계열 패널 3개(Trace duration / Mean / Longest) 응답에 exemplar, exemplar id 로 Tempo trace 조회 가능 (m5-03.sh ALL PASS, 40건).
- 수동 확인: 사용자가 VM Firefox 에서 직접 확인(2026-10-23), 스크린샷 없음. S4 5단계(실패 수 → exemplar → trace → Related logs → ipfs.cid 로 output.txt), S3 3건(timeout, memory_limit, truncated), Dashboard 2 패널 5개(exemplar 클릭, Slowest 정렬, 실패 trace 표).

### 알려진 사실 / 한계
- Slowest 정렬은 브라우저의 sortBy 가 한다. Tempo 응답은 최근 순이고 field `traceDuration` 의 표시 이름이 `Duration` 이다(verify 는 정의와 응답 field 이름을 대조).
- **TraceQL metrics exemplar 의 traceId 는 앞자리 0 이 빠져 30~31자로 올 수 있다.** Tempo 는 짧은 id 도 같은 trace 로 조회한다(HTTP 200, 동일 본문). verify 는 hex 1~32자 + 조회 성공으로 본다.
- Longest 의 exemplar 는 최댓값을 낸 trace 가 아닐 수 있다. 가장 긴 trace 는 Slowest 표에서 연다.
- 지연 약 50초는 새 trace 1회 측정이다. 이후 verify 는 기존 trace 가 있어 polling 0초였다(상한 120초).

### 안 된 것
- **`make verify` 전체 exit 0 아님 (완료 기준 7 미충족).** 전체 실행은 `m2-04` 에서 중단(exit 2)되어 뒤의 verify 는 개별 실행했다.
  1. `m2-04`: `lgtm_executions_total` increase() = 12 (기대 11). F-M5-01 때와 같은 증상(`m2-03` 직후). F-M5-01 에서 고친 wait_stable 이후에도 재발했다. 정보 수집 1회(`~/lgtm-logs/m5-03-m2-04-info.log`): 최근 30분 status 별 증가분에 `internal_error` 1건이 있었으나 어느 요청인지 귀속하지 못했다. 원인 미확인, 재현 시도 안 함.
  2. `m5-02`(개별 실행): backend 재시작 직후 첫 요청이 HTTP 504 `Gateway Timeout` (F-M5-02 에서 기록한 간헐 실패와 같은 위치). 원인 미확인, 재현 시도 안 함. 가설(미확인): rollout 직후 Traefik 이 이전 pod 로 보냄.
  3. 나머지(m1-01~m2-03, m3-01, m3-02, m4-01, m4-02, m6-03, m3-03, m5-01, m5-03)는 통과.
- 이 피처의 수정으로 인한 실패는 아니다(m5-03 은 Dashboard 2 와 tempo.yaml 주석만 추가). 다만 "전체 exit 0" 은 확인하지 못했다.

### 다음 단계
- F-M6-01 readme.
- 위 간헐 실패 2건(m2-04 12≠11, m5-02 재시작 직후 504)을 별도로 다룰지 결정.

### 검증표 (VM `lgtm-vm`, 로그 `~/lgtm-logs/m5-03-*.log`)
| 주장 | 확인 방법 | 결과 |
|---|---|---|
| 구현 전 m5-03.sh 실패 | `m5-03-red.log` | 확인(VM): FAIL 3건(파일·ConfigMap 키·uid 없음) |
| 구현 후 m5-03.sh 통과 (dashboard 존재/provisioned/refresh, 4개 패널 non-empty, rate 구간 통일, Slowest 정렬·limit, exemplar, Longest polling) | `m5-03-green2.log`, `make clean && make` 후 `m5-03-verify-rest.log` | 확인(VM): ALL PASS (40건 / 전체 실행 시 동일) |
| Tempo 설정 변경 없음, 주석 변경으로 재시작 없음 | deploy 전후 `tempo-0` restartCount 0, pod 생성 07:18:23Z 불변, 로그 `configmap/tempo-config unchanged` | 확인(VM) |
| Longest 값이 실제 최장 trace 와 같다 | spike: max 0.218s = Tempo search 최장 218ms | 확인(VM, spike) |
| exemplar 클릭 → trace 열림 | verify: exemplar id 로 Grafana→Tempo `/api/traces/<id>` 200 + root span; 수동: 사용자가 Firefox 에서 직접 | API 확인(VM) / 수동 확인(사용자, 2026-10-23, 스크린샷 없음) |
| S4, S3, 패널 5개 동작 | 수동 | 수동 확인: 사용자가 VM Firefox 에서 직접 확인(2026-10-23), 스크린샷 없음 |
| `make clean && make`, 이어서 `make` | `m5-03-clean-make.log`, `m5-03-make2.log` | 확인(VM): 둘 다 exit 0 |
| 전체 `make verify` exit 0 | `m5-03-verify-all.log`, `m5-03-verify-rest.log` | **미충족**: m2-04 FAIL 로 exit 2, 나머지는 개별 실행(m5-02 FAIL 1건, 그 외 통과) |

## F-M5-02 dashboard-metrics (브랜치 feat/m5-02-dashboard-metrics)

### 한 일
- **provisioning 구조는 새로 만들지 않았다.** F-M1-02 에서 이미 있던 것을 그대로 쓴다: `k8s/observability/grafana.yaml` 의 dashboards provider(`lgtm`, `/var/lib/grafana/dashboards`, `updateIntervalSeconds: 30`, `allowUiUpdates: false`)와 `make deploy` 가 `dashboards/*.json` 으로 만드는 ConfigMap `grafana-dashboards`. datasource 설정은 변경하지 않았다.
- `dashboards/lgtm-metrics.json`(신규): uid `lgtm-metrics`, title `LGTM Metrics`, `refresh: "5s"`, 기본 시간 범위 `now-1h`(제안), datasource 는 `{prometheus, uid: mimir}` 만 참조. 패널 9개:
  - 필수 stat 3개: 성공/실패/전체 = `sum(increase(lgtm_executions_total{status="success"|status!="success"|없음}[$__range]))`
  - 권장: 429 거절 수 stat, 실행 duration p95 timeseries(target `exemplar: true`), 단계별 p95(`sum by (le, stage)`, queue 포함), status별 비율 piechart, 큐 처리/대기 timeseries, output bytes 분포 heatmap
- `scripts/wait-dashboards.sh`(신규) + `make deploy` 의 grafana 대기 바로 뒤 한 줄: `dashboards/*.json` 의 uid 마다 Grafana 에서 title·패널 쿼리가 파일과 같아질 때까지 최대 150초 폴링. **시간 안에 확인되지 않은 uid 를 출력하고 exit 1 → make 실패.** (kubelet 볼륨 sync + 30초 스캔 때문에 deploy 직후에는 dashboard 가 비어 있을 수 있어서)
- `scripts/verify/m5-02.sh`(먼저 실패 상태로 커밋 b991837), `VERIFY_ALL` 끝에 추가. Grafana 는 Ingress 로 호출해서 port-forward 를 쓰지 않는다(포트 충돌 없음).

### PRD 해석 / 차이
- PRD 8.6 표의 성공/실패 쿼리는 raw `sum(lgtm_executions_total{...})` 이지만 같은 절의 주석("raw counter 는 재시작 때 0 으로 떨어진다. 성공/실패 패널도 같은 방식")과 요청에 따라 `increase(...[$__range])` 로 썼다.
- **UI 수정은 저장되지 않는다**: `allowUiUpdates: false` 라서 `POST /api/dashboards/db`·`DELETE` 가 HTTP 400 으로 거부되고, PVC 가 없어 Grafana pod 를 지우면 파일 기준으로 복원된다(m5-02.sh 가 확인). "다른 이름으로 저장"한 복사본은 pod 가 다시 뜨면 사라진다.

### F-M5-03 이 dashboard 를 추가하는 방법
1. `dashboards/<이름>.json` 을 추가한다(uid 고정, datasource 는 `{type, uid}` 로 `mimir`/`tempo`/`loki` 고정, `${DS_*}` 입력 변수 쓰지 않기).
2. `make deploy` — ConfigMap 이 `dashboards/*.json` 전체로 다시 만들어지고 `wait-dashboards.sh` 가 새 uid 가 올라올 때까지 기다린다. 코드 수정은 필요 없다.
3. 주의: `dashboards/*.json` 합계가 ~120KB 를 넘으면 `kubectl apply` 의 last-applied annotation(256KB 한도)에 걸린다. m5-02.sh 가 이 합계를 검사한다. 넘으면 `--server-side` 로 바꿔야 한다.
4. Tempo 패널은 datasource uid `tempo` 를 쓰고, `max_over_time(duration)` 은 Tempo `local-blocks`(metrics-generator) 설정이 먼저 필요하다(PRD 8.6, 현재 tempo.yaml 에 없음).

### 검증표 (VM `lgtm-vm`, 로그 `~/lgtm-logs/m5-02-*.log`)
| 주장 | 확인 방법 | 결과 |
|---|---|---|
| 구현 전 m5-02.sh 가 실패 | `m5-02-red.log` | 확인(VM): 7 PASS / 6 FAIL (dashboard 파일·wait 스크립트·uid 없음) |
| `/api/search` 에 고정 uid, `meta.provisioned=true`, refresh `5s` | `m5-02-final3.log` ALL PASS (45 PASS) | 확인(VM) |
| 모든 패널(9개, target 10개)의 쿼리가 `/api/ds/query` 로 실행되어 값이 있음 | 같은 로그 | 확인(VM). 부하는 20초 간격 2회(아래 참고) |
| 필수 3개 패널이 `stat` + `sum(increase(lgtm_executions_total...[$__range]))`, 성공 + 실패 = 전체(±0.01) | 같은 로그 | 확인(VM) |
| duration 패널 응답에 exemplar `trace_id`(32자리 hex) | 같은 로그 | 확인(VM): `/api/ds/query` 응답의 `trace_id` 필드. **브라우저에서 점을 클릭해 trace 로 이동하는 것은 확인하지 않음** |
| backend 재시작 후 필수 3개 값이 음수/0/감소 아님, 새 요청이 전체에 반영 | 같은 로그 | 확인(VM) |
| API 로 저장·삭제 시도 → 400, Grafana pod 삭제 후 같은 title·패널 수로 복원 | 같은 로그 | 확인(VM) |
| `wait-dashboards.sh`: 정상이면 exit 0, 없는 uid 는 이름을 출력하고 exit 1 | 같은 로그 | 확인(VM) |
| m5-02.sh 끝에서 backend/grafana Ready, ingress 연결, dashboard uid 재조회 | 같은 로그 | 확인(VM) |
| `make clean && make` 로 새 클러스터에서 dashboard 가 자동으로 올라옴 | `m5-02-clean-make2.log`: `CLEAN_MAKE_EXIT=0`, `dashboards ready: 1 file(s)` (2분 42초) | 확인(VM) |
| `make clean && make` 직후 m1-02.sh | `m5-02-m1-02b.log`, m5-02 뒤 `m5-02-m1-02c.log` | 확인(VM): 둘 다 59 PASS, `RESULT: 모두 통과` |
| 전체 `make verify` | 실행하지 않음 | 미실행 (CLAUDE.md: 이 피처 verify + 영향받는 m1-02 만. Makefile 변경이 있어 `make clean && make` 는 했다) |

### 실행 중 만난 문제
- **새 클러스터에서 단계별 p95 패널이 NaN(값 0개)**: 새 histogram series 는 첫 sample 만 있어 `rate()` 구간에 증가분이 없다. m5-02.sh 가 부하를 20초 간격으로 두 번 보내도록 고쳤다(운영 dashboard 쿼리는 그대로). 빈 패널은 첫 부하 직후 잠시 나타날 수 있다.
- **간헐 실패 1회, 원인 미확인**: 새 클러스터 직후 첫 m5-02 실행에서 backend 재시작 직후 요청 3건 중 1건이 HTTP 200 이 아니었다(그래서 "새 요청이 전체에 반영"도 FAIL, 17.34 → 18.19). 응답 코드를 남기지 않아서 모른다. 코드·본문·pod·traefik 로그를 남기도록 고친 뒤 m5-02.sh 를 1회 다시 실행했고 통과했다(재현 안 됨). **가설(미확인)**: rollout 직후 Traefik 이 종료 중인 이전 pod 로 한 요청을 보냄. 재현을 반복하지 않았다. 다시 나오면 `INFO: 재시작 후 요청 N: HTTP ...` 줄과 traefik 로그를 보면 된다.
- 첫 구현에서 `gpy ... | relay` 파이프가 subshell 이라 FAIL 카운트가 사라지는 버그가 있어 `relay < <(...)` 로 고쳤다(위 NaN 실패가 `FAILED` 로 집계되지 않던 문제).

### 안 된 것
- **스크린샷: 미확인, F-M5-03 수동 확인(VM Firefox) 때 함께 찍음.** (지시에 따라 브라우저 자동화와 ssh 터널은 시도하지 않았다.) 따라서 heatmap/piechart 가 실제로 보기 좋게 렌더되는지, `schemaVersion: 41` 이 Grafana 13.2.4 UI 에서 경고 없이 열리는지는 API 수준(쿼리 실행, provisioned 로드)까지만 확인했다.
- exemplar 점 클릭 → Tempo trace 이동은 수동 확인 대상(F-M5-03).

### 다음 단계
- F-M5-03: Dashboard 2(Traces) — Tempo 패널, `local-blocks`, `tracesToMetrics`. 위 "추가하는 방법" 참고. 스크린샷과 exemplar 클릭 확인을 함께.

## F-M5-01 instrumentation (브랜치 feat/m5-01-instrumentation)

### 한 일
- 현황 대조 결과 TR-01/03/04/05/06, 8.2 의 4개 metric, histogram bucket 은 M1~M3 에서 이미 PRD 와 같았다(다시 만들지 않음). 구현한 것은 아래뿐이다.
- **분류형 메시지 (TR-02)**: `telemetry/failspan.go`(신규) `FailSpan(span, class)` — status description 과 `exception` event(attribute `exception.message` 하나, `exception.type`/stacktrace 없음) 를 같은 고정 문구로 기록, 512바이트(UTF-8 경계) 절단. 기존 `RecordError(err)`/`SetStatus(err.Error())` 는 모두 제거.
  - compile_error: `rustc failed [E0425]`(stderr 첫 `error[Exxxx]` 의 코드만), deny-list `source denied [deny-env-macro]`, `compile timeout`. compiler 가 422 응답 헤더 `X-Lgtm-Class` 로 보내고 backend 는 정규식(`^(rustc failed|source denied)( \[[A-Za-z0-9-]{1,40}\])?$`)에 맞는 값만 쓴다(안 맞으면 `rustc failed`).
  - runtime_error: `exit code N`, `wasm trap [unreachable]`(TrapCode 고정 이름표, `Trap.Message()`/backtrace 는 사용 안 함), timeout `time limit exceeded`, memory_limit `memory limit exceeded`, 그 외 `runtime error`
  - 플랫폼 오류: `internal error [compile|execute]`, 업로드 `ipfs upload failed [timeout|http_5xx|http_4xx|connect|other]`(Kubo 응답 본문 제거, `ipfs.StatusError` 신설)
- **로그에도 같은 원칙**: `step()` 의 `ErrorContext` 는 사용자 입력이 섞일 수 있는 오류(`userError`, `execFailure`)면 `class` 만 남기고, 플랫폼 오류(Kubo 응답, 연결 실패 등)는 `class` + `error` 를 유지한다.
- **attribute**: rustc span `rustc.exit_code`(rustc 가 실제 종료한 경우만. 성공 0, 실패 N, deny/timeout 은 없음), `rustc.outcome`(`ok|compile_error|denied|timeout|canceled|internal`). 기존 `denylist.rule` 유지. root span `lgtm.status`(응답 status 9종: success/compile_error/internal_error/runtime_error/timeout/memory_limit/invalid_request/payload_too_large/queue_full). 값이 고정이라 cardinality 문제 없고, TraceQL 로 `{ name="POST /api/execute" && span.lgtm.status="timeout" }` 검색이 가능하다.
- **metric**: `lgtm_output`(unit `By`, 접미사 없음) → Mimir 저장 이름 `lgtm_output_bytes_{bucket,sum,count}` 로 실측 확인. 값=stdout+stderr 바이트 합, 실행이 끝난 요청만 root ctx 로 기록(exemplar 유지), label 없음. bucket `128, 512, 1024, 2048, 4096, 8192, 10240, 16384`.
- 단위 테스트: `execute/instrumentation_test.go`, `compile/instrumentation_test.go`(compiler rustc span 은 처음으로 tracetest 로 검증)
- `scripts/verify/m5-01.sh`(먼저 실패 상태로 커밋 56a5fb0), `make verify` 의 `VERIFY_ALL` 끝에 추가. port-forward mimir 27080 / loki 27100 / tempo 27200. 다른 verify 를 호출하지 않는다.

### PRD 해석 / 차이
- **PRD 해석: TR-02 의 에러 메시지 = 분류형 메시지. trace 와 로그 모두 사용자 입력 문자열 없음. 원문은 ipfs.cid 로 조회한다.** (원문 = 응답 JSON 의 message/stderr 와 업로드된 output.txt/status.json. 응답 JSON 은 바꾸지 않았다.)
- PRD 8.2 `lgtm_output_bytes` 는 "권장"이고 bucket 수치가 없다. 위 bucket 은 이 피처의 제안이다(10240 이 별도 경계라 잘린 출력이 `le=10240` 에 모인다).
- TR-02 의 업로드 실패 처리는 F-M3-02 해석 그대로(ipfs.upload 만 ERROR). 413/429/400 은 ERROR 아님(단위 테스트 `TestRejectedRequestsAreNotErrors`).

### 검증표 (VM `lgtm-vm`, 로그 `~/lgtm-logs/m5-01-*.log`)
| 주장 | 확인 방법 | 결과 |
|---|---|---|
| 구현 전 m5-01.sh 가 실패 | `m5-01-pre.log` | 확인(VM): 160 PASS / 49 FAIL (trace 원문과 Loki 에 rustc 식별자 노출, event 에 exception.type, `lgtm.status`/`rustc.*` 없음, `lgtm_output_bytes` 없음) |
| 7개 케이스(success, compile_error, deny-list, panic, exit 3, timeout, memory_limit)의 span 구성 · ERROR · error event(message 하나, ≤512B) · 분류 문구 · TR-03/04 값 일치 · `lgtm.status` · `rustc.*` | `m5-01-run2.log` ALL PASS (209 PASS) | 확인(VM) |
| trace 원문 전체와 Loki 로그(본문+structured metadata)에 고유 토큰(식별자, panic 메시지) 0건, trace_id 로그 7~11건씩 존재 | 같은 로그 | 확인(VM) |
| `lgtm_output_bytes_bucket` 저장 이름, `le` 에 10240 | 같은 로그 | 확인(VM) |
| `lgtm_execution_duration_seconds_bucket`, `lgtm_stage_duration_seconds_bucket` 의 `le` = PRD 8.2 | 같은 로그 | 확인(VM) |
| `lgtm_*` label 이름에 cid/sha/trace 없음(164 series), exemplar 가 trace_id 반환 | 같은 로그 | 확인(VM) |
| `go test ./internal/...` (docker `golang:1.27.3-trixie`) | m5-01.sh 안에서 실행 | 확인(VM) |
| `make clean && make`, `make` 연속 exit 0 | `m5-01-clean-make.log`, `m5-01-make2.log` | 확인(VM) |
| `make verify` 전체 exit 0 | `m5-01-fullverify.log` | **미확인: `VERIFY_EXIT=2`, m2-04 에서 중단.** 아래 참고. m2-04 는 수정 후 단독으로 2회 PASS, 전체는 재실행 안 함 |
| m1-01~m2-03 | 같은 `make verify` 실행 | 확인(VM): ALL PASS |
| m3-01, m3-02, m4-01, m4-02, m6-03, m3-03, m5-01 | m2-04 뒤라 `make verify` 가 실행하지 못해 같은 순서로 하나씩 실행 (`m5-01-rest-*.log`) | 확인(VM): 전부 exit 0. 단 `make verify` 한 번으로 통과한 것은 아님. m5-01 은 아래 스크립트 수정 후 `m5-01-run2.log` |

**m2-04 실패와 수정**: 전체 `make verify` 에서 `lgtm_executions_total ... increase() = '12' (기대 11)` 한 건만 FAIL (나머지 m2-04 검사는 PASS).
- 원인: 직전 스크립트(m2-03)의 요청이 reader 5초 주기 + collector batch 로 늦게 Mimir 에 들어와 m2-04 의 `increase(...[스크립트 시작 후 경과+15s])` 구간에 섞였다. 실패 직후 `sum by (status)(lgtm_executions_total)` 증가 시각을 조회하니 m2-03 의 마지막 요청(15:38:35)이 m2-04 시작 직후와 겹쳤다. 직접 재현으로 증명한 것은 아니고, 아래 수정 후 2회 PASS 가 이 진단과 맞는다는 것까지 확인했다. 이 피처는 `RecordExecution` 호출 횟수를 바꾸지 않았다.
- 수정(`scripts/verify/m2-04.sh`, 기대값 11/10 은 그대로): `wait_stable` 추가 — `lgtm_executions_total` 과 `lgtm_queue_rejected_total` 합계가 10초 간격 두 번 같을 때까지 대기(상한 60초). 시작 기준(`T_BASE`)을 안정된 시각으로 잡고, `poll_increase` 도 끝값을 읽기 전에 같은 방식으로 안정을 기다린 뒤 `increase(...[T_BASE 이후 경과+5s])` 를 읽는다(+5s 는 reader 주기 한 번분, 기준 앞 10초는 변화 없음이 확인된 구간).
- 확인(VM, `m2-04fix-*.log`): `m2-03.sh` 직후 `m2-04.sh` 를 2쌍 연속 실행, 둘 다 ALL PASS(27 PASS), executions 11 / rejected 10. 전체 `make verify` 는 다시 하지 않았다(그래서 위 "make verify 전체 exit 0" 은 여전히 미확인).
- 같은 문제 가능성이 있는 다른 `increase()` 사용(**목록만, 수정 안 함**): `scripts/verify/m3-02.sh:364` — 구간 `T_START+15s`, `ipfs_upload` stage count 증가가 **> 0** 인지만 보므로 직전 스크립트 요청이 섞여도 결과가 달라지지 않는다(정확한 개수 비교가 아님). 그 밖에 verify 스크립트의 `increase()`/`rate()` 는 m2-04.sh 뿐이고, m2-04 의 `stage queue count == stage compile count`(L225-232)는 raw 누적값 비교라 구간 문제가 없다.

**m5-01.sh 수정 1건**: 전체 실행 중 `[ml]` trace 에 rustc span 이 없어 1건 FAIL 했다. 원인은 `fetch_trace` 가 root 와 ipfs.upload 만 보이면 반환해서, 별도로 export 되는 compiler span 보다 먼저 가져온 것이다. rustc 까지 보일 때 종료하도록 고쳤고 이후 ALL PASS.

### 된 것 / 안 된 것
- 아래 검증표의 "확인(VM)" 항목만 실제로 실행한 결과다.
- 응답 JSON 에 exit_code 필드가 없어서 `exec.exit_code` 는 success=0, `process::exit(3)`=3 (응답 message `exit status 3` 와 대응), trap=nonzero(-1) 로 비교했다. panic 의 정확한 값 대조는 하지 않았다.
- compile timeout(15s), 컴파일러 내부 오류, 413/429/400 의 trace 는 m5-01.sh 가 요청하지 않는다(단위 테스트로만 확인).
- Mac 에서 돌린 `go test` 는 참고용이고 검증으로 치지 않는다.

### 다음 단계
- F-M5-02 (dashboard JSON + provisioning). TraceQL 은 `span.lgtm.status` 와 `lgtm_output_bytes_*` 를 쓸 수 있다.
- 로그에 남은 사용자 유래 문자열은 이 피처 범위에서는 없다(Loki 검사 통과). 단 pod 로그(DaemonSet 수집)는 아직 없는 구성이라 확인 대상이 아니었다.

## F-M3-02 ipfs-upload (브랜치 feat/m3-02-ipfs-upload)

### 한 일
- `backend/internal/ipfs/client.go`(신규): Kubo `POST /api/v0/add?wrap-with-directory=true&cid-version=1&raw-leaves=true&pin=true`. multipart 파트 이름 고정 3개, 응답은 줄 단위 JSON(실측 확인: 파일별 1줄 + `Name:""` 디렉토리 줄, Size 는 문자열), 3개 파일 엔트리와 디렉토리 CID 모두 있어야 성공. **keep-alive 끔** (아래 발견)
- `backend/internal/execute/files.go`(신규): 업로드 파일 3개. `main.rs`=코드 원문, `output.txt`=`--- stdout ---` / `--- stderr ---` 구분(+ truncated 면 마지막 줄 `--- truncated: output exceeded 10240 bytes ---`), `status.json`=고정 key 순서(status, message, exit_code, truncated, language, edition, rustc). timestamp·trace_id·timings 없음 → 같은 코드·결과면 같은 CID. 실행 전에 끝난 요청(compile_error 등)은 `exit_code: null`. `rustcVersion` 상수는 `Dockerfile.compiler` 태그와 m3-02.sh 가 비교
- `handler.go`: sleep stub·`fakeCID` 제거, `Uploader` 주입, `ipfs.upload` step 이 `context.WithTimeout(10s)` 로 호출. 성공 시 span+root 에 `ipfs.cid`, `cid`/`ipfs_url`(`http://ipfs.lgtm.local/ipfs/<cid>/`). 실패/timeout 이면 `cid`/`ipfs_url` JSON `null`. `IPFS_API_URL` env(`k8s/app/backend.yaml`, 기본 `http://kubo-api.ipfs.svc.cluster.local:5001`). 413/429/400 은 업로드 전에 return
- `scripts/verify/m3-02.sh`(먼저 실패 상태로 커밋 1a50ee1), `make verify` 에 추가(m3-01 뒤). port-forward 26080/26200

### PRD 해석 / 차이 (결정 반영)
- **PRD 해석: TR-02 의 root ERROR 는 실행 실패에만 적용한다. 업로드 실패는 부분 실패로 보고 `ipfs.upload` span 만 ERROR, root span 과 응답 status 는 유지한다.**
- `ipfs_url` 은 끝에 `/` 포함 (PRD 6.2 예시는 슬래시 없음, 지시에 따름). 실패 시 `cid` 도 `null` (PRD 6.2 는 ipfs_url 만 명시)
- 큐 슬롯은 `release()` 가 ipfs.upload 뒤라 업로드 시간까지 점유한다 (기존 구조 그대로). `maxQueueWait` 45s 는 변경하지 않고 주석만 갱신: 정상 최악(loop{}+업로드 0.2s ≈ 5.5s)은 8×5.5/2 ≈ 22s. Kubo 가 응답 없을 때 짧은 코드는 슬롯당 약 10.3s → 8×10.3/2 ≈ 41s < 45s 라 429 로 안 잘린다. loop{} 가 몰리고 Kubo 도 죽은 조합(≈15.4s)은 8×15.4/2 ≈ 61s > 45s 라 초과분은 429. **10초 업로드는 대기 상한(45s) 계산에 포함되며, 이 조합에서만 상한을 넘는다** (이 조합은 실측하지 않음, 계산값)

### 중요한 발견
- **keep-alive 를 끈 이유와 범위**: NetworkPolicy 는 새 연결만 막는다. keep-alive 가 켜진 첫 구현에서는 Kubo 5001 을 막은 뒤에도 재사용 연결로 업로드가 성공해서(m3-02 첫 실행) 차단 테스트가 성립하지 않았다. 클러스터 내부라 연결 비용은 무시할 만하다(실측 업로드 1~17ms). **범위는 IPFS client 전용 `http.Transport` 하나뿐이다**: `backend/internal/ipfs/client.go` 의 `New()` 가 `http.DefaultTransport.(*http.Transport).Clone()` 에 `DisableKeepAlives=true` 를 건다 (DefaultTransport 자체는 안 바꿈). compiler client(`execute/compiler_client.go`)는 diff 0줄, 전역 설정 변경 없음 (`grep DisableKeepAlives|DefaultTransport` 로 확인)
- **이 클러스터의 NetworkPolicy 는 차단 시 연결을 거부(REJECT)한다**: 차단 중 요청이 0.12~0.56s 에 실패. 그래서 NetworkPolicy 차단 검사로는 10초 timeout 경로를 못 잰다. **실제 10초 timeout 은 별도 검사로 실측했다**: `docker exec k3d-lgtm-server-0` 로 `ipfs daemon` PID 를 찾아 `kill -STOP` (커널은 연결을 받지만 응답이 없음) → 요청 → 응답 10.09~10.15s, `timings_ms.ipfs_upload=10001ms`, cid/ipfs_url null, 실행 status 그대로, `ipfs.upload` span ERROR, root 비-ERROR → trap 에서 `kill -CONT`, 5001 응답 복구 poll(실측 0.32s). 이 동안 Kubo 컨테이너 restartCount 0 → 0 (liveness/readiness 가 tcpSocket 이라 정지 중에도 통과). 종료 후 `ipfs daemon` 상태 S(실행 중), kubo-ingress 포트 5001 8080 4001 4001 복구 확인

### 검증표 (VM `lgtm-vm`, 로그 `~/lgtm-logs/m3-02-*.log`)
| 주장 | 확인 방법 | 결과 |
|---|---|---|
| 실패 상태 먼저 커밋 | `m3-02-red.log` (stub backend) | 확인(VM): 37 PASS / 28 FAIL (cid 형식, gateway 내용 불일치 등) |
| 정상 코드 → 200, cid(`bafy…`), `ipfs_url=http://ipfs.lgtm.local/ipfs/<cid>/`, main.rs 바이트 동일(`cmp`), output.txt/status.json 내용 정확 일치, 디렉토리 정확히 3개 | `m3-02-run2.log` | 확인(VM) |
| FE 형식 `http://ipfs.lgtm.local/ipfs/<cid>`(슬래시 없음) `curl -L` | 같은 로그 | 확인(VM): 최종 200, redirect 1회, 최종 URL 슬래시 포함, 본문에 main.rs/output.txt/status.json 목록. (브라우저에서 클릭한 것은 아님) |
| compile_error(문법·deny-list `include_str!`), timeout(`loop {}`), runtime_error(exit 3), truncated 모두 cid 있음, status.json status 일치(exit_code: null / -1 / 3), deny-list 업로드에 `/etc/passwd` 내용 없음 | 같은 로그 | 확인(VM) |
| `ipfs pin ls --type=recursive <cid>` 성공 (위 8개 CID) | 같은 로그 | 확인(VM) |
| 같은 코드 두 번 → 같은 CID, 다른 코드 → 다른 CID | 같은 로그 | 확인(VM) |
| 400/413 은 업로드 안 함 | pin 개수 전후 동일 | 확인(VM). 429 는 단위 테스트(큐 거부 경로가 업로드 전에 return) |
| Tempo: `ipfs.upload` span 과 root 의 `ipfs.cid` == 응답 cid, 성공 시 span 비-ERROR | 같은 로그 | 확인(VM) |
| Kubo 5001 차단(저장한 원본으로 복구): 차단 전 연결 성공(poll 상한 40s, 실측 0.09s) → replace → backend 라벨 probe pod 연결 실패(상한 40s, 실측 1.08~1.29s) → 요청 | `m3-02-run2.log`, `m3-02-final-verify.log` | 확인(VM): 응답 0.12~0.56s(13초 이내), status=success·stdout 그대로, `cid`/`ipfs_url` null, `ipfs.upload` span ERROR, root 비-ERROR, 실패 span 에 ipfs.cid 없음 |
| 복구: 저장한 원본으로 replace(kubo.yaml 재적용 안 함) → 5001 연결 성공(상한 40s, 실측 0.05~0.08s) → spec 이 차단 전과 동일 → 다음 요청이 다시 같은 CID | 같은 로그 | 확인(VM). 스크립트 종료 후 `kubo-ingress` 포트 5001 8080 4001 4001 |
| `lgtm_stage_duration_seconds_count{stage="ipfs_upload"}` increase > 0 | Mimir | 확인(VM) |
| backend 로그에 코드 원문(MARK) 없음 | `kubectl logs deploy/backend` | 확인(VM) (최근 15분 로그 기준) |
| `rustcVersion`(1.99.1) == `Dockerfile.compiler` 태그 | m3-02.sh | 확인(VM) |
| 단위 테스트 `go test ./internal/...` | **VM 에서 docker `golang:1.27.3-trixie` 이미지로 실행** (VM 에 Go 설치 안 함, m2-04 와 같은 방식). 개발 중 Mac 에서도 `go test ./internal/execute ./internal/ipfs` 실행했으나 그건 검증으로 안 침 | 확인(VM) |
| `make clean && make` exit 0 (144s), 재실행 `make` exit 0 (20s), `make verify` 전체 exit 0 (2755s, m3-02 포함) | `m3-02-final-make1/2.log`, `m3-02-final-verify.log` | 확인(VM) |
| **실제 10초 timeout**: Kubo daemon `kill -STOP` → 요청 | `m3-02-m-run.log`, `m3-02-m-verify.log` | 확인(VM): 정지 확인 poll(상한 40s, 실측 3.06s) 후 응답 10.09~10.15s(10~13s), `ipfs_upload=10001ms`, cid/ipfs_url null, status 그대로, `ipfs.upload` span ERROR, root 비-ERROR. `kill -CONT` 후 5001 복구 poll(상한 40s, 실측 0.32s), 복구 후 요청이 다시 같은 CID. **Kubo 컨테이너 restartCount 0 → 0** (두 번 모두) |
| origin/main(a843b1c, F-M3-03 포함) merge 후 `make build deploy` → m3-02.sh → `make verify` 전체 (make clean 은 앞서 수행해 생략) | `m3-02-m-build.log` `BUILD_DEPLOY_EXIT=0` 20s, `m3-02-m-run.log` `M302_EXIT=0` 73s ALL PASS, `m3-02-m-verify.log` `VERIFY_EXIT=0` 588s | 확인(VM). `VERIFY_ALL` = m1-01…m2-04, m3-01, m3-02, m4-01, m4-02, m6-03, m3-03 전부 포함, HANDOFF 블록 F-M3-02/F-M3-03/F-M6-03/F-M2-04 유지 |
| m3-02.sh 최종 | `m3-02-run2.log` | 확인(VM): 65 PASS, ALL PASS (약 52s) |

### 안 된 것 / 미확인
- 10초 timeout 은 `kill -STOP` 방식으로 실측했다. NetworkPolicy 의 패킷 drop(black-hole) 방식은 이 클러스터가 REJECT 라 재현하지 못했다 (STOP 은 커널이 연결만 받고 응답이 없는 경우로, 응답 없음 상황의 대표로 본다)
- frontend 는 수정하지 않았다. `ResultView.tsx` 는 `ipfs_url` null → "공유 링크 생성 실패(IPFS timeout)" 를 렌더링하는 기존 코드이며, 브라우저에서 실제 null 응답을 렌더링해 본 것은 **미확인** (frontend 단위 테스트는 `make build` 의 Docker build 단계에서 통과)
- Kubo 응답 지연(느린 add) 시의 업로드 시간 분포는 측정하지 않았다 (실측: 작은 디렉토리 1~17ms)
- ipfs.io 링크(ResultView 의 PUBLIC_IPFS)는 F-M3-03 에서 확인한 대로 현재 HTTP 요청이 거부된다. 이번 범위 밖
- origin/main(a843b1c, F-M3-03 포함)을 merge 해 `VERIFY_ALL` 과 HANDOFF 충돌을 해결했다 (둘 다 유지)

### 다음 단계
- F-M5-01 instrumentation (TR-03/04 나머지 attribute, bucket)

## F-M3-03 external-gateway (브랜치 feat/m3-03-external-gateway)

### 한 일
- `scripts/ipfs-check.sh` + `make ipfs-check` (make all 에 넣지 않음). `kubectl exec kubo-0 -- ipfs ...` 로 진단, 출력 형식 `[ipfs-check] S1..S9 PASS|FAIL|INFO|SKIP`, `GATEWAY <host> <code> <secs> <ok|mismatch|policy|noconn|fail>`, `CID`, `SUMMARY first_blocked=<vm-4001|utm|router|internet|none|unknown> reason=...`. gateway 실패는 exit 0
  - S1 VM 내부 4001 (kubo listen / docker 매핑 / 호스트 127.0.0.1:4001 multistream), S2 swarm peers, S3 우리 주소(공인·사설·`/p2p-circuit` 수, dcutr·relay client 프로토콜), S4 AutoNAT v2 reachability(`ipfs swarm addrs autonat --enc=json`), S5 8.8kB 테스트 파일(시각 포함) add+pin+`ipfs provide once`, S6 로컬 gateway, S7 delegated routing 에 우리 PeerID(광고됨, 최대 60s 재시도), S8 외부 ipfs-check 백엔드(도달 가능, 90s), S9 public gateway 5곳 병렬(각 90s)
  - 층 판정: S1 실패=`vm-4001`(증명), peers 0 또는 광고 안 됨=`internet`. AutoNAT Private 이면 VM 기본 게이트웨이가 `192.168.64.*`/`10.0.2.*` 일 때 `utm`, 다른 사설이면 `router` — **둘 다 VM 안에서는 추정(inferred)**. 단서로 기본 게이트웨이와 traceroute 의 사설 hop 수를 출력 (traceroute 없으면 "도구 없음", 설치 안 함)
- `scripts/verify/m3-03.sh` (먼저 실패 상태로 커밋 14d006d), `make verify` 에 m3-03 추가. public gateway 성공 여부는 통과 조건 아님
- 변경 없음: backend/, k8s/, UTM·공유기

### 실측 (VM lgtm-vm, 현재 환경: UTM QEMU 백엔드 + Shared Network, 포워딩 없음, 로그 `~/lgtm-logs/m3-03-run3.log`)
first_blocked=utm (inferred). 관측한 것:
- S1 PASS, S2 PASS(peers 16~41): VM 안과 아웃바운드는 정상
- S3: 공인 직접 주소 0개, 사설/loopback 6개, **relay(`/p2p-circuit`) 주소 5~6개(relay 노드 2개)**, dcutr·relay client 프로토콜 광고. `Swarm.RelayClient.Enabled`/`EnableHolePunching` 은 config 에 키가 없다 (`ipfs config` → not found = 기본값 사용. config.md v0.43.1 기본값 true). relay 주소를 실제로 얻으므로 relay client 동작은 확인
- S4: AutoNAT `Reachability: Private`, per-address 데이터 없음 → 밖에서 4001 직접 접속 불가
- S7: **delegated-ipfs.dev 에 광고됨** (provide 직후 0~30s 안). 단 Addrs 는 전부 `/p2p-circuit` (relay 경유 주소만). → "광고됨" ≠ "도달 가능"
- S8: ipfs-check 백엔드(`ipfs-check-backend.ipfs.io` = 15.204.31.98:443) 에 이 VM 에서 TCP 접속이 timeout (curl -4 `Connection timed out after 15003 ms`, IPv6 는 VM 에 경로 없음 `Network is unreachable`). **판정 불가(SKIP)**. 원인(서비스 다운/차단)은 확인 못 함
- S9: public gateway 5곳 모두 실패 (아래)

| gateway | 결과 | 의미 |
|---|---|---|
| ipfs.io | 429 (`switching to a service worker gateway only`), 브라우저 흉내 요청은 403 `blocked` | **HTTP gateway 서비스 종료/차단. NAT 와 무관** (gatewaychanges.ipfs.io: 2026-09-21 UTC 종료로 안내, 공지 페이지에 도메인 언급은 없음) |
| dweb.link | DNS 해석 timeout (VM 에서 `getent hosts dweb.link` 결과 없음) | NAT 와 무관 |
| gateway.pinata.cloud | 404 `timed out searching for a file on the non-pinata IPFS network` (62s) | 실제로 찾아봤고 못 받음 = 유일하게 의미 있는 부정 결과 |
| trustless-gateway.link | 525/522 (Cloudflare 오류, 20s) | gateway 쪽 문제 |
| 4everland.io | 504 (31s, 서브도메인으로 redirect) | 못 받음 |

- **relay 경유 소형 파일(8.8kB < 10kB) 실측 — 받아간 곳 없음**: ① 위 gateway 중 받은 곳 0. ② 독립 노드(VM 에서 `docker run ipfs/kubo:v0.43.1`, 별도 PeerID, 44 peers) 가 `ipfs cat /ipfs/<CID>` 를 시도: 120s timeout(우리 노드와 연결 0), 별도 시도에서 우리 relay 주소로 `ipfs swarm connect` 가 2번은 `success`였지만 직후 `cat --timeout=30s` 실패, 또 다른 시도에서는 `connect` 자체가 `all dials failed`. 우리 노드 bitswap `blocks sent: 0`. **관측된 사실만 기록한다: 연결(relay)은 될 때도 있으나 블록 전송은 한 번도 성공하지 않았다. 원인은 확인하지 못했다** (circuit v2 기본 limit 은 스펙에 없고 relay 별 설정. 의심: 제한된(relay) 연결에서 bitswap 이 동작하지 않을 수 있으나 검증 안 함). 원인 불명 간헐 실패라 정보 수집 후 추가 재현은 하지 않았다
- 포워딩 없는 현재 상태 결론: **public gateway 에서 열리지 않는다. relay/hole punching 으로도 이번 실측에서는 안 열렸다.**

### 된 것 / 안 된 것 (검증표는 아래)
- 된 것: `make ipfs-check` 가 끝까지 실행되고 층을 출력, 로컬 gateway 에서 테스트 CID 열림, relay 주소 획득·광고됨까지 확인
- 안 된 것: public gateway 에서 CID 열림(IP-06), 외부 프로브(S8). 이번 PR 에서 UTM·공유기는 변경하지 않음

### 검증표 (VM lgtm-vm, 로그 `~/lgtm-logs/m3-03-*.log`)
| 주장 | 확인 방법 | 결과 |
|---|---|---|
| `make ipfs-check` 가 끝까지 실행되고 S1~S9·GATEWAY·SUMMARY 출력, exit 0 | `m3-03-run3.log`, `m3-03-verify.log` | 확인(VM) 약 95s |
| m3-03.sh ALL PASS (19 검사: 형식, 로컬 gateway 200, 파일 8848B, HANDOFF 기록) | `m3-03-verify.log`, S7 판정 수정 후 `m3-03-verify2.log` | 확인(VM) |
| `make verify` 전체 exit 0 (m3-03 포함) | `m3-03-fullverify.log` `VERIFY_EXIT=0` 7m30s | 확인(VM). **단 이 실행은 S7 수정 전 스크립트**였고 수정 후에는 m3-03.sh 만 다시 실행 |
| origin/main(F-M2-04) merge 후 `make` exit 0, `make verify` 전체 exit 0 (m2-04, m3-03 모두 포함, Makefile VERIFY_ALL 에 둘 다 남김, HANDOFF 두 블록 유지) | `m3-03-merge-make.log` `MAKE_EXIT=0` 24s, `m3-03-merge-verify.log` `VERIFY_EXIT=0` 555s | 확인(VM). 이 실행의 ipfs-check 는 AutoNAT=**Unknown**(kubo 재기동 직후라 판정 데이터 없음으로 추정, 미확인), S7 은 60s 안에 광고 안 보임 → `first_blocked=utm` (inferred), reason 에 S7 지연 덧붙임. 수정한 판정 순서가 의도대로 동작 |
| S7 광고됨 | delegated-ipfs.dev | **실행마다 다름**: 0s, 30s 후 PASS, 한 번은 60s 안에 미반영(FAIL → 당시 스크립트가 `first_blocked=internet` 으로 오판해서 수정: 광고 지연은 AutoNAT Private 판정보다 뒤). 지연 원인은 미확인 |
| 포워딩 없는 현재 상태에서 public gateway 열림 | S9 | **안 열림 (0/5)**. 위 gateway 표 |
| relay 경유 소형 파일 전송 | 독립 Kubo 노드 `ipfs cat` | **받아간 적 없음**. 정확한 에러: `Error: context deadline exceeded` (cat, 120s·30s·45s timeout 3회). 별도로 `ipfs swarm connect <우리 /p2p-circuit 주소>` 는 `success` 2회, 다른 시도에서 `Error: connect ... failure: failed to dial: ... all dials failed`. 우리 노드 bitswap blocks sent 0 |
| S8 외부 프로브 | ipfs-check-backend.ipfs.io | 판정 불가 (TCP 15.204.31.98:443 접속 timeout) |

### PRD 영향 — 결정 필요
- **IP-06(`ipfs.io/ipfs/<CID>` 에서 접근) 은 NAT 를 해결해도 ipfs.io HTTP gateway 가 2026-10-23 현재 429/403 이라 충족할 수 없다.** subject V.1.4 의 "public gateway 에서 같은 CID" 는 열리는 다른 gateway(예: gateway.pinata.cloud 는 응답하며 조회함)로 보여야 한다. "PRD 변경: IP-06 ipfs.io → 응답하는 public gateway 목록(`ipfs-check` 가 확인), 이유: ipfs.io HTTP gateway 종료" — 승인 대기. 코드는 바꾸지 않았다

### README용 NAT 메모
- 되는 조건: VM 의 4001 tcp/udp 가 외부에서 직접 닿을 것 = AutoNAT `Public` + `ipfs id` 에 공인 직접 주소. 이 조건에서 DHT 에 직접 주소로 광고되고 gateway 가 bitswap 으로 받아간다 (이 조건은 아직 실측하지 못했다)
- 안 되는 조건(실측): UTM Shared Network(NAT) 뒤 + 포워딩 없음 → AutoNAT Private, 광고는 relay 주소만, gateway 에서 안 열림
- UTM (문서 확인, 변경은 사용자): "Port forwarding is only available on QEMU backend virtual machines using Emulated VLAN network mode" (docs.getutm.app/settings-qemu/devices/network/port-forwarding/). **현재 VM 은 QEMU + Shared Network 라 문서상 UTM 포워딩을 쓸 수 없다**(Shared 에서의 포워딩은 문서에 언급 없음 = 지원 문서 없음). 선택지: ① Emulated VLAN 으로 바꾸고 4001 tcp/udp 포워딩 + 공유기 포워딩(두 겹), ② Bridged(VM 이 LAN IP 를 직접 받음 → 공유기 포워딩 한 겹. 문서는 "advanced, Wi-Fi 는 추가 설정"만 언급, 포워딩과의 관계는 추론)
- 디펜스 대안: 모바일 핫스팟(통신사 CGNAT 면 인바운드 불가일 수 있음, 미검증), 공유기 포워딩 가능한 망, 안 되면 `make ipfs-check` 출력으로 막힌 층과 relay 한계를 설명
- ipfs.io 는 위 PRD 영향 참고
- **m3-03 verify PASS 의 의미**: "진단 스크립트가 끝까지 동작하고 정해진 형식으로 출력한다"이지 **외부 접근 성공이 아니다.** 같은 실행에서 S4 FAIL, S9 0/5 였다. README 에 "IPFS 외부 접근 확인됨"으로 쓰면 안 된다
- **ipfs.io 429**: 응답 본문이 `switching to a service worker gateway only`. 2026년 service worker gateway 전환 정책 때문으로 보이며(https://gatewaychanges.ipfs.io 에 종료 일정만 있고 ipfs.io/dweb.link 도메인을 명시하지는 않음), **브라우저에서의 동작(service worker 경유로 열리는지)은 측정하지 않았다.** curl 요청만 측정
- **relay(limited connection) 위 bitswap 이 동작하지 않는가 — 미확인(정황만)**: ① libp2p 스펙(https://raw.githubusercontent.com/libp2p/specs/master/relay/circuit-v2.md)은 relay 연결에 duration/data 제한이 있다고만 하고 protocol 별 opt-in 은 언급하지 않는다. ② go-libp2p `core/network/context.go` 의 `WithAllowLimitedConn` 주석: "instructs the network that it is acceptable to use a limited connection when opening a new stream". 기본 동작(옵션 없을 때 거부)은 그 주석에 적혀 있지 않아 **추론**이다. ③ boxo `bitswap/network/bsnet/ipfs_impl.go`(main 브랜치 raw, 질의 응답 기준)는 `NewStream`/`SetStreamHandler` 에 `WithAllowLimitedConn` 을 쓰지 않고 `conn.Stat().Limited` 연결은 건너뛴다. 단 이것은 **main 이지 Kubo v0.43.1 이 쓰는 boxo 버전이 아니다.** ④ 유사 사례: Helia `@helia/bitswap` 은 `runOnLimitedConnection` 옵션을 쓴다, discuss.ipfs.tech/t/connection-closes-during-bitswap-fetches/17041 는 relay data limit 으로 bitswap 이 끊긴 보고. 결론: 우리 실측(connect 는 되지만 블록 0)과 방향은 맞지만 **원인으로 확정하지 않는다 (미확인)**. 확정하려면 Kubo v0.43.1 의 go.mod boxo 버전 소스 확인 또는 `Swarm` 로그 수집이 필요

### 다음 단계
- F-M3-02 ipfs-upload (F-M5-01 instrumentation 은 F-M3-02 에 의존하므로 그 다음)
- 승인 필요: IP-06 문구 변경, UTM 네트워크 모드 변경(사용자 수행) 후 `make ipfs-check` 재실행

## F-M6-03 image-prefetch (브랜치 feat/m6-03-image-prefetch)

### 한 일
- `images.txt`(단일 출처, `<role> <image:tag>`): workload 6(mimir/loki/tempo/grafana/collector/kubo), build 5(golang/debian/rust/node/nginx-unprivileged), infra 3(`rancher/k3s`, `ghcr.io/k3d-io/k3d-proxy:5.9.0`, `k3d-tools:5.9.0`. helper 태그는 k3d 바이너리 `strings` 로 확인, VM 에서 실제 pull 됨 확인)
- `scripts/prefetch-images.sh [role..]`: 호스트에 있으면 skip, 없으면 `timeout 300 docker pull` 을 5회, backoff 5/10/20/40s. 마지막 실패 시 `ERROR: pull 실패 <이미지>` + exit 1. docker 명령(`PREFETCH_DOCKER`)·대기(`PREFETCH_SLEEP`) 주입 가능
- `scripts/import-images.sh`: workload 를 노드 containerd 로 import. 노드에 이미 있으면 skip(`ctr -n k8s.io images ls -q`, 이름 `docker.io/..` 정규화 매칭). 클러스터 없으면 skip
- `scripts/check-images.sh`: manifest `image:` ↔ workload, Dockerfile `FROM` ↔ build, `K3S_IMAGE`·`K3D_VERSION` ↔ infra, `:latest`/태그 없음, 모든 `image:` 다음 줄 `imagePullPolicy: IfNotPresent` (grep/awk, Mac 에서도 동작)
- Makefile: `cluster` 앞에 `prefetch infra`, `build` = prefetch → 자체 이미지 build/import → workload import, 단독 `make images`. `VERIFY_ALL` 끝에 m6-03
- `scripts/verify/m6-03.sh` (먼저 실패 상태로 커밋 3f17014)

### 중요한 발견 (cold 1차 실패 → 수정)
- **`k3d image import` 는 workload 6개에서 실패하는데 exit 0 으로 끝난다.** 로그: `ERRO failed to import images in node ... ctr: content digest sha256:... not found` 뒤에 `Successfully imported 6 image(s)`. 원인 추정: Docker 29.9.1 containerd 이미지 스토어에서 멀티아키 이미지를 `docker save` 하면 다른 플랫폼 blob 이 없음 (원인 자체는 미확인, `docker save --platform` 으로 해소되는 것만 확인). 그 결과 노드가 deploy 중 registry 에서 직접 pull (grafana 2m43s, loki 3m38s, mimir 3m02s, collector 2m58s, tempo 3m03s) → 이번 피처가 막으려던 timeout 경로 그대로. 자체 빌드 이미지(단일 플랫폼)는 영향 없었음
- 수정: `docker save --platform <uname -m 매핑> | docker exec -i <node> ctr -n k8s.io images import -` 로 직접 import 하고, import 후 노드에 실제로 있는지 다시 확인해 없으면 exit 1. **VM 은 aarch64** (`linux/arm64`). 처음 `linux/amd64` 로 시도해 실패 → `uname -m` 매핑으로 변경
- 자체 이미지 import(`build.sh`, `build-frontend.sh`)는 여전히 `k3d image import`. 단일 플랫폼이라 지금은 성공하지만 실패를 삼키는 점은 같다 (수정 안 함, 범위 밖)

### 된 것 (검증표, 모두 VM `lgtm-vm`, 로그 `~/lgtm-logs/m6-03-*.log`)
| 주장 | 확인 방법 | 결과 |
|---|---|---|
| 수정 전 cold: 노드가 workload 를 registry 에서 pull | `m6-03-cold.log` events | 확인(VM): make exit 0 이지만 745s, m6-03.sh 의 events 검사 FAIL (위 pull 시간) |
| cold(workload+infra 이미지만 rmi 후 `make clean && make`) exit 0 | `m6-03-cold2.log` | 확인(VM): `COLD_MAKE_EXIT=0 secs=560` (이 시간은 호스트의 인터넷 다운로드 포함) |
| cold 직후 m6-03.sh ALL PASS (14 검사: 목록 이미지 host/노드 존재, 불일치 0, workload 에 Pulling/Pulled 이벤트 0, `already present on machine` 12건, pullPolicy, 재시도 단위 테스트 3종) | 같은 로그 | 확인(VM) `M603_EXIT=0` |
| cold 후 재실행 `make` exit 0 | 같은 로그 | 확인(VM) `RERUN_MAKE_EXIT=0 secs=20` |
| warm: `/etc/hosts` 에 registry-1.docker.io, auth.docker.io, ghcr.io → 127.0.0.1 상태에서 `make clean && make` exit 0 | `m6-03-warm.log` | 확인(VM) `WARM_MAKE_EXIT=0 secs=173`, 직후 m6-03.sh ALL PASS, 재실행 exit 0. trap 원복 후 `diff /etc/hosts hosts.orig` 동일 |
| registry 차단 상태에서 `docker build` 가 FROM 때문에 실패하지 않음 | warm `make` 에서는 자체 이미지 3개가 `[skip] (이미 있음)` 이라 build 가 돌지 않았다. 그래서 차단(curl 000) 상태에서 3개 Dockerfile 을 따로 `docker build` (`m6-03-warmbuild.log`) | 확인(VM): 3개 모두 rc=0. **단 전부 레이어 캐시 히트(0s)**. 소스가 바뀐 재빌드(캐시 미스)는 차단 상태로 시험하지 않았다. 실패 시 대응 옵션은 아직 필요 없어 구현 안 함 |
| `make verify` 전체 (m1-01 … m6-03) | `m6-03-verify.log` | 확인(VM) `VERIFY_EXIT=0 secs=328` |
| 재시도 로직: N번째 성공 / 전부 실패(이미지 이름 출력) / 이미 있으면 pull 0 | m6-03.sh 6번 (가짜 docker) | 확인(VM) |
| 실제 pull 실패 후 재시도가 동작 | — | **미확인**. 이번 VM 실행에서는 pull 이 한 번도 실패하지 않아 `[retry` 로그가 나오지 않았다. 가짜 docker 단위 테스트로만 확인 |
| main 기준선 (prefetch 전) 소요 시간 | — | 생략 (지시). 기준선 = F-M3-01 의 pull timeout 실패 |

### 안 된 것 / 한계
- warm 차단은 `/etc/hosts` IPv4 매핑뿐이다. `getent` 에 registry-1.docker.io/auth.docker.io 의 IPv6 주소가 그대로 나왔다. `curl https://registry-1.docker.io/v2/` 는 5s 안에 000 이었으므로 차단된 것으로 봤지만, IPv6 경로가 완전히 막혔다는 증명은 아니다. 또 k3d 노드 컨테이너는 자체 hosts 라 차단되지 않는다: warm 에서도 k3s 시스템 이미지는 실제 인터넷으로 받았다 (아래)
- **k3s 시스템 이미지 측정 (구현 안 함, 승인 대기)**: 노드가 클러스터 생성 시 직접 pull 하는 8개 (`ctr images ls` 크기 합 약 172MiB): coredns 1.14.7 (20.7MiB, pull 43.5s), klipper-helm v0.13.3-build20260727 (64.7MiB, 28.9~32.9s), busybox 1.37.0 (1.8MiB, 6s), local-path-provisioner v0.0.37 (12.8MiB, 20s), metrics-server v0.9.0 (19.9MiB, 14.9s), klipper-lb v0.4.17 (5.5MiB, 5.1s), traefik 3.7.13 (47.7MiB, 16.7s), pause 3.10.2 (262KiB). 이 네트워크에서는 최대 43s 라 timeout 은 안 났지만, workload 이미지가 같은 네트워크에서 3분 걸렸으므로 느린 평가 환경에서는 같은 위험이 있다. 이벤트의 "in Ns" 는 파드별 값이라 같은 이미지가 중복 표시됨
  - 처리안 (a) k3s airgap tar(`/var/lib/rancher/k3s/agent/images/`)를 k3d `--volume` 으로 마운트: 이 tar 의 실제 파일명·크기·릴리스 URL 은 **확인하지 않았다** (구현 전에 WebFetch 로 확인 필요). 비용: 다운로드 1회 + host 캐시 디렉토리 + K3S_IMAGE 버전 연동. (b) host 에서 save 후 노드 기동 직후 import 는 k3s 가 이미 pull 을 시작한 뒤라 효과 약함
- k3d helper 태그는 k3d 버전과 짝(`check-images.sh` 가 K3D_VERSION 으로 검사)
- `make clean` 은 k3s 시스템 이미지 캐시를 지운다 (cluster 컨테이너와 함께 삭제)
- PRD 변경 없음

### 다음 단계
- F-M3-02 ipfs-upload 또는 F-M3-03 (외부 gateway/NAT 도달)
- 승인 시: k3s 시스템 이미지 airgap 처리 (위 (a), 별도 피처 또는 이 PR 후속)

## F-M2-04 limits-queue (브랜치 feat/m2-04-limits-queue)

### 한 일
- **PRD 변경: 8.2 stage 값에 queue 추가. 이유: 부하 시 실행 지연과 대기 지연 구분** (`lgtm_stage_duration_seconds{stage="queue"}`, 승인된 요청마다 기록, 대기 0 도 기록, 같은 bucket). `execution_duration` 은 root span 전체라 큐 대기가 섞인다
- 413 (BE-01, SEC-06): `r.ContentLength > 64KB` 면 본문을 읽지 않고 즉시 413 + `Connection: close`, 아니면 `http.MaxBytesReader(64KB)` 로 JSON 디코드 전에 읽는 양을 제한 (chunked 포함). 64KB 는 JSON 래핑 포함 body 전체 기준
- 큐 (BE-09, SEC-07/08): `backend/internal/limiter`. 처리 슬롯 채널(2) + 대기 카운터(CAS, 8). 슬롯이 없고 대기도 8이면 기다리지 않고 429. 대기 중 `r.Context()` 취소(클라이언트 끊김)면 카운터가 줄어 자리 반환. 큐 범위 = 디코드/검증(400/413) 통과 후 ~ ipfs.upload 끝(응답 쓰기 전에 release). 400/413 은 슬롯을 쓰지 않음
- **대기 상한 시간 45초** (`maxQueueWait`, handler.go): 최악 대기 = 앞 8개 × 요청 1건 소요 / 2. 정상 최악(loop {}: compile 0.25 + execute 5.1 + ipfs 0.1 ≈ 5.4s) 이면 약 22s (실측 20개 동시 시 마지막 요청까지 전체 26.99s). 이론 최악(15+5+10=30s)을 그대로 쓰면 120s 라 사용자가 기다릴 수 없어, 정상 최악의 약 2배인 45s 에서 429 (`queue.reason=wait_timeout`). 무한 대기 금지(SEC-08)
- 429/413/400 은 `lgtm_executions_total` 에 넣지 않음. 429 는 root span `queue.rejected=true`, `queue.reason=full|wait_timeout` + WARN 로그 1줄 + `lgtm_queue_rejected_total`. 413 은 `request.too_large=true` + WARN 로그. 대기 중 끊김은 `queue.cancelled=true` + INFO 로그(응답 없음). 승인된 요청 root span 에 `queue.wait_ms`
- metric: `lgtm_queue_rejected_total`(Counter), `lgtm_queue_active`, `lgtm_queue_waiting`(Int64ObservableGauge, label 없음, Mimir 이름 그대로 확인됨)
- counter series 0 초기화(`execute.InitMetrics`, 기동 시 1회): executions 의 6개 status × rust 와 queue_rejected. 이유: **increase() 가 첫 증가분을 놓치지 않게** (series 가 첫 증가 때 생기면 그 첫 증가분이 구간 안의 첫 sample 이 되어 increase 에서 빠진다)
- **-48 의 원인과 쿼리**: `m2-04-run1.log`. 쿼리는 `sum(lgtm_executions_total)` 의 **raw 값** 두 시점 차이였다 (`/prometheus/api/v1/query`, 기준 83 → 끝 35 = -48). 같은 label 의 series(`job,language,otel_scope_name,status`, pod label 없음)를 backend 재시작이 리셋하는데, Mimir 에는 이전 pod 의 마지막 값이 남아 있다가 새 pod 값으로 덮였기 때문. 즉 raw 값의 차이였고 구현 버그가 아니다. 그래서 m2-04.sh 의 counter 검사를 `sum(increase(<counter>[경과+15s]))` 기준으로 바꿨다 (리셋 보정, 외삽 때문에 정수로 반올림). gauge 와 `stage="queue"`(count == compile count 불변식)는 raw 비교가 아니다
- backend resources: request 64Mi, **limit 512Mi 유지** (아래 '메모리')
- `scripts/verify/m2-04.sh`(먼저 실패 상태로 커밋 5df36d3), `make verify` 에 m2-04 추가 (m2-03 뒤)

### 된 것 (검증표, VM `lgtm-vm` aarch64, 로그 `~/lgtm-logs/m2-04-*.log`)
| 주장 | 확인 방법 | 결과 |
|---|---|---|
| 구현 전 m2-04.sh 가 실패 | `m2-04-red.log` | 확인(VM): 14건 FAIL (413 없음, 429 0개, 200 20개 …) |
| 65KB body → 413, 0.01s, status=payload_too_large / 60KB 정상 → 200 / 깨진 JSON → 400 | m2-04.sh 1~4 | 확인(VM) |
| 본문을 다 읽지 않음: backend 에 Content-Length 5000000 만 보내고 본문 0바이트 → 413 (0.00s), Ingress 경유 실제 5MB → 413 (0.03s) | m2-04.sh 2 | 확인(VM) |
| 동시 20개(loop {}) → 429 정확히 10 / HTTP 200 정확히 10, 429 는 3초 안에 반환, 200 은 모두 status=timeout, 504 없음, 전체 26.99s | m2-04.sh 5 | 확인(VM) |
| Mimir `lgtm_queue_rejected_total` increase = 10 (burst 의 429 10건) | m2-04.sh 6 | 확인(VM, run3 및 `make verify`) |
| Mimir `lgtm_executions_total` increase = **11**. 근거: 60KB 정상 요청 1건(success) + 20개 burst 중 처리된 10건(timeout) = 실행이 시작된 요청. 제외(기대값에 안 들어감): 65KB 413 1, 5MB 413 1(Ingress), 깨진 JSON 400 1, burst 의 429 10건. (Content-Length 만 보낸 backend 직접 요청은 헤더만 보내고 끊으므로 핸들러가 413 만 쓰고 메트릭 없음) | m2-04.sh 6 | 확인(VM, run3 및 `make verify`) |
| 부하 종료 후 15초 안에 `lgtm_queue_active=0`, `lgtm_queue_waiting=0` (Mimir) | m2-04.sh 9 | 확인(VM, run3 2.09s) |
| `make clean && make` exit 0, 재실행 exit 0, `make verify` exit 0 (m1-04 기대값 수정 후, 아래 최종 실행 참고) | `m2-04-final2.log`, `m2-04-final3.log` | 확인(VM) |
| `stage="queue"` series 존재, count == `stage="compile"` count (대기 0 도 기록), bucket series 존재 | m2-04.sh 6 | 확인(VM) |
| gauge `lgtm_queue_active`=2, `lgtm_queue_waiting`>0 관측, 종료 후 둘 다 0 | m2-04.sh 5, 6 | 확인(VM) |
| 429 root span `queue.rejected=true`, 승인 요청 `queue.wait_ms` (Tempo) | m2-04.sh 7 | 확인(VM) |
| 처리 2 + 대기 8 이 찬 상태의 11번째 → 429, 대기 1건을 curl kill 로 끊으면 새 요청이 429 가 아니라 큐에 들어가고 504 없이 완료, 나머지 9건 200 (Ingress/Traefik 경유) | m2-04.sh 8 | 확인(VM) |
| 단위 테스트: limiter(즉시 거절, 취소 시 자리 반환, 대기 타임아웃, 상한), 핸들러(413 CL/chunked, 64KB 안쪽, 429 가 executions 미기록, rejected +1, stage queue 10) | VM golang 컨테이너 `go test ./internal/...` (m2-04.sh 9) | 확인(VM) |
| 배포 직후(`make build deploy` 바로 뒤) m2-04.sh | `m2-04-build2.log` → `m2-04-run2.log` ALL PASS | 확인(VM), 504 없음 |

### 메모리
- 실측 (VM, backend 재시작 후 9MB 를 쥐고 5초 spin 하는 서로 다른 코드 20건 동시: 처리 10(2씩) + 429 10, `m2-04-memprobe.log`): idle 11MB, 실행 중 memory.current 43~63MB, **memory.peak 70MB**, 재시작 0, OOMKilled 아님
- **결정: limit 512Mi 유지 (원래 값), request 64Mi.** 근거: 위 실측은 최악 케이스가 아니다 (처리 2건이 둘 다 10MiB 한도까지 쓰면서 큰 wasm 의 compile 응답이 겹치는 조합, 64KB body 10개 동시 버퍼는 측정하지 않았다). backend 가 OOMKill 되면 처리 2 + 대기 8 의 큐 전체가 사라진다. 256Mi 는 peak 의 3.8배였지만 최악을 못 재서 되돌렸다. 최악 케이스 실측은 안 된 것에 남긴다
- 이 설정(64Mi/512Mi)으로 아래 '최종 실행'의 전체 검증을 통과했다

### 실행 순서 (정직하게)
- m2-04.sh 첫 구현 실행(`m2-04-run1.log`) 4건 FAIL: (1) Content-Length 만 크고 본문 없는 요청을 Traefik 경유로 보내면 5초 timeout (Traefik 이 본문을 기다리는 것으로 보이나 원인 확인은 안 함) → 같은 검사를 backend 직접 + Ingress 경유 실제 5MB 로 분리, (2) `send_bg` 가 소요 시간을 안 남겨 429 속도 검사가 오검출 (스크립트 버그), (3)(4) executions 증가량 -48 (위 counter 리셋). 구현 코드는 (3) 때문에 0 초기화만 추가
- 그 뒤 `make build deploy` → m2-04.sh 한 번에 ALL PASS (`m2-04-run2.log`)

### 최종 실행 (PR 직전, VM lock 잡고 실행, 로그 `~/lgtm-logs/m2-04-*.log`)
- 이전 시도(`m2-04-final.log`)는 다른 세션이 같은 `~/lgtm` 에 `rsync --delete` 해서 m2-04 가 빠진 채 실행돼 무효였다 (이후 `~/.lgtm-vm.lock` 규칙을 CLAUDE.md 에 추가)
- `make build deploy` → `m2-04.sh` (increase() 기준, gauge 0 검사 포함) 한 번에 ALL PASS (`m2-04-run3.log`): rejected increase 10, executions increase 11, 부하 종료 후 2.09s 에 active=0 waiting=0
- `make clean && make` `MAKE1_EXIT=0`, 재실행 `MAKE2_EXIT=0` (`m2-04-final2.log`). 이어진 `make verify` 는 **m1-04 에서 FAIL**: `stage 값=['compile','execute','ipfs_upload','queue']`. PRD 8.2 stage 에 queue 를 추가한 결과 m1-04 가 stage 값 집합을 3개로 고정하고 있었다 (사용자 승인 PRD 변경의 필연적 결과라 범위 밖이지만 `scripts/verify/m1-04.sh` 기대값에 `queue` 만 추가)
- 그 뒤 `m1-04.sh` 단독 ALL PASS (`m2-04-m104.log`), 같은 클러스터에서 `make verify` 전체 `VERIFY_EXIT=0`, `verify: ALL PASS` (m1-01 ~ m2-04, m3-01, m4-01, m4-02, m6-03 `m2-04-final3.log`)
- 즉 "`make clean && make` 직후 첫 `make verify` 가 한 번에 통과"한 것은 아니다. m1-04 기대값 수정 후의 `make verify` 이고 `make clean` 은 그 사이에 하지 않았다. backend 이미지는 수정 전후로 바뀌지 않았다 (verify 스크립트만 수정)
- 이 실행에서 m3-03 은 이 브랜치의 VERIFY_ALL 에 없다 (다른 세션 브랜치)

### 안 된 것 / 열린 문제
- 대기 상한 45초(wait_timeout)에 의한 429 는 단위 테스트(limiter, 50ms 로 축소)만 확인했고 VM 에서 실제 45초를 기다리는 검증은 하지 않았다
- 클라이언트가 끊었을 때 자리 반환은 "새 요청이 429 가 아니라 큐에 들어감"으로 간접 확인했다. `lgtm_queue_waiting` 값이 8→7 로 줄어드는 것을 직접 관측하지는 않았다 (export 5초 주기)
- 최악 메모리 조합(처리 2건이 모두 10MiB 한도 + 큰 wasm compile 응답 겹침)은 측정하지 않았다. 실측은 peak 70MB 뿐
- `queue.wait_ms` 만 root span 에 두고 별도 child span 은 만들지 않았다 (TR-01 구조 유지)
- PRD 변경은 위 8.2 stage `queue` 1건뿐

### 다음 단계
- F-M3-02 ipfs-upload (ipfs.upload stub 교체. 이제 큐 슬롯이 ipfs.upload 끝까지 점유되므로 upload 10s timeout 이 슬롯 점유 시간과 대기 상한 45s 계산에 들어간다)

## F-M2-03 wasmtime-exec (브랜치 feat/m2-03-wasmtime-exec)

### 한 일
- `backend/internal/wasmexec`(신규): wasmtime-go **v50.0.0**(`github.com/bytecodealliance/wasmtime-go/v50`, 태그 v50.0.0 에 `build/linux-aarch64/libwasmtime.a` 60MB, `build/linux-x86_64/libwasmtime.a` 69MB 둘 다 있음. `gh api` 로 확인, main 에는 없고 태그에만 있음)
  - Engine/Linker 공유 + **전역 ticker 100ms 가 `IncrementEpoch`**, Store 마다 `SetEpochDeadline(51)` (요청별 타이머로 올리면 동시 실행 중인 다른 요청이 끊김. 51 인 이유: ticker 위상 때문에 50 이면 4.9초에 끊길 수 있음). 실측 loop {} execute 5.077s
  - `Store.Limiter(10MiB)`, WASI: preopen 없음·환경변수 없음·argv `["main"]`·stdin 설정 없음·socket 없음
  - **출력 캡처**: wasmtime-go v50 `WasiConfig` 는 `SetStdoutFile/SetStderrFile(path)` 와 Inherit 뿐 (pipe/writer 없음, `wasi.go` 소스 확인) → 파일 방식은 5초 동안 디스크에 무제한 쓸 수 있음. 그래서 `Linker.AllowShadowing(true)`(`linker.go:50-55`) 후 `DefineWasi()` 뒤에 `wasi_snapshot_preview1.fd_write` 만 Go 함수로 재정의. fd 1/2 → 요청별 stdout·stderr 버퍼 2개(합계 10240바이트, 초과분 버림 + truncated), 그 외 fd 는 EBADF(8), `nwritten` 은 요청 전체(프로그램은 정상 진행). 디스크에 쓰는 코드 경로 없음
  - 분류: `proc_exit` 0 → success / 그 외 → runtime_error(exit_code) / trap Interrupt → timeout / 그 외 trap → runtime_error / **memory_limit = (a) instantiate 실패(초기 메모리 > 10MiB) 또는 (b) `unreachable` trap + stderr 마지막 512바이트에 `memory allocation of … bytes failed`**. (b) 는 10kB 제한과 별개인 분류 전용 tail 이라 출력이 먼저 꽉 찬 뒤 OOM 이어도 동작하고 응답에는 포함하지 않음
- `internal/execute/handler.go`: stub 을 `Executor` 인터페이스(운영: `*wasmexec.Runner`)로 교체. execute span 에 `exec.exit_code`(종료 코드 없으면 -1) / `exec.timed_out` / `exec.output_truncated` / `exec.memory_limited` (성공·실패 모두). success 가 아니면 execute span 과 root span ERROR, 플랫폼 오류는 `internal_error`. `__slow__` 트리거와 stub 의 execute sleep 제거 (ipfs.upload stub sleep 은 유지)
- `backend/Dockerfile`: `CGO_ENABLED=1` (golang:1.27.3-trixie 에 gcc 있음), 런타임은 debian trixie 그대로
- `k8s/app/backend.yaml`: resources request 100m/128Mi, limit 1 CPU/512Mi (아래 실측)
- `__slow__` 대체(범위 11): `scripts/load.sh`, `m1-03.sh` 7번, `m1-04.sh` 라벨. 실제 2.2초 busy loop Rust (`Instant::now()` 후 `elapsed < 2200ms`). 처음 1.5초로 했다가 compile 이 약 0.25초라 전체 1.82초(<2s)가 되어 `make verify` 가 m1-03 에서 실패 → 2.2초로 수정
- `scripts/verify/m2-03.sh`(먼저 실패 상태로 커밋 806d7cf), `make verify` 에 m2-03 추가 (m2-02 뒤, m3-01 앞). 504 진단 출력 추가(아래)

### 된 것 (검증표, 모두 VM `lgtm-vm` aarch64, 로그 `~/lgtm-logs/m2-03-*.log`)
| 주장 | 확인 방법 | 결과 |
|---|---|---|
| arm64 에서 cgo 빌드·링크·실행 | `make build deploy` `m2-03-build1.log` `BUILD_DEPLOY_EXIT=0` | 확인(VM) |
| `make clean && make` exit 0, 재실행 exit 0 | `m2-03-final.log` `MAKE1_EXIT=0`, `MAKE2_EXIT=0` (이번에는 Docker Hub pull timeout 없음) | 확인(VM) |
| `make verify` exit 0 (m1-01 … m2-03, m3-01, m4-01, m4-02) | `m2-03-verify2.log` `VERIFY_EXIT=0`, 마지막 줄 `verify: ALL PASS` | 확인(VM). 아래 "실행 순서" 참고 |
| m2-03.sh ALL PASS (51 PASS) | run2, run3, run4, 롤아웃 직후 fresh1·fresh2 | 확인(VM) |
| loop {} → timeout, execute 5.077s, 전체 5.34s | m2-03 1번 | 확인(VM) |
| `vec![0u8;100_000_000]` → memory_limit / fs 읽기 → runtime_error, 응답에 `root:x:0:0` 없음 / TcpStream → 실패 | m2-03 2~4번 | 확인(VM) |
| 1MB 출력 → truncated, stdout+stderr ≤ 10240 / `loop{println}` → timeout + truncated + 10240 이하 | m2-03 5~6번 | 확인(VM) |
| 위 실행 동안 backend 재시작 0, OOMKilled 아님, cgroup `memory.peak` < `memory.max`, `/tmp`·`/var/tmp` 비어 있음, `readOnlyRootFilesystem=true` + volume 없음 | m2-03 6번 | 확인(VM) |
| env 0개, args 1개 / 정상 예제(frontend `EXAMPLE_CODE`) 출력 `total area = 19.85` / stdout·stderr 분리 / `exit(3)` → runtime_error / panic → runtime_error | m2-03 7~9번 | 확인(VM) |
| 10kB 출력 후 OOM → memory_limit + truncated, 분류 tail 은 응답에 없음 / 초기 메모리 20MB 모듈 → memory_limit | m2-03 10~11번 | 확인(VM) |
| **동시성**: loop {} 실행 중 hello 2건 success(execute 47ms), loop 만 timeout, hello 가 loop 종료 전에 끝남 | m2-03 12번 | 확인(VM) |
| Tempo: TR-04 attribute 4종, 실패 케이스(exit3, loop, loopp, mem) execute·root span ERROR, 성공(hello, big) ERROR 아님 | m2-03 13번 | 확인(VM) |
| 단위 테스트 (wasmexec: WAT 기반 17종 + 동시성/timeout, execute: status 매핑·attribute·ERROR) | VM golang 컨테이너 `go test ./internal/...` (m2-03.sh 14번) | 확인(VM) |

### backend 메모리 실측 (VM, 요청마다 9MB 를 쥐고 5초 spin 하는 코드를 동시 N건, backend 재시작 후 cgroup `memory.peak`, `m2-03-memprobe.log`)
| N | idle | peak |
|---|---|---|
| 0 | 11MB | 21MB |
| 1 | 9MB | 27MB |
| 4 | 11MB | 70MB |
| 8 | 12MB | 122MB |
| 16 | 9MB | 232MB |

동시 요청당 약 +14MB (guest 9~10MB + 나머지). 기존 limit 128Mi 로는 N=16 에서 OOMKilled 위험 → **limit 512Mi (N=16 실측의 2배 이상), request 128Mi**. 동시성 상한이 아직 없으므로 상한은 F-M2-04 에서 정할 것 (N=8 이면 약 122MB).

### 실행 순서 (정직하게)
- `make clean && make` → 재실행 → `make verify` 한 번에 돌린 `m2-03-final.log` 는 **m1-03 에서 실패**(느린 요청 1.82s, 위 설명). 그 뒤 스크립트만(load.sh, m1-03.sh) 고치고 같은 클러스터에서 `make verify` 를 다시 돌려 통과했다 (`m2-03-verify2.log`). 즉 "클린 클러스터에서 한 번에 verify 통과" 는 아니다. 고친 파일은 verify 스크립트뿐이고 backend 이미지는 `make clean` 이후 바뀌지 않았다
- 첫 `m2-03.sh` 실행에서 스크립트 버그 1건(`ls /tmp /var/tmp` 가 빈 디렉토리에도 헤더 출력) → `find` 로 수정

### 안 된 것 / 열린 문제
- **Gateway Timeout (원인 미확인)**: 코드 변경 후 `make build deploy` 직후 바로 돌린 m2-03.sh(`m2-03-build2.log`)에서 **첫 `loop {}` 요청이 HTTP 응답 본문 `Gateway Timeout` 으로 실패**했고 같은 실행에서 backend Ready 검사도 실패(종료 중인 이전 pod 가 같이 잡힘). 배포 직후 첫 요청은 평가자가 처음 Run 을 누르는 상황과 같다. 그 응답이 Traefik 의 텍스트인지 backend 응답인지, 헤더·소요 시간·Traefik 로그는 **수집하지 못했다**. 이후 **재현 안 됨**: run3, run4, `kubectl rollout restart deploy/backend` 직후 곧바로 m2-03.sh 2회(fresh1, fresh2) 모두 PASS 51개, DIAG 출력 0건. 워밍업으로 덮지 않았다
  - 다음 정보 수집을 위해 `m2-03.sh` 의 `run()` 이 HTTP != 200 이거나 JSON status 가 없으면 `diag_http` 로 응답 본문 앞 300바이트·응답 헤더·소요 시간·kube-system traefik 로그·backend pod 목록(Terminating 포함)·backend 로그를 stderr 로 출력한다. **이 진단 경로는 실제로 실행된 적이 없다 (미검증)**. 또 Ready 검사는 종료 중 pod 를 제외하고 pod 1개가 Ready 일 때까지 최대 120초 기다리도록 바꿨다
- **memory_limit 위장 가능**: 사용자가 `memory allocation of N bytes failed` 를 stderr 에 출력하고 abort 하면 memory_limit 으로 분류된다 (status 라벨만 영향, 보안 경계 아님). Rust 외 언어/다른 alloc handler 는 해당 없음. 또 memory_limit 판별은 C API 에 limiter 거부 콜백이 없어서 휴리스틱이다. instantiate 실패 판별은 wasmtime 에러 문자열 매칭(`memory` + `exceeds|limit|minimum`)이라 wasmtime 버전을 올리면 단위 테스트(`TestInitialMemoryOverLimit`)로 재확인해야 한다
- **동시성 상한 없음**: 동시 요청 수 제한·큐·413/429 는 F-M2-04. 지금은 요청마다 module compile + 최대 10MiB 가 쌓인다 (위 표)
- CPU limit 을 200m → 1 로 올렸는데 CPU throttling 은 측정하지 않았다 (loop {} 가 CPU 를 쓰므로 잠정)
- 미검증 가정: WASI stdio 를 설정하지 않았을 때 `fd_pwrite` 등 다른 쓰기 호출이 버려지는지(fd 1/2 의 `fd_write` 만 shadowing 했다). `proc_exit` 코드가 126 이상일 때 wasmtime 동작(단위 테스트에서 810 이 실패해서 6 으로 바꿈, 그 이유는 확인하지 않음)
- `go mod tidy` 가 `otlpmetricgrpc`, `otel/metric`, `otel/sdk/metric` 3줄을 `// indirect` 에서 direct 로 옮겼다 (이미 직접 import 하던 모듈, tidy 결과)
- 맥 spike(`rustc --target wasm32-wasip1`, macOS)는 가능성 확인용이고 검증으로 치지 않음

### 다음 단계
- F-M2-04 limits-queue (64KB 413, 429/큐, 동시 실행 상한 — 요청당 약 +14MB 와 backend limit 512Mi 기준으로 정할 것)
- Gateway Timeout 이 다시 나오면 `m2-03.sh` 의 DIAG 출력을 첨부해서 원인 조사

## F-M3-01 kubo-node (브랜치 feat/m3-01-kubo-node)

### 한 일
- `k8s/ipfs/kubo.yaml`: `ipfs/kubo:v0.43.1`(GitHub releases latest 2026-09-15, Docker Hub amd64/arm64 확인), StatefulSet 1 + PVC 5Gi, Service `kubo-api`(5001) / `kubo-gateway`(8080) 분리, Ingress `ipfs.lgtm.local` → gateway 8080 만, hostPort 4001 tcp/udp, NetworkPolicy `kubo-ingress`(5001 ← ns lgtm + app=backend 만, 8080·4001 은 전체)
- 설정은 ConfigMap `kubo-init` 의 `/container-init.d/001-lgtm-config.sh` 가 매 기동 적용 (수동 설정 없음): path gateway(`UseSubdomains=false`), `Gateway.NoFetch=true`, `Swarm.ConnMgr` basic 20/60/20s, `Swarm.ResourceMgr.MaxMemory=512MiB`·`MaxFileDescriptors=4096`, `Datastore.StorageMax=4GB`, `AutoTLS.Enabled=false`. 유지: DHT, bootstrap, AutoConf, relay client, UPnP. env `IPFS_TELEMETRY=off`, `DO_NOT_TRACK=1`, `GOMEMLIMIT=800MiB`
- securityContext: runAsNonRoot(uid 1000), allowPrivilegeEscalation false, drop ALL, seccomp RuntimeDefault, automountServiceAccountToken false, enableServiceLinks false. **readOnlyRootFilesystem=true 로 동작** (쓰기 경로는 `/data/ipfs` PVC 와 `/tmp` emptyDir 뿐. VM 에서 기동·add·재시작 정상, 루트 쓰기 실패 확인)
- resources: request 100m/256Mi, limit 1 CPU/1Gi
- `k8s/dummy/ipfs.yaml` 삭제, Makefile deploy 에서 `dummy-ipfs` 를 `delete --ignore-not-found`, 순서 observability → ipfs → app. dummy namespace 는 비어 있는 채로 남음. `wait-ingress` 의 ipfs 기대값은 `ipfs.lgtm.local/ipfs/bafkqaaa`(빈 identity CID)가 200
- `scripts/verify/m3-01.sh`(먼저 실패 상태로 커밋 123faa5), `make verify` 순서에 m3-01 추가 (m2-02 뒤)

### 된 것 (검증표, 모두 VM `lgtm-vm`, 로그 `~/lgtm-logs/m3-01-*.log`)
| 주장 | 확인 방법 | 결과 |
|---|---|---|
| `make clean && make` exit 0 | `m3-01-final.log` | **첫 실행 exit 2 (실패)**: observability 단계에서 `grafana/mimir:3.2.2` pull 이 `registry-1.docker.io` timeout (DeadlineExceeded), tempo rollout 300s 초과. kubo 단계 도달 전. 같은 체인의 바로 다음 `make` 는 exit 0 |
| 재실행 `make` exit 0 | 같은 로그 `MAKE2_EXIT=0`, 추가로 한 번 더 `m3-01-make3.log` `MAKE3_EXIT=0` | 확인(VM) |
| 이전 실행(kubo 단계 포함 `make clean && make` + 재실행, `m3-01-make.log`) | startupProbe 405 로 두 번 다 실패 → 수정 후 | 아래 "실패 이력" |
| `make verify` 전체 exit 0 (m1-01~m4-02, m3-01 포함) | `m3-01-final.log` `VERIFY_EXIT=0` | 확인(VM) |
| `m3-01.sh` ALL PASS: pod Ready/limit/PVC Bound/securityContext/uid 1000/telemetry off, 설정 키, ipfs add → gateway 200(301 아님)+내용 일치, 디렉토리 목록, `/api/v0/id` 404(POST·GET), Ingress 에 5001 없음, 없는 CID → 404 (0s), swarm peers 20, listen tcp/4001·quic-v1, hostPort, 호스트 4001 tcp/udp listen, 호스트 127.0.0.1:4001 에서 multistream 응답, pod 삭제 후 같은 CID·pin 유지 | `make verify` 안 m3-01 | 확인(VM) |
| NetworkPolicy 강제: 다른 ns pod → 5001 실패, lgtm/app=backend 라벨 pod → 5001 성공, 다른 ns → gateway 8080 성공, 정책 삭제 시 같은 pod 연결 **성공**(대조군), 복구 후 다시 실패 | m3-01.sh 7번 | 확인(VM) |
| Kubo 메모리 실측 | `kubectl top pod -n ipfs` | 53Mi / 50m (최종 `make` 후 idle), 90Mi / 133m (add·pin·peers 20 직후 측정). limit 1Gi, 재시작 0. 계획 예상 150~350MB 보다 낮음 |
| `ipfs.io` 등 외부 gateway 에서 CID 도달 | — | **미확인** (F-M3-03) |
| NAT 너머 4001 도달 (UTM/공유기 포워딩) | — | **미확인** (F-M3-03). 확인한 것은 VM 호스트 127.0.0.1:4001 까지 |

### 실패 이력 / 열린 문제
- 1차(`m3-01-make.log`): kubo startupProbe `httpGet /api/v0/version` 이 405 (Kubo `/api/v0/*` 는 POST 전용). 데몬은 `Daemon is ready` 였지만 probe 실패로 재시작 반복 → `tcpSocket: api` 로 수정 (커밋 fix: kubo startupProbe). 주의: StatefulSet 은 Ready 아닌 pod 를 롤링 업데이트하지 않아서 `kubectl delete pod kubo-0` 이 필요했다
- 2차: m3-01.sh 가 `lgtm-probe` ns 를 m2-02 와 공유 → m2-02 cleanup(`--wait=false`)이 아직 terminating 이라 probe pod 생성 실패. 그 상태에서 "차단" 검사가 pod 없음 때문에 **거짓 PASS** 가 됐다. 전용 ns `ipfs-probe` + 삭제 대기 + exec 가능 단언 추가. k3s 노드 컨테이너에 `nc` 없음 → 호스트에서 multistream 헤더 송수신으로 변경
- 최종 체인 첫 `make` 실패(위 표)는 Docker Hub pull timeout 으로 이번 변경과 무관해 보이나, 같은 VM 네트워크 문제가 새 VM 첫 `make` 에서 재발하면 감점 위험. 이미지 pull 재시도/사전 pull 은 이번 범위 밖이라 손대지 않음
- `scripts/verify/m0-02.sh` 는 dummy ns 에 파드 3개 이상을 기대한다 (`make verify` 에 없는 스크립트). 이번에 수정하지 않았고 현재 통과하지 않을 것으로 예상 (실행해 보지 않음)
- 로그에 `failed to sufficiently increase receive buffer size` (quic-go UDP 버퍼, 208KiB). 기능에는 영향 없었으나 QUIC 처리량은 줄 수 있음. `net.core.rmem_max` 는 VM 호스트 설정이라 건드리지 않음
- PRD 변경 없음

### 다음 단계
- F-M3-02 ipfs-upload: backend 가 `kubo-api.ipfs.svc.cluster.local:5001` 로 업로드 (NetworkPolicy 는 이미 lgtm/app=backend 허용). backend egress 정책이 생기면 5001 허용 필요. `ipfs.cid` attribute, 10s timeout

## F-M2-02 compiler-hardening (브랜치 feat/m2-02-compiler-hardening)

### 한 일
- `backend/internal/compile/denylist.go`: rustc 실행 전 소스 deny-list. raw 소스 + 주석 제거 뷰(중첩 `/* */` 인식, 문자열·raw string·char 안의 `//`는 주석 아님) 두 뷰를 모두 검사. 위반 시 422, 첫 줄 `error: LGTM 소스 정책 위반 [규칙ID] N행: 설명` (소스 줄 내용은 응답에 넣지 않음) → backend `firstErrorLine`이 그대로 `compile_error` message로 사용 (backend 수정 없음)
- 규칙: `deny-include-macro`(include_str/include_bytes/option_env 이름 단독, `include!`, 인자 위치 `include`), `deny-env-macro`(`env!`, 인자 위치 `env`), `deny-rename`(`include|env` 뒤 `as`), `deny-mod-file`(`mod 이름;`), `deny-path-attr`(`#[..path..]`, `cfg_attr(.. path =`), `deny-incbin`(`.incbin`)
- 인자 위치 규칙은 `use` 문을 지운 텍스트에서 찾는다 (`use std::{env, fs};` 오탐 방지). 재명명(`as`)은 원문 전체에서 잡는다
- `runner.go`: rustc 환경변수 `rustcEnv()`로 분리, PATH/RUSTUP_HOME/CARGO_HOME/HOME/TMPDIR 5개만 (상속 없음). 단위 테스트로 키 집합과 비밀값 미포함 확인
- `k8s/app/compiler.yaml`: `readOnlyRootFilesystem: true`, `enableServiceLinks: false`, NetworkPolicy `compiler-ingress`(app=backend → 8080), `compiler-egress`(kube-dns 53 UDP/TCP, observability/otel-collector 4317). `/tmp` emptyDir은 추가하지 않음 (VM 기동 결과로 확정, 아래)
- `scripts/verify/m2-02.sh` (먼저 실패 상태로 커밋 e34bf0c)

### 확정 결정 (PRD 변경)
- **PRD 변경: 7.3 수용 기준 (b) = 격리 + 소스 deny-list. deny-list에 PRD에 없던 `include!` 추가.** 이유: 결과가 IPFS에 영구 공개되므로 소스 단계 차단을 추가. `include!`는 파일을 Rust 소스로 끼워 넣어 rustc 에러 메시지에 파일 내용이 찍히는 경로
- 사용자 추가 지시로 `[(,\[{]\s*(?:\w+::)*(?:r#)?env\s*[),\]}]`(인자 위치 env)와 `deny-incbin` 포함

### rustc 실측 (Mac rustc, `rustc -` 로 stdin 컴파일. VM 검증 아님, 규칙 설계 근거)
- 동작함(= 우회 실재): `r#include_str!`, `std::r#env!`, `use std::env as e; e!(..)`, `use std::include_str as x; x!(..)`, `include_str /* /* */ */ !(..)`(중첩 주석), `m!(include_str)`/`m!(env)`/`m!(r#env)`(`$n:ident` 매개변수), `#[cfg_attr(all(), path = "..")] mod x;`
- 동작 안 함: `$p:path` 로 `$p!(..)` ("macro expansion ignores `!`")

### 한계 (의도된 오탐 / 미탐 가능성)
- 정규식 기반이라 **문자열·주석 안의 패턴도 차단**: `println!("include_str!")`, `// env!("X")`
- 인자 위치 규칙 때문에 **`f(env)`, `g(a, include)` 처럼 변수 이름이 env/include인 함수 인자 전달도 차단** (use 문 안은 제외). 테스트 `TestCheckSourceKnownFalsePositives`가 이 동작을 고정
- `#[..path..]`는 속성 안 어디든 `path` 단어면 차단 (`#[doc = "path"]` 오탐)
- 주석 제거 뷰는 완전한 lexer가 아님. 그래서 raw 뷰와 함께 검사한다. 정적 패턴은 완전하지 않으며 **최종 방어는 격리 계층**(read-only rootfs, 환경변수 명시 목록, SA 토큰 없음, NetworkPolicy)

### verify 구조 정리 (F-M4-02 후속 요청)
- verify 스크립트는 다른 verify 스크립트를 호출하지 않는다: m1-03의 m1-01/02 호출, m2-01의 `make verify-m1` 호출 제거, m2-02는 처음부터 호출하지 않음
- Makefile: `make verify` = m1-01 → m1-02 → m1-03 → m1-04 → m2-01 → m2-02 → m4-01 → m4-02 순차, 첫 실패에서 중단하고 FAIL 줄 출력. `make verify-m1`은 m1만. 둘 다 `run_verify` 매크로 공유
- `scripts/verify/lib-pf.sh`(공용 `pf_forward`/`pf_stop`): kubectl이 실제로 로컬 포트를 열었는지(`Forwarding from 127.0.0.1:PORT`)와 **포트마다 HTTP 응답(코드 != 000)** 을 확인한 뒤 반환. kubectl이 죽으면 출력을 stderr로 남긴다. 스크립트별 로컬 포트 대역을 분리(기존 값 + 1000×스크립트 번호)
- **관찰된 사실**: 정리 전 구조로 처음 `make verify`를 돌렸을 때 m1-01 재기동 단계에서 `address already in use`(19080/14100/14200)로 실패했고, 그 포트를 `kubectl port-forward` 프로세스 3개가 점유 중이었다(스크립트 종료 후에도 생존). 원인은 `k()` 함수를 `&`로 띄우면 `$!`가 subshell PID라 `kill`이 kubectl에 닿지 않는 것. kubectl을 직접 띄우고 `pkill -P`로 자식도 정리하도록 고친 뒤 재현되지 않음. **m2-01 안 verify-m1의 m1-02 code=000 두 번 실패가 이 원인인지는 이번에 재현·증명하지 않았다** (중첩 호출 제거 + 포트 대역 분리 + HTTP 확인으로 구조적으로 막았을 뿐)

### 된 것 / 안 된 것 (검증표, 모두 VM `lgtm-vm`, 로그 `~/lgtm-logs/m2-02-*.log`)
| 주장 | 확인 방법 | 결과 |
|---|---|---|
| `make clean && make` exit 0 | nohup, `m2-02-make1.log` `MAKE_EXIT=0` | 확인(VM) |
| 재실행 `make` exit 0 | `m2-02-make2.log` | 확인(VM), `MAKE_EXIT=0` |
| 공격 12종(include_str!/공백/core::/r#/include!/env!/`m!(env)`/`#[path]` mod/cfg_attr mod/`use as`+`x!`/중첩 주석 gap/incbin) → `compile_error` + `LGTM 소스 정책 위반 [규칙]`, 응답에 `root:x:0:0` 없음 | `m2-02.sh` 1번 | 확인(VM) |
| 정상 예제(struct/trait/iterator/`std::env::args`/인라인 mod/`path` 변수) → success | `m2-02.sh` 2번 | 확인(VM) |
| 격리 계층 단독: (KUBERNETES_* 제외) 다른 Service 주소·비밀값 환경변수 없음, `/var/run/secrets/kubernetes.io` 없음, 루트 FS 쓰기 실패(`/work`는 성공), 1.1.1.1:80 / backend Service / API 서버 연결 실패, otel-collector:4317 연결 성공 | `m2-02.sh` 3번 | 확인(VM) |
| **k3s가 NetworkPolicy를 강제**: 다른 namespace pod → compiler:80 실패, 정책 2개 임시 삭제 시 같은 pod 연결 **성공**(대조군), 복구 후 다시 실패, backend → compiler `/api/execute` success | `m2-02.sh` 4번 | 확인(VM) |
| `readOnlyRootFilesystem=true / enableServiceLinks=false / automountServiceAccountToken=false`, 이 상태에서 compile 응답 `\0asm`, `/tmp` emptyDir 없이 동작 | `m2-02.sh` 5번 | 확인(VM). `/tmp` 추가 불필요 |
| deny-list·rustcEnv 단위 테스트 | VM golang 컨테이너 `go test ./cmd/compiler/... ./internal/...` (`m2-02.sh` 6번) | 확인(VM) |
| `make verify`(8개 순차) exit 0 | `m2-02-verify3.log`, `m2-02-verify4.log` (연속 2회) | 확인(VM). 아래 실패 이력 참고 |

### 안 된 것 / 열린 문제 / 실패 이력
- `make verify` 실패 이력: (1) 1번째: m1-01 포트 점유(위 원인, 수정함). (2) 2번째: m2-02 환경변수 검사가 `KUBERNETES_PORT_443_TCP=tcp://10.43.0.1:443`에 걸림 → 아래 항목. 수정 후 3회, 4회 연속 통과
- **`enableServiceLinks: false`로도 `KUBERNETES_*` 8개(SERVICE_HOST/PORT/PORT_443_TCP* 등)는 K8s가 항상 주입한다** (VM `env` 실측: 그 외 Service 변수는 없음). 그래서 m2-02 검사를 "KUBERNETES_* 제외 다른 Service 주소·비밀값 없음"으로 바꾸고, API 서버(`KUBERNETES_SERVICE_HOST:443`) 연결 실패를 별도로 확인(실측: Connection refused). rustc 프로세스 환경에는 이 변수들이 없다 (`rustcEnv` 5개 키 단위 테스트). 지시한 기준 "환경변수 목록에 다른 Service 주소 없음"을 K8s 동작에 맞게 좁힌 것이므로 이의가 있으면 알려 달라
- 15초 timeout은 VM에서 재현하지 않았고 단위 테스트 유지 (선택 항목, 시도하지 않음)

### 다음 단계
- F-M2-03 wasmtime-exec

## F-M4-02 result-display (브랜치 feat/m4-02-result-display)

### 한 일
- `frontend/src/api.ts`: `execute()` 가 throw 대신 `ExecuteOutcome` 반환 (`ok` / `too_large`(413) / `busy`(429) / `http_error`(그 외 비정상, 400 포함) / `bad_body`(비JSON·비객체·status 없음) / `network`)
- `frontend/src/ResultView.tsx`(신규): success(stdout/stderr 구분, `Output truncated (10kB)` 배지) / compile_error(rustc 메시지 `<pre>`) / runtime_error / timeout(`Time limit exceeded (5s)`) / memory_limit(`Memory limit exceeded (10MB)`) / internal_error(`서버 내부 오류, 잠시 후 다시 시도` + message) / 알 수 없는 status 는 원문. `timings_ms` 표시. 출력은 JSX 텍스트 노드만 (`dangerouslySetInnerHTML` 없음)
- IPFS 링크 2개(`http://ipfs.lgtm.local/ipfs/<cid>`, `https://ipfs.io/ipfs/<cid>`, 새 탭, `noopener noreferrer`): cid 를 `^[A-Za-z0-9]{10,100}$` 로 검증한 뒤 직접 조립. 응답의 `ipfs_url` 은 href 에 쓰지 않고 null/빈 값(=생성 실패) 판정에만 사용. null → `공유 링크 생성 실패(IPFS timeout)`, cid 검증 실패 → 링크 없이 안내
- trace_id 표시 + 복사 버튼. `http://lgtm.local` 은 보안 컨텍스트가 아니라 `navigator.clipboard` 가 없으므로 fallback(텍스트 자동 선택 + `선택됨 — Ctrl+C로 복사`)이 정상 경로다. clipboard 거부 시에도 같은 fallback. Grafana 링크는 만들지 않음 (저장소에 Tempo datasource uid/Explore URL 형식 근거 없음)
- `App.tsx`: Run 옆 안내 `실행한 코드와 결과는 IPFS에 영구 공개됩니다`
- 테스트: vitest 5.0.5 + jsdom + @testing-library (`ResultView.test.tsx`, `api.test.ts`, `App.test.tsx`, 39건). 실패 상태로 먼저 커밋(`cdf40ab`) 후 구현
- `frontend/Dockerfile` build 단계: `npm run lint && npm test && npm run build` (이미지 빌드가 테스트 통과를 포함)
- make 통합: `build` 에 `build-frontend.sh`, `deploy` 에 frontend.yaml apply + rollout + `wait-ingress lgtm.local`. `deploy-frontend` 타겟과 `k8s/dummy/lgtm.yaml` 제거. `dummy-lgtm` 은 `delete --ignore-not-found` 로 정리 유지
- `scripts/verify/m4-02.sh` 신규 (frontend pod/restart, dummy-lgtm 없음, `/` 앱 HTML, `/api` 회귀, 번들 CDN 0건, src 에 dangerouslySetInnerHTML 없음, 번들에 공개 안내 문구)
- verify 수정(범위 확장, 필요해서 함): `m1-03.sh` 8번(`/`·`/healthz` 가 dummy 텍스트가 아니라 frontend HTML 인지), `m1-03.sh` 9번(하위 스크립트 FAIL 줄 노출), `m1-02.sh`, `m2-01.sh`, Makefile `verify-m1` (아래)

### PRD 변경 (확정)
- **FE-07**: `ipfs.lgtm.local` 링크 + `https://ipfs.io/ipfs/<cid>` 두 개. 이유: subject "share with the world"
- **status `internal_error` 추가** (F-M2-01 확정 사항, 화면 처리 추가). 플랫폼 장애
- FE-08 문구: PRD "실행한 코드는 IPFS에 영구 공개됩니다" → "실행한 코드와 결과는 IPFS에 영구 공개됩니다" (사용자 지시)

### m1-02 간헐 실패 대응 (사용자 지시로 이번에 처리)
- `m1-02.sh`: Collector 로그 error 검사를 스크립트 시작 시각 이후(`kubectl logs --since-time`)로 한정, 기동 오류는 `restartCount==0` 으로 확인. `Exporting failed` 제외 예외 제거
- `make verify-m1`: 실패 시 해당 스크립트의 `FAIL` 줄을 그대로 다시 출력. `m2-01.sh` 의 verify-m1 실패 메시지와 `m1-03.sh` 9번도 `tail -5` 대신 FAIL 줄을 담음
- 이 변경으로 첫 FAIL 줄이 처음 보이게 됨 (아래 "안 된 것")

### 된 것 (검증표)
| 주장 | 확인 방법 | 결과 |
|---|---|---|
| vitest 39건 통과, `npm run lint`, `npm run build` | Mac `frontend/` 에서 실행 | 확인(mac) |
| 테스트가 구현 전에 실패 | 구현 전 `npx vitest run` (3 파일 실패, 11건 실패 출력 확인) 후 `cdf40ab` 커밋 | 확인(mac) |
| `make clean && make` exit 0, 재실행 `make` exit 0 (frontend 이미지 빌드 + Dockerfile 안 `npm test` 포함) | VM, 로그 `~/lgtm-logs/m4-02-full-run.log` (`MAKE1_OK`/`MAKE2_OK`) | 확인(VM). 커밋 62598cf 기준 |
| `m4-01.sh` ALL PASS (이미지 `docker build --target build` = lint+test+build 포함) | 위 체인 | 확인(VM) |
| `m4-02.sh` ALL PASS (frontend pod Ready/restart 0, dummy-lgtm 없음, `/` 앱 HTML, `/api` 회귀, 번들 CDN 0건, src 에 dangerouslySetInnerHTML 없음, 공개 안내 문구 번들 포함) | 위 체인 | 확인(VM). 새로 만든 클러스터 기준 |
| `m1-03.sh` + `m2-01.sh` 통과 (m1-03 8번 수정 후, verify-m1 포함) | VM, `m4-02-run2.log` `CHAIN2_OK` | 확인(VM). **커밋 2c1bc12 기준, m1-02 변경(62598cf) 이전 스크립트** |
| 새 `m1-02.sh` + `make verify-m1` 단독 실행 통과 (Collector restartCount 0, since-time error 0건, `Exporting failed` 예외 없이) | VM 단독 `make verify-m1` → `verify-m1: ALL PASS` | 확인(VM). 1회 |
| 브라우저에서 Run → 결과 화면 | 미실시 | **미확인** (수동 체크리스트) |
| 413 화면 | api/ResultView mock 테스트만 | **backend 에 413 이 아직 없음** (F-M2-04). 실서버 미확인 |
| S3 (runtime error / 제한 초과) 화면 | mock 테스트만 | **F-M2-03 전이라 실서버 미확인** |
| 기존 클러스터에서 `dummy-lgtm` 이 `delete --ignore-not-found` 로 정리됨 | — | **미확인** (VM 을 `make clean` 으로 새로 올렸기 때문에 이 경로를 타지 않음) |

### 안 된 것 / 열린 문제
- **m2-01 안에서 호출되는 `make verify-m1` 의 m1-02 간헐 실패 (미해결, 원인 미확인)**. 새 m1-02 스크립트로 전체 체인(`m4-02-full-run.log`)을 돌렸을 때 `m2-01.sh` 9번이 실패했고 체인이 거기서 멈춤(최종 `make verify-m1` 단계는 실행되지 않음). 첫 FAIL 줄: `FAIL: Collector /v1/traces code=000` (이어서 `/v1/logs`, `/v1/metrics` 도 000, 그 뒤 Tempo 404 / Loki·Mimir 0건은 그 결과). 같은 m1-02 에서 앞 단계(restartCount 0, error 로그 0건, Grafana, datasource 3개)는 통과 → 6번 OTLP `port-forward` 호출만 연결 실패. 이번에 추가한 로그 검사 변경과는 무관한 지점
  - 이력: 전체 체인 첫 실행에서도 m2-01 의 verify-m1 이 m1-02 에서 실패(당시 FAIL 줄이 안 남아 같은 실패인지는 **확인 못 함**). 이후 m2-01 단독 재실행에서는 m1-03 8번(dummy 가정, 수정함)이 원인이었고, 수정 후 m1-03+m2-01 은 통과, `make verify-m1` 단독도 통과. 즉 m1-02 실패는 `m2-01.sh` 안에서 호출될 때만 2회 관측
  - 추정(증명 안 됨): `pf_start` 는 로컬 포트가 열렸는지만 보고(kubectl 이 listen 하면 통과) upstream 연결을 확인하지 않는다. m2-01 의 선행 단계(compiler 중단·복구, 동시 3건, 도커 go test) 직후라 Collector 쪽 연결이 아직 안정되기 전일 수 있다. 다음 실패 때는 `pf_start` 의 kubectl 출력(현재 `/dev/null`)을 먼저 본다
  - 같은 실패 2번이라 이 브랜치에서는 더 고치지 않고 멈춤
- `m4-02.sh` 에는 413 검사가 없다 (backend 413 미구현)
- Grafana 링크 미구현 (위 사유)
- 번들 크기는 F-M4-01 과 동일하게 2.9MB 대(monaco). 범위 밖
- `npm audit`: F-M4-01 에 적은 monaco-editor/dompurify low 외에 vitest/jsdom 추가분은 확인하지 않음

### 수동 확인 체크리스트 (VM Firefox, `http://lgtm.local`)
- [ ] **S1 정상 실행**: 예제 그대로 Run → status 정상 표시, stdout, `compile/execute/ipfs_upload` timings, IPFS 링크 2개(`ipfs.lgtm.local`, `ipfs.io`)가 새 탭으로 열림(ipfs.io 는 오프라인이면 열리지 않아도 href 가 `https://ipfs.io/ipfs/<cid>` 인지만 확인), Run 근처 공개 안내, trace_id 복사 버튼 → "선택됨 — Ctrl+C로 복사" 와 텍스트 선택
- [ ] **S2 문법 오류**: `let x = ;` 로 Run → compile_error, rustc 메시지가 monospace 로 그대로 표시, IPFS 링크 2개
- [ ] S3 (runtime error / 제한 초과)는 **F-M2-03 전이라 mock 테스트로만 확인**됐다. F-M2-03 에서 실제 화면 확인 필요
- [ ] 네트워크 탭의 요청 도메인이 `lgtm.local` 하나인지 (ipfs 링크 클릭 제외)

### 다음 단계
1. m2-01 안 verify-m1 의 m1-02 간헐 실패 원인 확인 (`pf_start` upstream 확인 / kubectl 출력 보존). 위 추정은 증명 전
2. F-M2-03 (execute) 이후 S3 화면을 실서버로 확인
3. F-M2-04 의 413 이 들어오면 `m4-02.sh` 에 413 검사 추가

## F-M2-01 compiler-service (브랜치 feat/m2-01-compiler-service)

### 한 일
- `backend/cmd/compiler` + `internal/compile`: `POST /compile`(text/plain) → rustc → 200 wasm / 422 rustc stderr / 504 timeout / 500 내부. `GET /healthz`
- rustc: `rustc --edition 2021 --target wasm32-wasip1 -C opt-level=1 --crate-type bin --crate-name main -o out.wasm main.rs` (cwd = 요청별 임시 디렉토리, 상대 경로라 에러 메시지에 `req-XXXX` 경로가 새지 않음)
- 요청별 `os.MkdirTemp("/work")` + `defer RemoveAll`(성공/실패/timeout/취소 공통). 시작 시 `/work` 잔여물 청소
- timeout 15초(semaphore 획득 이후부터), `Setpgid` + `Cancel`에서 `kill(-pgid, SIGKILL)` + `WaitDelay 2s`. semaphore 2: 초과 요청은 거부하지 않고 대기 (429는 F-M2-04)
- tracing: `otelhttp` server span 이름 `rustc`(service.name=lgtm-compiler, `telemetry.Setup(ctx, serviceName)`로 파라미터화). 로그는 backend와 같은 slog fan-out
- backend: compile 단계를 compiler HTTP 호출로 교체. execute / ipfs.upload는 stub 유지
- 이미지 `backend/Dockerfile.compiler`(golang:1.27.3-trixie 빌드 → `rust:1.99.1-slim-trixie` + `rustup target add wasm32-wasip1`, uid 65532). 태그 `lgtm-compiler:src-<backend/ 해시>`. `scripts/build.sh`는 두 이미지 루프, Makefile `build`/`deploy`에 compiler 추가
- `k8s/app/compiler.yaml`: Deployment 1 / ClusterIP Service `compiler:80` / Ingress 없음 / emptyDir `/work` / request 250m·256Mi, limit 2·2Gi. backend에 `COMPILER_URL` env

### 확정 결정과 이유 (PRD 변경 포함)
- **PRD 변경 1 (SEC-10)**: "compile memory 1GB pod limit" → "compiler pod limit 2Gi(동시 2개 합계), request 256Mi". 이유: SEC-07 동시 2와 10장 1GB×2 계산에 맞춤
- **PRD 변경 2 (6.2 status)**: `internal_error` 추가. 이유: 플랫폼 장애와 사용자 코드 오류를 metric(`lgtm_executions_total{status}`)과 trace에서 구분. 분류: rustc 422 / compile timeout 504 → `compile_error`, compiler 연결 실패 / 그 외 5xx·4xx / wasm 8MiB 초과 → `internal_error`(HTTP 200, 스키마 동일, message에 요약, stderr 비움, root span ERROR)
- **traceparent는 `otelhttp.NewTransport`를 쓰지 않고 직접 주입**: transport가 HTTP client span을 하나 더 만들어 rustc의 parent가 compile이 아니게 된다 (PRD 8.3 트리 compile → rustc). compile span ctx에서 `otel.GetTextMapPropagator().Inject(ctx, propagation.HeaderCarrier(req.Header))`, 일반 `http.Client{Timeout: 20s}`. 단위 테스트(`TestTraceparentParentIsCompileSpan`)가 traceparent의 parent == compile span id, backend span 4개(추가 client span 없음)를 확인
- edition 2021: 널리 쓰이는 예제 코드와 호환. 2024는 `gen` 예약어·unsafe extern 등 변경 위험
- Rust 이미지: `rust:1.99.1-slim-trixie`. 근거 URL: https://static.rust-lang.org/dist/channel-rust-stable.toml (stable 1.99.1, wasm32-wasip1 rust-std 존재), https://hub.docker.com/v2/repositories/library/rust/tags?name=slim-trixie (태그 존재)
- backend compile timeout 20초 = compiler 15초 + 5초 여유. wasm 응답 상한 8MiB: 이후 Wasmtime 적재·IPFS 업로드와 backend 메모리 limit(128Mi) 보호. 실측 hello world는 약 2.1MB(opt-level=1, 디버그 정보 포함)
- 트리거: `__slow__`는 유지(compile 실제 시간을 뺀 나머지를 execute/ipfs stub에 나눠 전체 2~3초). `__fail_compile__` 분기는 제거(실제 rustc 에러로 대체)

### m1 verify / load.sh 수정 (최소)
- `scripts/load.sh`, `m1-03.sh`: `__fail_compile__` 코드를 주석만 있던 것에서 `let x = ;` 문법 오류 + 마커로 변경 (이제 실제 rustc가 실패해야 compile_error)
- `m1-03.sh`: 정상 trace span 4 → 5개(rustc 추가), 자식 span 목록에 `rustc` 포함, `rustc`는 parent가 compile이므로 "parent = root" 검사에서 제외, 실패 trace 3 → 4개
- backend compile span에 `compile started/finished` 로그를 복구(m1-03 Loki 검사가 compile span_id 로그를 요구)

### 이미지 크기 (VM `docker image ls`)
- lgtm-compiler:src-72063c37732d **1.32GB**, lgtm-backend 177MB

### 된 것 (검증표)
| 주장 | 확인 방법 | 결과 |
|---|---|---|
| `make clean && make` exit 0, 재실행 `make` exit 0 | VM, 로그 `MAKE1_OK`/`MAKE2_OK` | 확인(VM). 커밋 5ab6b79+19a25a5 기준 |
| compiler pod Ready, limit 2/2Gi, request 256Mi, 태그 고정, Ingress 없음 | `m2-01.sh` 1번 | 확인(VM) |
| POST /compile 200 + `\0asm`(2174529 bytes), 문법 오류 422 + rustc 메시지, 요청 후 `/work` 비어 있음 | `m2-01.sh` 2~4번 | 확인(VM) |
| /api/execute success, Tempo service 2개, rustc parent == compile span id | `m2-01.sh` 5번 | 확인(VM) |
| /api/execute 문법 오류 → compile_error + rustc stderr | `m2-01.sh` 6번 | 확인(VM) |
| compiler 다운 → HTTP 200 internal_error, message 있음, root span ERROR | `m2-01.sh` 6b | 확인(VM) |
| compile 시간 (예제 `println!`, pod 재시작 직후 첫 요청 = cold / 그 다음 = warm): cold **0.53s** → **1.21s**(두 번 실행), warm **0.06s** | `m2-01.sh` 2번 INFO | 확인(VM). cold는 실행마다 편차가 있음 |
| 15s timeout·프로세스 그룹 kill·임시 디렉토리 삭제·semaphore(peak 2, 대기)·backend handler(internal_error 3종 포함) | `go test ./cmd/compiler/... ./internal/...` (golang 컨테이너). **timeout은 VM에서 15초를 직접 재현하지 않고 단위 테스트(느린 명령 + 자식 프로세스 주입, timeout 단축)로 대체** | 확인(VM) |
| 동시 3건 compile 전부 200 (1.76s/1.54s/1.54s), compiler 로그 started 3건, 동시 실행 peak 2 (2+1 직렬화) | `m2-01.sh` 7번 | 확인(VM) |
| `make verify-m1` 통과 (m1-03 수정·compile span 로그 복구 반영) | `m2-01.sh` 9번 | 확인(VM) |
| `bash scripts/verify/m2-01.sh` exit 0 (`ALL PASS (m2-01)`, `make verify-m1` 포함) | VM, 로그 `~/lgtm-logs/m2-01-run3.log` | 확인(VM). 3번째 실행에서 통과 (아래 이력) |

### 안 된 것 / 열린 문제
- **`m2-01.sh` 실패 이력**: 1번째 실행은 `wait`(인자 없음)가 백그라운드 port-forward를 기다려 멈춤 → 대상 PID만 기다리도록 수정. 2번째는 6b 복구 직후 동시 3건 HTTP 000, 3번째 실행은 첫 compile HTTP 000 (두 번째 발생). 이 둘의 원인으로 "svc/ port-forward가 시작 시점 pod 하나에 고정되어 Terminating 중인 옛 pod 또는 새 pod 준비 전에 붙음"을 가정하고 verify를 고침: 새 pod 하나만 Ready로 남을 때까지 대기 → `pod/<이름>`으로 port-forward → 첫 요청 `curl --retry 10 --retry-connrefused`. 고친 뒤 3번째 실행에서 통과. **원인을 pod/endpoint 상태로 직접 증명한 것은 아니다** (수정 후 재현되지 않음). 재발하면 verify의 실패 시 디버그 출력(`get pods -o wide`, pf 로그)을 먼저 본다
- 서비스(backend → compiler)는 ClusterIP DNS로 호출하며 verify 6~7번에서 통과했다. 위 HTTP 000은 verify 쪽 port-forward 문제로 판단하나, 첫 실패 때 backend → compiler 20초 timeout이 한 번 같이 있었다 (같은 시점, 원인 미확인)
- 15초 timeout은 VM에서 직접 재현하지 않고 단위 테스트로 대체 (위 표)
- 413/429, deny-list, 하드닝은 범위 밖 (F-M2-02, F-M2-04)
- compiler 이미지 1.32GB (slim rust + wasm32-wasip1 target). 크기 최적화는 하지 않음

### 다음 단계
1. F-M2-02 compiler-hardening (securityContext, `env -i`, NetworkPolicy, read-only rootfs, 7.3 deny-list)
2. F-M4-01 merge 체크리스트(아래 블록)의 build/deploy 통합은 이 브랜치가 main에 merge된 뒤 진행 (이 브랜치는 이미 origin/main 위로 rebase됨, Makefile 충돌 없음)

## F-M4-01 frontend-shell (브랜치 feat/m4-01-frontend-shell)

### 한 일
- `frontend/`: Vite 8.3.5 + React 19.3.1 + TypeScript 5.9.3(7.x 금지, typescript-eslint 8.72.0 peer `<6.1.0`) + monaco-editor 0.57.0. 전부 정확 버전 고정 + lockfile, Node 22 (`.nvmrc` 22.23.2, 빌드 이미지 `node:22.23.4-alpine`)
- Monaco 로컬 번들: `@monaco-editor/react` 미사용 (loader 에 jsdelivr URL 이 남음). `monaco-editor` 를 직접 쓰는 `src/Editor.tsx`. import 는 package `exports` 의 `./*` → `esm/vs/*.js` 매핑을 따름: `monaco-editor/editor/editor.api`, `monaco-editor/languages/definitions/rust/register`(0.57 에서 `basic-languages` 경로는 사라짐), worker `monaco-editor/editor/editor.worker?worker` (Rust 는 editor.worker 하나만 필요)
- 예제(struct/trait/iterator), Run 버튼(실행 중 disabled + spinner), 결과는 status + stdout 원문만
- dev: `vite.config.ts` 의 `/api` proxy → `LGTM_VM_URL`(기본 `http://192.168.64.8`), Host 헤더 `lgtm.local`
- 이미지: multi-stage, build 단계에서 `npm run lint && npm run build`, `nginxinc/nginx-unprivileged:1.31.7-alpine`(uid 101, 8080). 태그 `lgtm-frontend:src-<hash>` (`scripts/image-tag.sh frontend` 재사용)
- `k8s/app/frontend.yaml`(Deployment/Service/Ingress `lgtm.local /`), `scripts/build-frontend.sh`, Makefile 맨 아래 `deploy-frontend`(dummy-lgtm 은 `delete --ignore-not-found` 로 정리), `scripts/verify/m4-01.sh`
- `k8s/dummy/lgtm.yaml`, backend/, k8s/observability/, 기존 Makefile 타겟은 수정하지 않음

### emptyDir 목록 (확정: `/tmp` 하나)
- `docker run --read-only` 로 실제 기동: `--read-only` 만 주면 `mkdir() "/tmp/proxy_temp" failed (30: Read-only file system)` 로 종료. `/tmp` 만 쓰기 가능하게 하면 기동·200 응답. `/tmp` 에 생긴 것: nginx.pid, client_temp, proxy_temp, fastcgi_temp, uwsgi_temp, scgi_temp. `/var/cache/nginx` 쓰기 불필요(touch 시도는 read-only 실패, 기동엔 영향 없음)
- 이 확인은 **Mac Docker**(non-root 101, cap-drop ALL) 기준이다. k8s(VM) 기동은 아래 "안 된 것"
- `10-listen-on-ipv6-by-default.sh: can not modify default.conf` 는 정보성 로그(우리 conf 는 이미 `listen 8080`)

### 된 것 (검증표)
| 주장 | 확인 방법 | 결과 |
|---|---|---|
| `npm run lint`(eslint + tsc), `npm run build` 통과 | Mac `frontend/` 에서 실행 | 확인(mac) |
| dist 에 CDN 도메인(jsdelivr/unpkg/cdnjs/googleapis/gstatic) 0건. http(s) 호스트는 w3.org, github.com, react.dev, code.visualstudio.com, microsoft.com (주석·xmlns 문자열) | `grep -rEoh 'https?://...' dist` | 확인(mac) |
| 이미지 빌드(lint+build 포함) 성공, `--read-only --tmpfs /tmp --user 101 --cap-drop ALL` 에서 `/` 200, `id="root"` 포함, `/deep/link` SPA fallback 200 | Mac Docker 로컬 실행 | 확인(mac). VM 아님 |
| frontend pod Ready(1/1, restart 0), limit 100m/64Mi, 태그 `lgtm-frontend:src-81848450da36`, IfNotPresent | `make deploy-frontend` 후 `m4-01.sh` | 확인(VM) |
| `lgtm.local /` 200 + `id="root"`, dummy 텍스트 아님 | `m4-01.sh` | 확인(VM) |
| 이미지 안 정적 파일(6개)에 CDN 도메인 0건, index.html 외부 src/href 없음 | `m4-01.sh` | 확인(VM) |
| `/api/execute` GET 405, POST backend JSON (Ingress 회귀 없음) | `m4-01.sh` | 확인(VM) |
| `docker build --target build` (npm ci + lint + build) | `m4-01.sh` | 확인(VM) |
| `bash scripts/verify/m4-01.sh` exit 0 (ALL PASS) | VM 실행 | 확인(VM) |
| k8s 에서 readOnlyRootFilesystem + emptyDir(/tmp) 기동, nginx 로그에 emerg/error 없음 (ipv6 정보성 한 줄만) | VM `kubectl logs` | 확인(VM) |
| Mac `npm run dev`(포트 5199) 의 `/api/execute` POST → VM backend stub 응답(`stub output`) 프록시 | curl localhost:5199 | 확인(mac). 브라우저에서 Run 클릭은 미실시 |

### 안 된 것
- `m4-01.sh` 를 구현 전에 커밋했으나 당시 VM 이 꺼져 있어 "VM 에서 실패" 는 확인하지 못했다 (이후 구현 + 배포 뒤 통과만 확인)
- 브라우저(VM Firefox)에서 Run → 결과 표시와 네트워크 탭 외부 요청 0개는 **미확인** (아래 수동 절차)
- `npm audit`: monaco-editor 0.57.0 → dompurify(≤3.4.15) low 2건 (IN_PLACE 사용 경로, 우리 코드는 해당 API 미사용). 0.56.0 으로 내리면 해소된다고 나오지만 breaking 이라 그대로 둠
- 번들 index js 2.9MB (monaco 전체 editor.api). 코드 분할은 범위 밖

### 수동 확인 절차 (VM Firefox)
1. `rsync -a --delete --exclude .git --exclude node_modules --exclude dist ./ lgtm-vm:~/lgtm-fe/` 후 `ssh lgtm-vm 'cd ~/lgtm-fe && make deploy-frontend && bash scripts/verify/m4-01.sh'`
2. Firefox `http://lgtm.local` → 개발자 도구 네트워크 탭을 연 채 새로고침 → Run → status/stdout 표시
3. 네트워크 탭의 모든 요청 도메인이 `lgtm.local` 하나인지 확인 (외부 도메인 0개)

### merge 체크리스트
1. F-M2-01 merge 후 main 을 rebase 하고 Makefile 충돌을 해결한다 (이 브랜치는 Makefile 맨 아래에만 추가)
2. 본 `build` / `deploy` 타겟에 frontend 를 통합한다 (build 에 `build-frontend.sh`, deploy 에 frontend.yaml apply + `rollout status`, `k8s/dummy/lgtm.yaml` 제거와 dummy-lgtm delete 줄 정리, 그 뒤 `deploy-frontend` 는 제거하거나 별칭으로)
3. merge 후 `make clean && make` 로 새로 올려 `lgtm.local /` 가 frontend 인지 확인 (`curl -s lgtm.local | grep 'id="root"'`, `m4-01.sh`)

### 다음 단계
F-M4-02 result-display (FE-05~FE-10: 상태별 에러, IPFS 링크, 공개 안내, trace_id, 413/429)

## F-M1-04 metrics-exemplar (브랜치 feat/m1-04-metrics-exemplar)

### 한 일
- `telemetry.Setup`: `otlpmetricgrpc`(v1.47.0) + `PeriodicReader(WithInterval(5s))` → Collector. 같은 resource(`service.name=lgtm-backend`). Shutdown 순서 metric → log → trace
- `telemetry/metrics.go`: instrument 3개. bucket `0.05 … 20` 공통 (`DurationBuckets`)
- `execute/handler.go`: stage duration은 `step()`에서 stage span ctx로 `span.End()` 전에 기록, execution counter/duration은 응답 쓰기 직전 root span이 살아 있는 `r.Context()`로 기록 (otelhttp가 ServeHTTP 반환 뒤 End). duration 값은 ServeHTTP 진입 시각부터의 시간이라 root span 시작과 ms 미만 차이가 있음. 400 invalid_request는 metric 미기록
- `scripts/load.sh`: 단발 모드(`-n`, `--ok/--slow/--fail`)와 지속 모드(`-d <초> [--interval <초>]`, 정상 70/slow 15/fail 15 가중 랜덤). stdout `<kind> <status> <trace_id>`, stderr 요약. M5 dashboard 개발·디펜스 시연용. verify는 단발 모드만 사용
- `make verify-m1`: m1-01 → m1-04 순차, 첫 실패에서 중단
- `scripts/verify/m1-04.sh` (실패 상태로 먼저 커밋: VM에서 15건 실패 확인)

### 확정 결정과 이유
- **OTel 이름에 접미사를 쓰지 않는다**: `lgtm_executions`(→ `_total`), `lgtm_execution_duration` / `lgtm_stage_duration`(unit `s` → `_seconds`). 실측 Mimir 이름이 PRD와 정확히 일치함
- exemplar: otel-go sdk/metric v1.47.0은 **기본 활성**, 기본 filter `TraceBasedFilter` (`config.go newConfig`). `OTEL_GO_X_EXEMPLAR` 불필요. 바꾸려면 `WithExemplarFilter` 또는 `OTEL_METRICS_EXEMPLAR_FILTER`
- Collector `prometheus_remote_write`는 exemplar 설정 키 없이 전송함 (`pkg/translator/prometheusremotewrite/helper.go` `getPromExemplars`, v0.163.0). **collector.yaml 변경 없음**, Mimir `max_global_exemplars_per_user`는 F-M1-01에서 이미 설정
- Mimir exemplar label 키 실측: `trace_id`, `span_id` → Grafana `exemplarTraceIdDestinations.name: trace_id` 그대로 일치
- 근거 URL: https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/v0.163.0/pkg/translator/prometheusremotewrite/helper.go , https://github.com/open-telemetry/opentelemetry-specification/blob/v1.40.0/specification/compatibility/prometheus_and_openmetrics.md , https://github.com/open-telemetry/opentelemetry-specification/blob/d4b241f451674e8f611bb589477680341006ad2b/specification/configuration/sdk-environment-variables.md#exemplar

### 된 것 (검증표)
| 주장 | 확인 방법 | 결과 |
|---|---|---|
| `make clean && make` exit 0, 재실행 exit 0 | VM 실행 (`make1=0 make2=0`) | 확인(VM) |
| `make verify-m1` exit 0 (m1-01~m1-04 전부 ALL PASS) | VM 실행. m1-02 수정(아래) 후 재실행한 결과 | 확인(VM) |
| Mimir 저장 이름이 PRD와 정확히 일치: `lgtm_executions_total`, `lgtm_execution_duration_seconds_{bucket,sum,count}`, `lgtm_stage_duration_seconds_{bucket,sum,count}` | `m1-04.sh` (label/__name__/values 출력) | 확인(VM) |
| `status="success"` > 0, `status="compile_error"` > 0 | `m1-04.sh` | 확인(VM) |
| 두 histogram의 `le` 집합 == PRD bucket + `+Inf` | `m1-04.sh` | 확인(VM) |
| label 세트: executions/duration `language,status`, stage `stage`; cid/hash/sha 류 없음 | `m1-04.sh` | 확인(VM) |
| `query_exemplars`가 `trace_id`(+`span_id`) 라벨 반환, load.sh 응답 trace_id와 일치, Tempo 조회됨 | `m1-04.sh` | 확인(VM) |
| Grafana `exemplarTraceIdDestinations.name: trace_id` == 실측 키 | `m1-04.sh` (grafana.yaml 파싱 vs 실측) | 확인(VM). 설정 존재·일치만, UI 동작은 미확인 |
| load.sh 지속 모드 (`-d 6 --interval 1`) 가 요청을 계속 보내고 종료 0 | VM 실행 (total=4, errors=0) | 확인(VM). 짧은 구간만 |
| 계측 이름/unit/bucket/label/exemplar trace_id(root·stage ctx), 400은 미기록 | `go test` (ManualReader) | 확인(mac 정적). VM에서 go test는 실행 안 함 |
| Grafana Explore에서 exemplar 점 클릭 → Tempo → Related logs | — | **미확인** (위 수동 절차) |
| amd64, Mimir/Collector 장애 중 metric 유실 허용 범위 | — | 미확인 |

### 범위 밖 수정 (이유)
- `scripts/verify/m1-02.sh` 1줄: Collector 로그 error 검사에서 `Exporting failed` 줄을 제외. 원인: m1-01이 mimir/loki/tempo를 일부러 삭제하는데, F-M1-04부터 backend가 5초마다 metric을 보내서 재시작 구간의 PRW 전송 실패(`context deadline exceeded`, dropped_items 10 × 3건)가 error로 찍혀 `make verify-m1`의 m1-02가 실패했다. 기동/설정 오류 검사는 그대로 유지. 첫 실행(수정 전)은 이 때문에 `verify-m1=2`였다.
- 유의: `make clean && make`(make1/make2=0)는 이 수정 전에 실행했고, verify-m1 통과는 수정 후 같은 클러스터에서 재실행한 결과다. 수정 후 `make clean`부터 다시 돌린 것은 아님.


### 안 된 것
- Grafana UI에서 exemplar 점 클릭 → Tempo → Related logs 클릭 이동은 **미확인** (아래 수동 절차)
- `lgtm_queue_rejected_total`(F-M2-04), `lgtm_output_bytes`(M5)는 범위 밖
- 실제 compile/execute 값이 아니라 stub sleep 기반 duration

### 수동 확인 절차 (VM 브라우저, 1회)
1. VM에서 트래픽: `bash scripts/load.sh -d 120 --interval 1`
2. Firefox `http://grafana.lgtm.local` → Explore → datasource **Mimir** → 쿼리 `histogram_quantile(0.95, sum by (le) (rate(lgtm_execution_duration_seconds_bucket[1m])))`
3. 쿼리 옵션에서 **Exemplars** 켜기 → Run → 그래프의 점(exemplar)에 마우스를 올려 `trace_id` 확인
4. 점의 **Query with Tempo**(trace_id 링크) 클릭 → Tempo trace 열림
5. span(예: `compile`) 클릭 → **Logs for this span** 클릭 → Loki 로그 1줄 이상 확인
(점이 안 보이면 시간 범위를 Last 5 minutes로 좁히고 load.sh가 도는 동안 확인. 스크린샷 1장 남기기)

### 다음 단계
- F-M2-01 compiler-service (rustc → wasm32-wasip1, 별도 pod, traceparent 전파로 backend → rustc span이 한 trace)
- M5 dashboard에서 `load.sh -d`를 트래픽 소스로 사용

## F-M1-03 backend-skeleton (브랜치 feat/m1-03-backend-skeleton)

### 한 일
- `backend/` Go 모듈 `lgtm/backend` (Go **1.27.3**). `cmd/api`(서버, SIGTERM → `http.Server.Shutdown` → provider Shutdown으로 flush), `internal/telemetry`(Tracer/Logger provider, slog fan-out), `internal/execute`(stub). F-M2-01 compiler는 `backend/cmd/compiler`로 같은 모듈에 추가
- `GET /healthz`(계측·로그 없음, Ingress 미노출), `POST /api/execute` stub: compile 20~40ms / execute 10~30ms / ipfs.upload 50~100ms sleep, cid는 `bafy`+코드 sha256 앞 52자의 **가짜 값**. 트리거: `__fail_compile__`(status compile_error), `__slow__`(합계 2~3초). 400 invalid_request(JSON 오류, language≠rust, 빈 code)만 처리. **64KB 413 / 429는 F-M2-04 전까지 없음 → 본문 크기 무제한**
- Tracing: root span 이름은 `execute.RootSpanName`(`"POST /api/execute"`)을 `otelhttp.WithSpanNameFormatter`로 고정. 자식 `compile`(Client) / `execute` / `ipfs.upload`. attribute `code.sha256`, `code.language`, `code.size_bytes`(root), `ipfs.cid`(ipfs.upload + root). 실패 시 해당 span과 root에 `RecordError`(exception event) + `SetStatus(Error)`. W3C TraceContext propagator 등록. OTLP gRPC `otel-collector.observability:4317`(env `OTLP_ENDPOINT`로 변경 가능), `service.name=lgtm-backend`
- Logs: `slog.NewMultiHandler(otelslog, JSON stdout)`. JSON 쪽은 `ctxHandler`가 `trace_id`/`span_id`를 최상위에 넣고, `WithAttrs`/`WithGroup`도 래퍼를 유지(그룹이 열려 있으면 root에 trace attr을 먼저 붙여 재구성). 모든 로그는 `*Context(ctx, …)`. 각 단계 span 안에서 최소 1줄
- 이미지/배포: `backend/Dockerfile`(multi-stage, `RUN --mount=type=cache`로 go mod/build 캐시, non-root 65532). `k8s/app/`(ns `lgtm`, Deployment+Service+Ingress `lgtm.local` `/api` Prefix). `make build` = `scripts/build.sh`(없으면 docker build → `k3d image import`), `make deploy`가 `__BACKEND_IMAGE__` 치환 후 apply + rollout + `scripts/wait-backend.sh`
- `scripts/verify/m1-03.sh` (실패 상태로 먼저 커밋: VM에서 39건 실패)

### 확정 결정과 이유
- **이미지 태그 = 소스 content hash** `lgtm-backend:src-<12자>` (`scripts/image-tag.sh`: `backend/` 전 파일 경로+내용 sha256). VM에 .git이 없고, 시간 태그는 make 재실행마다 이미지가 바뀌어 idempotent 위반. 같은 소스는 같은 태그(build skip, deploy 변화 없음), 소스가 바뀌면 태그가 바뀌어 Deployment가 롤링 교체됨. `:latest` 없음, `imagePullPolicy: IfNotPresent`. 이전 태그는 docker host에서만 정리, **k3d 노드 containerd에는 남음**
- **base 이미지**: 빌드 `golang:1.27.3-trixie`, 런타임 `debian:trixie-20261020-slim`(날짜 태그 고정). F-M2-03에서 wasmtime-go(cgo, glibc 링크)로 바뀔 때 base 교체가 없도록 alpine(musl)/distroless-static을 피하고 VM과 같은 Debian 13 glibc로 맞춤. 지금은 `CGO_ENABLED=0` 정적 빌드
- 6.2 해석: 성공/실패 모두 같은 응답 구조체(모든 필드 항상 포함, `message`만 omitempty). `__fail_compile__`은 compile 실패 → execute 생략 → ipfs.upload 수행 → trace는 span **3개**(성공은 4개)
- 버전 (go.mod에서 확인): otel / sdk / trace / otlptracegrpc **v1.47.0**, otel/log·sdk/log **v1.47.0**, otlploggrpc **v0.23.0**, contrib otelslog **v0.21.0**, otelhttp **v0.72.0**, grpc v1.83.2. 근거 URL: https://go.dev/dl/?mode=json, https://pkg.go.dev/log/slog (`NewMultiHandler`, Go 1.26.0 추가), pkg.go.dev 각 모듈 versions 탭, Docker Hub debian `trixie-20261020-slim`

### 된 것 (검증표)
| 주장 | 확인 방법 | 결과 |
|---|---|---|
| `make clean && make` exit 0, 재실행 exit 0 | VM 실행 (`make1=0 make2=0`) | 확인(VM) |
| backend pod Ready, request/limit, 이미지 태그 고정, IfNotPresent | `m1-03.sh` | 확인(VM) |
| `POST /api/execute` 200 + 6.2 필드 전부 | `m1-03.sh` | 확인(VM) |
| Tempo: span 4개, root 이름 `POST /api/execute`, 자식 parent=root, TR-03 attribute | `m1-03.sh` | 확인(VM) |
| Loki `{service_name="lgtm-backend"} \| trace_id=` ≥1, 3개 자식 span 각각 `\| span_id=` ≥1 | `m1-03.sh` | 확인(VM) |
| kubectl logs JSON에 같은 trace_id + span_id | `m1-03.sh` | 확인(VM) |
| `__fail_compile__`: compile_error, compile·root ERROR, event 존재, span 3개 | `m1-03.sh` | 확인(VM) |
| `__slow__` 2~3.5초 | `m1-03.sh` | 확인(VM) |
| `lgtm.local /` 와 `/healthz` 본문이 dummy 텍스트 (healthz가 backend로 안 감) | `m1-03.sh` | 확인(VM) |
| m1-01, m1-02 여전히 통과 | `m1-03.sh` 내부 호출 | 확인(VM) |
| 코드 수정 → `make build && make deploy` → 새 태그(`9d3f…`→`55ff…`)로 교체, 응답에 변경 반영, 무변경 재실행은 build skip | VM 실행 | 확인(VM) |
| ctxHandler가 `With`/`WithGroup` 조합에서도 trace_id를 최상위에 유지, MultiHandler fan-out | `go test` 단위 테스트 | 확인(mac 정적). VM 실행 안 함 |
| stub 스키마/span 구성/트리거/400 | `go test` | 확인(mac 정적) |
| Grafana Explore에서 trace → "Logs for this span" 클릭 이동 | — | **미확인** (아래 수동 절차) |
| OTLP exporter 실패(Collector 다운) 시 동작 | — | 미확인 |
| amd64 | — | 미확인 (VM은 aarch64) |

실측: `kubectl top pod -n lgtm` backend 1m / 19Mi (limit 200m/128Mi), 유휴.

### 수동 확인 절차 (VM 브라우저, 1회)
1. Firefox로 `http://grafana.lgtm.local` → Explore → datasource **Tempo** → Query type **TraceQL**(또는 TraceID) → trace ID 입력:
   - 성공 trace: `256307ecde8dcf0cbb06e80f26395ea8`
   - compile_error trace: `22c80413bfa70173357abb2044990bce`
   (없으면 `curl -s -X POST --resolve lgtm.local:80:127.0.0.1 -d '{"language":"rust","code":"fn main(){}"}' http://lgtm.local/api/execute` 로 새로 만들고 응답의 `trace_id` 사용)
2. span 목록에서 `compile` 등 자식 span 클릭 → 상세 패널의 **Logs for this span** 버튼 클릭 → Loki 쿼리 `{service_name=~".+"} | trace_id="…" | span_id="…"` 로 이동하고 로그가 1줄 이상 나오는지 확인
3. compile_error trace에서는 compile / root span이 ERROR로 표시되고 exception event가 보이는지 확인
(m1-02에서 provisioned 쿼리를 Loki API로 직접 실행하는 검증은 통과. 버튼 클릭 자체만 미확인.)

### 안 된 것
- metrics/exemplar (F-M1-04), 실제 compile/실행/IPFS, 413/429 (F-M2-04), compiler pod, frontend
- k3d 노드 containerd의 오래된 `lgtm-backend:src-*` 이미지 정리

### 다음 단계
- **F-M1-04 metrics-exemplar**: `lgtm_execution_duration` histogram + exemplar(trace_id), counter. stub 트리거(`__slow__`, `__fail_compile__`)로 느린/실패 trace 생성. Mimir에 저장된 실제 metric 이름은 조회로 확정. m1-02 HANDOFF의 `service.name → job` label 변환 확인 결과 참고

## F-M1-02 collector-grafana (브랜치 feat/m1-02-collector-grafana)

### 한 일
- `k8s/observability/collector.yaml`: OTel Collector contrib `0.163.1` (Deployment 1, ClusterIP Service 4317/4318, Ingress 없음). receivers otlp(grpc/http), processors memory_limiter+batch, pipelines traces/metrics/logs, `health_check`(13133) → readiness/liveness. limit 500m/256Mi
- exporter 이름은 `otelcol-contrib components`(VM, 0.163.1) 출력으로 확인: `otlp_grpc`(Tempo, `tempo.observability:4317`), `prometheus_remote_write`(Mimir `/api/v1/push`), `otlp_http`(Loki `/otlp`, `/v1/logs` 자동 부착). 구 이름 `otlp`/`otlphttp`/`prometheusremotewrite`는 deprecated alias라 쓰지 않음
- `k8s/observability/grafana.yaml`: Grafana `13.2.4` (Deployment, PVC 없음, limit 500m/512Mi) + Ingress `grafana.lgtm.local` + provisioning ConfigMap 2개(datasources, dashboard provider). `k8s/dummy/grafana.yaml` 삭제
- `make deploy`: Secret `grafana-admin`(없을 때만 랜덤 생성, 출력 안 함) → `dashboards/*.json`으로 ConfigMap `grafana-dashboards`(0개면 빈 것) → apply → rollout 대기 → 기존 클러스터의 `dummy-grafana` 삭제(`apply`는 prune 안 함; 실제로 구 dummy를 apply한 뒤 `make deploy`로 제거됨 확인)
- `scripts/wait-ingress.sh`: `host[/path]` 인자 지원. grafana는 `/api/health` 200 기대
- `scripts/verify/m1-02.sh` (실패 상태로 먼저 커밋: VM에서 28건 실패 확인)
- `scripts/verify/m1-01.sh` 최소 수정: 같은 namespace에 Collector/Grafana가 생겨 "pod 3개", "Ingress 0개" 검사가 깨지므로 `app in (mimir,loki,tempo)` 라벨로 한정, Ingress는 backend 3종을 가리키는 것만 센다 (PRD 변경 아님, 검증 범위 조정)

### 확정 결정과 이유
- Grafana 접근: anonymous **Editor**. Viewer는 Explore 접근이 막혀 trace-to-logs가 깨질 수 있어서. 로그인 폼 숨김. admin은 랜덤 Secret (기본 admin/admin 금지). PRD 14장 해소. admin/admin 으로는 admin API 불가 (verify 확인; 익명 사용자의 정확한 응답 코드는 미확인)
- 외부 통신 차단 (env `GF_<SECTION>_<KEY>`, 13.2.4 `defaults.ini`로 키 존재 확인, 적용값은 `/api/admin/settings`로 verify): analytics.reporting_enabled / check_for_updates / check_for_plugin_updates / feedback_links_enabled=false, news.news_feed_enabled=false, snapshots.external_enabled=false, plugins.preinstall_disabled=true, preinstall_auto_update=false, plugin_admin_enabled=false. (`preinstall_async` 키는 13.2.4에 없음)
- tracesToLogsV2.query: `{service_name=~".+"} | trace_id="$${__trace.traceId}" | span_id="$${__span.spanId}"`. LogQL은 `{...}`로 시작해야 하므로 stream selector 포함. `$$`는 provisioning의 `$` 이스케이프
- tracesToMetrics.tags: `service.name → job`. remote write 변환 후 `service.name`이 `job` label이 됨을 실측으로 확인(아래). queries는 비워둠 (spanmetrics는 F-M5-03)
- Loki derivedFields: `matcherType: label`, `matcherRegex: trace_id` (structured metadata 기준, 로그 본문 regex 아님). provisioning 후 API 응답에 `matcherType: label`이 남는 것 확인
- 근거 URL: https://grafana.com/docs/grafana/v13.2/datasources/tempo/configure-tempo-data-source/ (변수 `${__trace.traceId}`, `${__span.spanId}`), …/configure-tempo-data-source/provision/ (tracesToLogsV2/tracesToMetrics YAML, `$$` 이스케이프), …/datasources/prometheus/configure/ (exemplarTraceIdDestinations), …/datasources/loki/configure/ (derivedFields), …/administration/provisioning/ (dashboard provider). Collector: opentelemetry-collector-contrib v0.163.0 exporter README

### 된 것 (검증표)
| 주장 | 확인 방법 | 결과 |
|---|---|---|
| `make clean && make` exit 0, 재실행 exit 0 | VM에서 실행, 재실행 `MAKE_RERUN_EXIT=0` | 확인(VM) |
| collector/grafana Ready + request/limit | `scripts/verify/m1-02.sh` | 확인(VM) |
| Collector `otelcol-contrib validate` 성공, 기동 로그 error 0 | m1-02 | 확인(VM) |
| `/api/health` 200 (Ingress), 인증 없이 홈 200 / `/api/search` 200 | m1-02 | 확인(VM) |
| admin/admin 불가, Secret 비밀번호로 admin API 200 | m1-02 | 확인(VM) |
| 설정 적용값 (anonymous Editor, 외부 통신 차단 키) | `/api/admin/settings` | 확인(VM) |
| datasource 3개(uid mimir/tempo/loki) 존재 + health OK | Grafana API | 확인(VM) |
| exemplarTraceIdDestinations, tracesToLogsV2(customQuery, span_id), derivedFields(label) | datasource API JSON | 확인(VM) |
| provisioned tracesToLogsV2.query를 trace/span id로 치환해 Loki query_range 실행 → 1건 | m1-02 | 확인(VM) |
| Collector→Tempo / Loki(`\| trace_id=`) / Mimir smoke | m1-02 | 확인(VM) |
| Mimir 저장 label 세트 (service.name=verify-m1-02 로 전송) | `/prometheus/api/v1/series` | 확인(VM): `{__name__="verify_m1_02_gauge", job="verify-m1-02", otel_scope_name="verify"}` |
| Grafana 로그에 외부 다운로드/플러그인 설치 시도 없음 | 로그 grep | 확인(VM) |
| Grafana pod 삭제 후 datasource 3개 유지, PVC 없음 | m1-02 | 확인(VM) |
| m1-01 여전히 통과 | `scripts/verify/m1-01.sh` | 확인(VM) |
| 구 `dummy-grafana`가 있는 클러스터에서 `make deploy`가 제거 | 구 manifest apply 후 deploy | 확인(VM) |
| YAML/스크립트 문법 | `bash -n` (mac) | 확인(mac 정적) |
| metric → trace → logs 클릭 이동, exemplar end-to-end | — | **미확인** (앱 없음, F-M1-04 범위) |
| tracesToMetrics 링크 실제 렌더링 (queries 없음) | — | **미확인** (F-M5-03 spanmetrics 이후) |
| amd64 | — | 미확인 (VM은 aarch64) |

### 실측 (`kubectl top pod -n observability`, VM, 유휴, 재배포 직후 약 1~3분)
| pod | CPU | MEM |
|---|---|---|
| grafana | 8m | 294Mi (limit 512Mi) |
| otel-collector | 8m | 43Mi (limit 256Mi) |
| loki-0 / mimir-0 / tempo-0 | 5m / 5m / 2m | 43Mi / 59Mi / 44Mi |
| node k3d-lgtm-server-0 | 111m (2%) | 1835Mi (23%) |

### 안 된 것
- 클릭 이동(metric→trace→logs) 확인, Collector→Mimir exemplar 전달 실측: F-M1-04
- tracesToMetrics `queries`, serviceMap, nodeGraph: 범위 밖
- dashboard JSON: M5. provider만 설정됨 (`dashboards/` → ConfigMap → `/var/lib/grafana/dashboards`). 새 JSON 추가 후에는 `make deploy`를 다시 실행해야 ConfigMap이 갱신됨

### 다음 단계
- F-M1-03 backend-skeleton
- Collector는 delta metric을 버리므로(prometheus_remote_write 문서) 앱 metric은 cumulative로 export할 것

## F-M1-01 obs-backends (브랜치 feat/m1-01-obs-backends)

### 한 일
- `k8s/observability/`: namespace + Mimir/Loki/Tempo 각각 ConfigMap + StatefulSet(1) + ClusterIP Service + PVC(local-path). Ingress 없음. 모든 컨테이너 request/limit, `readinessProbe httpGet /ready`
- 이미지(확인일 2026-10-21, amd64/arm64 모두 Docker Hub 태그 API로 확인): `grafana/mimir:3.2.2`, `grafana/tempo:3.1.0`, `grafana/loki:3.7.9`. 버전은 각 GitHub `releases/latest`로 확인
- `make deploy`: `k8s/observability/` apply → `rollout status statefulset/{mimir,loki,tempo}`(readinessProbe 기반, port-forward 안 씀) → `k8s/dummy/` apply → 기존 dummy 대기
- `scripts/verify/m1-01.sh` (실패 상태로 먼저 커밋, 구현 전 VM에서 5건 실패 확인). port-forward는 verify 안에서만 사용, trap으로 정리

### 확정 결정과 이유
- 배포: 셋 다 raw manifest. Mimir 공식 chart가 distributed 위주라 monolithic에 맞지 않고, 세 백엔드의 방식을 통일하기 위해
- Collector→Mimir: `prometheusremotewrite` (`/api/v1/push`). Collector→Loki: `otlphttp` (`/otlp`). Collector 자체는 F-M1-02. (OTLP→Mimir 경로의 exemplar 전달은 확인하지 않았고 F-M1-04에서 실측)
- Mimir classic: 3.x에서 `ingest_storage.enabled` 기본값은 false이고 켜려면 명시해야 한다(https://grafana.com/docs/mimir/v3.2.x/configure/configuration-parameters/). 문서는 ingest storage를 "preferred"라 하지만 monolithic 설명(https://grafana.com/docs/mimir/v3.2.x/references/architecture/deployment-modes/)에는 언급이 없다. 그래서 `ingest_storage.enabled: false`를 명시했고 `/config`로 반영을 확인
- `max_global_exemplars_per_user` 기본값 0(비활성, experimental)이라 100000으로 설정. `/config`에서 반영 확인
- Tempo 3.x: ingester/compactor 블록 제거, monolithic은 Kafka 불필요(https://grafana.com/docs/tempo/v3.1.x/set-up-for-tracing/setup-tempo/migrate-to-3/). metrics-generator/local_blocks는 설정하지 않음(F-M5-03에서 이 문서 기준으로 다시 확인)
- Loki: schema v13 + tsdb, `allow_structured_metadata: true`, OTLP는 `/otlp/v1/logs`. 성공 응답은 200이 아니라 **204**

### Mimir ruler/alertmanager 스토리지 문제 (기록)
- 증상: Mimir CrashLoop, `module=ruler err="unable to read dir /data/ruler: open /data/ruler: no such file or directory"`. 이전에 `activity-tracker`도 `./metrics-activity.log` permission denied로 실패 → `activity_tracker.filepath: /data/metrics-activity.log`
- 확인: `docker run --rm --entrypoint /bin/mimir grafana/mimir:3.2.2 -modules` 에서 `ruler (in: all)`, `alertmanager`는 all에 포함되지 않음. 그래서 alertmanager 설정은 넣지 않았다
- 선택: `ruler_storage.backend: filesystem`, `dir: /data/ruler`(PVC 안). 이유: backend `local`은 디렉터리가 없으면 시작이 실패하고, `filesystem`(object store 방식)은 디렉터리 없이도 시작되는 것을 VM에서 확인(수정 후 `logs | grep level=error` 0건). rule/alert 기능은 쓰지 않는다
- 대안(끄는 방법): `-target=all` 대신 모듈을 나열하면 ruler를 뺄 수 있다. `-modules` 출력 기준이며 모듈 제외 문법(`-ruler`)은 문서에서 확인하지 못했다. emptyDir를 `/data/ruler`에 마운트하는 방법도 있으나 시도하지 않았다
- ring: `/config` 확인 결과 기본값 memberlist였던 것 중 `-target=all`에서 실제로 쓰는 ruler/query_scheduler/querier ring을 포함해 distributor/ingester/store_gateway/compactor ring을 inmemory로 설정. 남은 memberlist는 `distributor.ha_tracker`(비활성), `ingester.partition_ring`(ingest storage용), alertmanager, usage_tracker, overrides_exporter로 이 구성에서 쓰이지 않는 항목

### 검증표
| 주장 | 확인 방법 | 결과 |
|---|---|---|
| verify가 구현 전에 실패 | VM `bash scripts/verify/m1-01.sh` | 확인(VM): 5건 실패, exit 1 |
| pod 3개 Ready, 컨테이너 3개 request/limit, readinessProbe /ready, PVC 3개 Bound | verify | 확인(VM) |
| 세 백엔드 /ready 200 | verify (port-forward) | 확인(VM) |
| Tempo OTLP 1건 전송 → `/api/traces/<id>` 조회 | verify | 확인(VM) |
| Loki OTLP 로그 1건 전송 → `query_range` 조회, `\| trace_id="..."` structured metadata 필터로 조회 | verify | 확인(VM) |
| Mimir `/api/v1/push` 404 아님 | verify (빈 body로 400) | 확인(VM) |
| exemplar 설정 반영 | verify (`/config` max_global_exemplars_per_user=100000) | 확인(VM) |
| ingest storage 꺼짐, multitenancy 꺼짐 | verify (`/config`) | 확인(VM) |
| pod 3개 delete 후 재기동, /ready 200, 기존 trace/log 재조회(PVC 유지) | verify | 확인(VM) |
| Ingress 없음 | verify | 확인(VM) |
| `make clean && make` → exit 0, 재실행 exit 0, 그 뒤 verify exit 0 | VM | 확인(VM) |
| 로그 `level=error`: mimir 0, tempo 0, loki 1(`ratestore ... empty ring`, 기동 직후 1회) | VM `kubectl logs` | 확인(VM) |
| `bash -n`, shellcheck(warning 이상) | mac | 확인(mac 정적) |
| amd64 VM에서의 기동 | - | 미확인 (검증 VM은 aarch64) |
| OTLP→Mimir 경로의 exemplar 전달 | - | 미확인 (F-M1-04) |
| Tempo 3.1.0 monolithic에서 compaction 등 장기 동작 | - | 미확인 (기동 직후 `backend scheduler no jobs found` 경고/에러가 보였던 적이 있으나 최종 로그에서는 0건) |

### 실측 (VM, 기동 후 verify 직후)
`kubectl top pod -n observability`: loki-0 42Mi / mimir-0 59Mi / tempo-0 29Mi (CPU 4~6m). 부하 없는 상태의 값이다.
노드 allocatable (`kubectl describe node`): cpu 4, memory 8121856Ki (약 7.75Gi). 배포 후 Allocated: requests cpu 430m / memory 828Mi, limits cpu 2300m / memory 2314Mi (dummy와 k3s 시스템 pod 포함).
request: mimir 100m/256Mi, loki 50m/192Mi, tempo 50m/192Mi (limit: mimir 1Gi, 나머지 512Mi). 이후 compiler는 request 256Mi / limit 1Gi 예정. 이 값으로 예산 부족 여부는 판단하지 않았다.

### 안 된 것
- verify는 한 번 수정했다: Loki OTLP 성공 코드(204), 재기동 직후 첫 연결 실패에 대한 재시도, port-forward 포트 전체 대기. 검사 기준을 완화한 것이 아니라 기대값/타이밍 오류 수정이다
- 부하 상태 RAM 미측정

### 다음 단계
- F-M1-02: tracesToLogs는 customQuery로 structured metadata 필터 (`| trace_id="${__trace.traceId}" | span_id="${__span.spanId}"`). Loki에서 `| trace_id="..."` 필터가 동작함은 이번에 확인
- F-M1-02: Collector → Mimir `prometheusremotewrite` `http://mimir.observability:8080/api/v1/push`(send_exemplars/resource_to_telemetry 등은 버전 문서로 확인), Collector → Loki `otlphttp` `http://loki.observability:3100/otlp`, Collector → Tempo `otlp` `tempo.observability:4317`
- F-M1-02: Grafana datasource는 provisioning. multitenancy 꺼짐이라 X-Scope-OrgId 불필요

## F-M0-02 cluster-ingress-hosts (브랜치 feat/m0-02-cluster-ingress-hosts)

### 한 일
- `scripts/cluster.sh` (`make cluster`): `k3d cluster create lgtm --image $K3S_IMAGE --servers 1 --agents 0 -p 80:80@loadbalancer -p 443:443@loadbalancer -p 4001:4001/tcp@server:0:direct -p 4001:4001/udp@server:0:direct --wait --timeout 180s`. 이미 있으면 `[skip]`. 이후 node Ready(120s) → `deploy/traefik` 생성 polling(180s) → `rollout status deploy/traefik`(180s) → IngressClass `traefik` 확인. skip 경로에서도 동일하게 대기. 실패 시 단계 이름과 함께 exit 1
- `k8s/dummy/`: namespace `dummy`, 호스트 3개 각각 Deployment + Service + Ingress(traefik). 이미지 `hashicorp/http-echo:1.0.0`(amd64/arm64 확인), 본문 `lgtm-dummy` / `grafana-dummy` / `ipfs-dummy`, resources request/limit 지정. `make deploy`가 apply 후 Available 대기, `scripts/wait-ingress.sh`로 세 호스트가 200을 낼 때까지 대기(실제 deploy는 F-M1-01부터)
- `scripts/hosts.sh` (`make hosts`): `# BEGIN lgtm` / `# END lgtm` 블록. 재실행해도 1개, 이미 최신이면 `[skip]`
- `make status`(nodes -o wide, pods -A, ingress -A), `make clean`(클러스터 삭제, 없으면 `[skip]` exit 0, /etc/hosts 안 건드림)
- `scripts/verify/m0-02.sh` (실패 상태로 먼저 커밋, VM에서 15건 실패 확인)
- HANDOFF.md F-M0-01 중복 블록 정리 (`fix: HANDOFF duplicate block`)

### 검증표
| 주장 | 확인 방법 | 결과 |
|---|---|---|
| verify가 구현 전에 실패 | VM `bash scripts/verify/m0-02.sh` | 확인(VM): 15건 실패, exit 1 |
| 노드 Ready, VERSION = K3S_IMAGE | verify (`kubectl get nodes`, 기대 `v1.37.1+k3s1`) | 확인(VM) |
| k3d v5.9.0이 k3s v1.37.1을 지원 | 실제 `--image`로 생성 후 위 검사 | 확인(VM). 공식 호환표는 없음 |
| 4001/tcp, 4001/udp 매핑 존재 | VM `docker port k3d-lgtm-server-0` → `4001/tcp -> 0.0.0.0:4001`, `4001/udp -> 0.0.0.0:4001` (+ `[::]`) | 확인(VM): **매핑 존재까지만**. 외부에서 실제로 닿는지는 F-M3-01 |
| 세 호스트 → 127.0.0.1 | verify (`getent hosts`) | 확인(VM) |
| 세 호스트 curl 200, 본문이 서로 다름 | verify (`curl`, `lgtm-dummy`/`grafana-dummy`/`ipfs-dummy`) | 확인(VM) |
| `make cluster` 재실행 skip, 클러스터 재생성 안 함 | verify | 확인(VM) |
| `make hosts` 재실행 후 블록 1개 | verify (BEGIN/END 각 1) | 확인(VM) |
| `dummy` namespace 컨테이너 3개 모두 request/limit | verify (jsonpath) | 확인(VM) |
| `make clean && make cluster && make deploy && make hosts` | VM 실행 | 확인(VM): exit 0 |
| `make clean && make cluster` 재생성 경로 | VM 실행 (여러 번) | 확인(VM): exit 0 |
| `make` 처음(클러스터 없음)부터 끝까지, 그리고 재실행 | VM `make` | 확인(VM): 둘 다 exit 0, 재실행 `[skip]` 6줄 |
| `make clean`이 클러스터 없을 때 통과, /etc/hosts 유지 | VM `make clean` 2회 연속 | 확인(VM): exit 0, hosts 블록 1개 유지 |
| `bash -n`, shellcheck(warning 이상), `make -n` | mac | 확인(mac 정적) |
| amd64 VM, 클러스터가 stopped 상태일 때 skip 경로 | - | 미확인 |

### 결정 / 주의
- `@server:0:direct`는 k3d 공식 문서(v5.9.0 cluster create 페이지)에 예시가 없다. 근거는 소스 `pkg/client/ports.go`(TransformPorts: `direct`는 지정한 단일 노드의 ports에 기록, 2개 이상이면 에러). 실제 동작은 위 `docker port`로 확인했다
- 4001은 생성 시점에만 매핑된다. 이미 있는 클러스터는 skip하므로 매핑을 바꾸려면 `make clean`
- 대기 방식 변경 이유: 생성 직후에는 `helm-install-traefik` job이 아직 없을 수 있어 `kubectl wait job/...`은 즉시 not found로 실패한다. 그래서 `deploy/traefik` 생성 polling → rollout status → IngressClass 순서로 했다(VM에서 helm-install-traefik이 1회 재시작했지만 통과)
- verify의 resources 검사는 `dummy` namespace로 한정. kube-system의 svclb/coredns 등 k3s가 띄우는 pod는 우리가 제어할 수 없어 검사하면 항상 실패한다 (PRD INF-08의 "모든 pod"는 우리가 만든 pod 기준으로 해석)
- 구현 중 발견: Deployment Available 직후에도 Traefik이 라우트를 반영하기 전에는 503이 나온다(첫 verify에서 lgtm/grafana 503). `make deploy`가 `scripts/wait-ingress.sh`로 200을 기다리게 해 해결. verify는 완화하지 않음

### 안 된 것
- 4001 외부 도달(NAT, 공유기 포트포워딩 포함)은 F-M3-01
- amd64 VM 미검증(검증한 VM은 arm64), stopped 클러스터 재시작 경로 없음(`make clean && make cluster`로 복구)
- 호스트 PC에서의 접속(README 옵션)은 이번 범위 밖

### 다음 단계
- F-M1-01: `make deploy`를 observability 스택 배포로 확장(더미 `grafana.lgtm.local`부터 교체)
- F-M3-01: 4001 외부 도달 검증
- README Instructions에 `sudo apt install -y make git` 사전 조건 명시 (F-M6-01)

## F-M0-01 skeleton-install (브랜치 feat/m0-01-skeleton-install)

### 한 일
- 디렉토리(backend/ frontend/ k8s/ dashboards/ scripts/verify/) + `.gitkeep`, `.gitignore`
- `Makefile`: 9.1 전 타겟. 미구현은 `TODO <피처ID>` 후 exit 0. 기본 타겟 `all = install cluster build deploy hosts`
- `scripts/install.sh`: docker(공식 apt repo, docker-buildx-plugin 포함, compose 제외), kubectl/helm/k3d. 버전은 Makefile 상단 변수. arch 자동 감지, kubectl/helm/k3d는 공식 checksum 검증, idempotent(`[skip] <tool> <ver>`)
- `scripts/with-docker.sh`: 재로그인 없이 docker 그룹 권한 사용. `sg docker -c` + POSIX single-quote quoting, `WITH_DOCKER_FORCE_SG=1`로 sg 경로 강제
- `scripts/verify/m0-01.sh` (실패하는 상태로 먼저 커밋)

### 고정 버전 (2026-10-21 web 확인)
| 도구 | 버전 | 비고 |
|---|---|---|
| k3d | v5.9.0 | 기본 k3s는 v1.35.5-k3s1(VM의 `k3d version`으로 확인). `K3S_IMAGE`로 최신 minor를 명시 고정 |
| k3s (`K3S_IMAGE`) | rancher/k3s:v1.37.1-k3s1 | F-M0-02에서 `k3d --image`로 사용. 이번 피처 미사용 |
| kubectl | v1.37.1 | k3s와 같은 minor |
| helm | v3.22.1 | Helm 3 선택 이유: Helm 4(v4.3.x)가 최신이지만 Mimir/Tempo/Loki 차트와 호환 검증이 안 돼서 3.x 최신 패치로 고정 |
| docker-ce / -cli | 5:29.9.1-1~debian.13~trixie | download.docker.com trixie pool의 amd64·arm64 양쪽에 있는 최신 |

### 된 것
- mac 정적: `bash -n`, shellcheck, `make -n` 전 타겟, TODO 타겟 exit 0, mac에서 install 거부
- VM(Debian 13 trixie, arm64, 2026-10-21): docker 미설치 상태에서 `make install` 1회차 exit 0, 같은 ssh 명령 안에서 `id -nG`에 docker 없음 / 직접 `docker info` 실패(direct=1) / 래퍼 경유 성공(wrapper=0) → INF-03 확인. 2회차 `make install`은 `[skip]` 4줄만. `scripts/verify/m0-01.sh` exit 0(PASS 40), `make` exit 0
- 개발 VM은 NOPASSWD sudo 사용 중, 클린 VM 검증(F-M6-02)은 이 설정 없이

### 안 된 것
- amd64 VM 미검증(검증한 VM은 arm64). sudo 비밀번호 경로 미검증
- 새 VM에는 `make`가 없을 수 있음(Makefile이 스스로 설치 불가): `sudo apt-get install -y make`를 먼저 해야 한다. F-M6-02/README에서 다룰 것
- checksum 불일치 경로 미테스트(정상 경로만 VM 확인)
- verify 스크립트 첫 버전은 설치 여부를 `dpkg-query -W` 성공으로 판정해 compose가 미설치인데도 실패했음 → Status 기준으로 수정(커밋됨)

### 다음 단계
- README Instructions에 `sudo apt install -y make git` 사전 조건 명시 (F-M6-01)

## VM 검증 절차
Debian 13 VM에서 그대로 복붙.

```bash
git fetch origin && git checkout feat/m0-01-skeleton-install && git pull

# 0) 새 VM이면 make 부터: sudo apt-get install -y make
# 1) 고정한 docker 버전이 실제로 설치 가능한지 재확인 (repo 추가 전이면 install 후 다시 실행)
#    install 이 repo 를 추가한다. 아래 출력에 5:29.9.1-1~debian.13~trixie 가 있어야 함
sudo apt-get update -qq; apt-cache madison docker-ce | head -5
curl -sI https://download.docker.com/linux/debian/dists/trixie/InRelease | head -1

make install
make install          # 두 번째: [skip] 4줄만, 다운로드/apt 로그 없어야 함
bash scripts/verify/m0-01.sh; echo "exit=$?"
make; echo "exit=$?"
```
참고: madison 단계는 docker repo 추가 전(첫 설치 전)에는 항목이 비어 있을 수 있다. 그 경우 `make install` 이 repo 를 추가한 뒤 위 madison 명령을 다시 실행해 값을 대조한다.
