##
## ft_lgtm — install the tooling, build the images and deploy the whole stack
## on a local k3d cluster.
##
## Fresh Debian VM:  make up  (then log out/in once if docker was just installed)
## Local dev:        make install && make dev
##

CLUSTER        := lgtm
K3D_CONFIG     := k8s/k3d-config.yaml
APP_NS         := lgtm
OBS_NS         := observability

BACKEND_DIR    := backend
FRONTEND_DIR   := frontend

FRONTEND_IMAGE := ft_lgtm/frontend:dev
BACKEND_IMAGE  := ft_lgtm/backend:dev

HOSTS_LINE     := 127.0.0.1 lgtm.local grafana.lgtm.local ipfs.lgtm.local

# Chart versions are pinned; the grafana and tempo charts moved to the
# grafana-community repo, loki is still in the grafana repo. Mimir is not a
# chart, it is a plain manifest in k8s/observability/mimir.yaml.
GRAFANA_REPO    := https://grafana.github.io/helm-charts
COMMUNITY_REPO  := https://grafana-community.github.io/helm-charts
LOKI_VERSION    := 7.3.0
TEMPO_VERSION   := 3.0.0
GRAFANA_VERSION := 13.2.5
VALUES_DIR      := k8s/observability/values

# helm_install release,chart,version: install or upgrade one chart and wait.
helm_install = helm upgrade --install $(1) $(2) --version $(3) -n $(OBS_NS) \
	-f $(VALUES_DIR)/$(1)-values.yaml --wait --timeout 10m >/dev/null

# Third-party images the stack runs, read from the rendered charts and
# manifests so the list always follows the pinned versions. With PRELOAD=1,
# `images` pulls them on the host and `load` imports them, so the host Docker
# cache survives `make down` and a rebuilt cluster downloads nothing. That
# keeps every image twice (host + node, ~2.5GB extra), too much for a small VM
# disk, so by default the node pulls them itself and stores them once.
PRELOAD        ?= 0

# Free space, in GB, on the Docker data root: under MIN_FREE_GB `make up`
# stops before it starts, under WARN_FREE_GB it only warns. A full run needs
# roughly 12GB (build cache ~5GB, app images ~1GB twice, stack ~2.5GB, data).
MIN_FREE_GB    ?= 10
WARN_FREE_GB   ?= 20

STACK_IMAGES = { \
	helm template loki grafana/loki --version $(LOKI_VERSION) --skip-tests -f $(VALUES_DIR)/loki-values.yaml; \
	helm template tempo grafana-community/tempo --version $(TEMPO_VERSION) --skip-tests -f $(VALUES_DIR)/tempo-values.yaml; \
	helm template grafana grafana-community/grafana --version $(GRAFANA_VERSION) --skip-tests -f $(VALUES_DIR)/grafana-values.yaml; \
	kubectl kustomize k8s/observability; \
	kubectl kustomize k8s/base; \
	} 2>/dev/null | sed -n 's/^[[:space:]-]*image:[[:space:]]*//p' | tr -d "\"'" \
	| grep -v '^ft_lgtm/' | sort -u

# Single-node cluster (see K3D_CONFIG): every image lives on this node.
K3D_NODE        := k3d-$(CLUSTER)-server-0

# Host toolchains, only needed for `make dev` / `make test`; the container
# images carry their own compilers. GO_VERSION must satisfy the `go` directive
# in backend/go.mod, and RUST_MIN is 1.85 because the compile stage passes
# --edition 2024 to rustc. Override on the command line to move either one.
GO_VERSION     ?= 1.27.1
RUST_VERSION   ?= 1.98.1
RUST_MIN       := 1.85.0
GO_REQUIRED    := $(shell awk '/^go /{print $$2; exit}' $(BACKEND_DIR)/go.mod)
RUST_TARGET    := wasm32-wasip1

GO_ROOT        := /usr/local/go
UNAME_S        := $(shell uname -s)
UNAME_M        := $(shell uname -m)
ARCH           := $(if $(filter aarch64 arm64,$(UNAME_M)),arm64,amd64)

# Freshly installed tools land outside the default PATH, so every recipe below
# sees them without the caller having to reload their shell first.
export PATH := $(GO_ROOT)/bin:$(HOME)/.cargo/bin:/usr/local/bin:$(PATH)

# Shell helper: ver_ge A B succeeds when version A >= version B.
VER_GE := ver_ge() { [ "$$(printf '%s\n%s\n' "$$2" "$$1" | sort -V | head -n1)" = "$$2" ]; };

# The compile stage replaces HOME before calling rustc, so the rustup shim can
# only find its toolchain when RUSTUP_HOME/CARGO_HOME are set explicitly.
# See backend/src/internal/compiler/rust.go.
RUSTUP_ENV := RUSTUP_HOME=$${RUSTUP_HOME:-$$HOME/.rustup} \
              CARGO_HOME=$${CARGO_HOME:-$$HOME/.cargo}

.PHONY: all up packages install-apt install-docker install-k3d install-kubectl \
        install-helm check-docker check-disk prune install toolchain install-go install-rust \
        versions check-wasm cluster helm-repos images load observability deploy dashboards \
        hosts unhosts status logs dev back front build build-backend \
        build-frontend test lint fmt down clean fclean re help

all: up

## up: install the tooling, create the cluster, build and deploy everything
up: packages check-docker check-disk cluster images load observability deploy dashboards hosts
	@echo ""
	@echo "Stack is up:"
	@echo "  http://lgtm.local          playground"
	@echo "  http://grafana.lgtm.local  Grafana (admin / admin)"
	@echo "  http://ipfs.lgtm.local     IPFS gateway"

# ---------------------------------------------------------------------------
# Package installation (Debian; every target is idempotent)
# ---------------------------------------------------------------------------

## packages: install docker, k3d, kubectl and helm if they are missing
packages: install-apt install-docker install-k3d install-kubectl install-helm

## install-apt: base apt packages, Debian only, skipped elsewhere
install-apt:
	@if [ "$(UNAME_S)" != "Linux" ] || ! command -v apt-get >/dev/null 2>&1; then \
		echo "[apt]    not a Debian-like system, skipping"; \
	else \
		echo "[apt]    installing base packages"; \
		sudo apt-get update -qq; \
		sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
			build-essential ca-certificates curl git; \
	fi

## install-docker: install Docker from the Debian repository and enable it
install-docker:
	@# On trixie the CLI is its own package (docker-cli) that docker.io only
	@# recommends, so --no-install-recommends would leave the daemon without a
	@# docker command. Older releases ship neither package, hence the probe.
	@if command -v docker >/dev/null 2>&1; then \
		echo "[docker] $$(docker --version), skipping"; \
	elif [ "$(UNAME_S)" != "Linux" ] || ! command -v apt-get >/dev/null 2>&1; then \
		echo "[docker] not found; install Docker Desktop on $(UNAME_S)"; \
		exit 1; \
	else \
		pkgs=docker.io; \
		for p in docker-cli docker-buildx; do \
			apt-cache show "$$p" >/dev/null 2>&1 && pkgs="$$pkgs $$p"; \
		done; \
		echo "[docker] installing $$pkgs"; \
		sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $$pkgs; \
		sudo systemctl enable --now docker; \
		sudo usermod -aG docker $$USER; \
		echo "[docker] added $$USER to the docker group - log out and back in before 'make up'"; \
	fi
	@# Without buildx, Debian's docker.io falls back to the legacy builder,
	@# which keeps every intermediate stage as a dangling image on disk.
	@if command -v docker >/dev/null 2>&1 && ! docker buildx version >/dev/null 2>&1 \
			&& [ "$(UNAME_S)" = "Linux" ] && command -v apt-get >/dev/null 2>&1; then \
		echo "[docker] installing docker-buildx"; \
		sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends docker-buildx; \
	fi

## install-k3d: install the k3d CLI
install-k3d:
	@if command -v k3d >/dev/null 2>&1; then \
		echo "[k3d]    $$(k3d version | head -n1), skipping"; \
	else \
		echo "[k3d]    installing"; \
		curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash; \
	fi

## install-kubectl: install the kubectl matching the current stable release
install-kubectl:
	@if command -v kubectl >/dev/null 2>&1; then \
		echo "[kubectl] $$(kubectl version --client -o yaml 2>/dev/null | awk '/gitVersion/{print $$2; exit}'), skipping"; \
	elif [ "$(UNAME_S)" != "Linux" ]; then \
		echo "[kubectl] not found; install it with your package manager on $(UNAME_S)"; \
		exit 1; \
	else \
		v=$$(curl -fsSL https://dl.k8s.io/release/stable.txt); \
		echo "[kubectl] installing $$v"; \
		tmp=$$(mktemp -d); \
		curl -fsSL -o "$$tmp/kubectl" "https://dl.k8s.io/release/$$v/bin/linux/$(ARCH)/kubectl"; \
		sudo install -m 0755 "$$tmp/kubectl" /usr/local/bin/kubectl; \
		rm -rf "$$tmp"; \
	fi

## install-helm: install the helm CLI
install-helm:
	@if command -v helm >/dev/null 2>&1; then \
		echo "[helm]   $$(helm version --short), skipping"; \
	else \
		echo "[helm]   installing"; \
		curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash; \
	fi

## check-docker: fail early with a readable message if the daemon is unreachable
check-docker:
	@if ! docker info >/dev/null 2>&1; then \
		echo "docker is installed but not usable by $$USER."; \
		echo "If it was just installed, log out and back in (or run 'newgrp docker'),"; \
		echo "then run 'make up' again."; \
		exit 1; \
	fi

## check-disk: stop early when the Docker disk is too small for the stack
check-disk:
	@root=$$(docker info --format '{{.DockerRootDir}}' 2>/dev/null || echo /var/lib/docker); \
	[ -d "$$root" ] || root=/; \
	free=$$(df -Pk "$$root" 2>/dev/null | awk 'NR==2 {print int($$4/1024/1024)}'); \
	if [ -z "$$free" ]; then \
		echo "[disk]   cannot read the free space of $$root, skipping the check"; \
	elif [ "$$free" -lt $(MIN_FREE_GB) ]; then \
		echo "[disk]   only $${free}GB free on $$root, need at least $(MIN_FREE_GB)GB."; \
		echo "         Try 'make prune', grow the VM disk, or override with MIN_FREE_GB=<n>."; \
		docker system df 2>/dev/null; \
		exit 1; \
	elif [ "$$free" -lt $(WARN_FREE_GB) ]; then \
		echo "[disk]   $${free}GB free on $$root; tight, $(WARN_FREE_GB)GB+ is comfortable"; \
	else \
		echo "[disk]   $${free}GB free on $$root"; \
	fi

## prune: reclaim Docker disk space (build cache, dangling and unused images)
prune:
	-docker builder prune -af
	-docker image prune -f
	@# Keep the app images the cluster was loaded from; drop unused third-party ones.
	-docker image ls --format '{{.Repository}}:{{.Tag}}' \
		| grep -v '^ft_lgtm/' | grep -v '<none>' | grep -v '^rancher/\|^ghcr.io/k3d-io/' \
		| xargs -r docker rmi 2>/dev/null
	@docker system df

# ---------------------------------------------------------------------------
# Host toolchains (only for `make dev` and `make test`)
# ---------------------------------------------------------------------------

## install: host toolchains plus the frontend dependencies, for local dev
install: toolchain
	cd $(FRONTEND_DIR) && npm install

## toolchain: install or refresh the pinned Go and Rust toolchains, idempotent
toolchain: install-apt install-go install-rust
	@$(MAKE) --no-print-directory versions

## install-go: install the pinned Go into /usr/local/go unless it is current
install-go:
	@$(VER_GE) \
	if ! ver_ge "$(GO_VERSION)" "$(GO_REQUIRED)"; then \
		echo "[go]     GO_VERSION $(GO_VERSION) does not satisfy 'go $(GO_REQUIRED)' in go.mod"; \
		exit 1; \
	fi; \
	current=$$(go env GOVERSION 2>/dev/null | sed 's/^go//'); \
	if [ -n "$$current" ] && ver_ge "$$current" "$(GO_VERSION)"; then \
		echo "[go]     $$current already satisfies $(GO_VERSION), skipping"; \
	elif [ "$(UNAME_S)" != "Linux" ]; then \
		echo "[go]     need $(GO_VERSION), found $${current:-none}; install it from https://go.dev/dl/ on $(UNAME_S)"; \
		exit 1; \
	else \
		echo "[go]     installing $(GO_VERSION) linux-$(ARCH) into $(GO_ROOT)"; \
		tmp=$$(mktemp -d); \
		curl -fsSL "https://go.dev/dl/go$(GO_VERSION).linux-$(ARCH).tar.gz" -o "$$tmp/go.tar.gz"; \
		sudo rm -rf $(GO_ROOT); \
		sudo tar -C /usr/local -xzf "$$tmp/go.tar.gz"; \
		rm -rf "$$tmp"; \
		echo "[go]     installed; add $(GO_ROOT)/bin to PATH in your shell profile"; \
	fi

## install-rust: install rustup, the pinned toolchain and the wasm target
install-rust:
	@$(VER_GE) \
	rustup_bin=$$(command -v rustup 2>/dev/null || echo "$$HOME/.cargo/bin/rustup"); \
	if [ ! -x "$$rustup_bin" ]; then \
		echo "[rust]   installing rustup with toolchain $(RUST_VERSION)"; \
		curl -fsSL --proto '=https' --tlsv1.2 https://sh.rustup.rs \
			| sh -s -- -y --no-modify-path --profile minimal \
				--default-toolchain $(RUST_VERSION) --target $(RUST_TARGET); \
		echo "[rust]   installed; add \$$HOME/.cargo/bin to PATH in your shell profile"; \
	else \
		current=$$(rustc --version 2>/dev/null | awk '{print $$2}'); \
		[ -n "$$current" ] || current=$$("$$(dirname "$$rustup_bin")/rustc" --version 2>/dev/null | awk '{print $$2}'); \
		if [ -n "$$current" ] && ver_ge "$$current" "$(RUST_MIN)"; then \
			echo "[rust]   rustc $$current satisfies the edition 2024 minimum $(RUST_MIN)"; \
		else \
			echo "[rust]   rustc $${current:-none} is below $(RUST_MIN), installing $(RUST_VERSION)"; \
			"$$rustup_bin" toolchain install $(RUST_VERSION); \
			"$$rustup_bin" default $(RUST_VERSION); \
		fi; \
		"$$rustup_bin" target add $(RUST_TARGET); \
	fi

## versions: print the toolchain versions this Makefile will build with
versions:
	@echo "go      $$(go version 2>/dev/null || echo 'not found')"
	@echo "rustc   $$(rustc --version 2>/dev/null || echo 'not found')"
	@if rustup target list --installed 2>/dev/null | grep -qx '$(RUST_TARGET)'; then \
		echo "target  $(RUST_TARGET) installed"; \
	else \
		echo "target  $(RUST_TARGET) MISSING"; \
	fi
	@echo "node    $$(node --version 2>/dev/null || echo 'not found')"
	@echo "docker  $$(docker --version 2>/dev/null || echo 'not found')"
	@echo "k3d     $$(k3d version 2>/dev/null | head -n1 || echo 'not found')"
	@echo "kubectl $$(kubectl version --client -o yaml 2>/dev/null | awk '/gitVersion/{print $$2; exit}' || echo 'not found')"
	@echo "helm    $$(helm version --short 2>/dev/null || echo 'not found')"

## check-wasm: prove the Rust toolchain can produce a wasm32-wasip1 module
check-wasm:
	@tmp=$$(mktemp -d); \
	printf 'fn main() { println!("wasm ok"); }\n' > "$$tmp/main.rs"; \
	if $(RUSTUP_ENV) rustc --edition 2024 --target $(RUST_TARGET) \
			-o "$$tmp/main.wasm" "$$tmp/main.rs" 2>"$$tmp/err"; then \
		echo "check-wasm: ok ($$(wc -c < "$$tmp/main.wasm" | tr -d ' ') bytes)"; \
		rm -rf "$$tmp"; \
	else \
		echo "check-wasm: FAILED"; cat "$$tmp/err"; rm -rf "$$tmp"; exit 1; \
	fi

# ---------------------------------------------------------------------------
# Cluster and deployment
# ---------------------------------------------------------------------------

## cluster: create the local k3d cluster, no-op if it already exists
cluster:
	@k3d cluster list $(CLUSTER) >/dev/null 2>&1 \
		&& echo "cluster $(CLUSTER) already exists" \
		|| k3d cluster create --config $(K3D_CONFIG)

## helm-repos: register and refresh the chart repositories
helm-repos:
	@helm repo add grafana $(GRAFANA_REPO) >/dev/null
	@helm repo add grafana-community $(COMMUNITY_REPO) >/dev/null
	@helm repo update >/dev/null

## images: build both app images while the stack images are pulled on the host
images: helm-repos
	@pull=; \
	if [ "$(PRELOAD)" = 1 ]; then \
		echo "[pull]   pulling the stack images in the background"; \
		$(STACK_IMAGES) | xargs -n 1 -P 4 docker pull -q >/dev/null & pull=$$!; \
	fi; \
	docker build -t $(BACKEND_IMAGE) ./$(BACKEND_DIR) \
		&& docker build -t $(FRONTEND_IMAGE) ./$(FRONTEND_DIR); \
	built=$$?; \
	if [ -z "$$pull" ]; then :; \
	elif wait $$pull; then echo "[pull]   stack images ready on the host"; \
	else echo "[pull]   some stack images failed to pull, the cluster will fetch those itself"; fi; \
	docker image prune -f >/dev/null; \
	exit $$built

## load: import the app images, and with PRELOAD=1 the stack images the cluster lacks
# Not `k3d image import`: with Docker's containerd image store, `docker save`
# lists every platform of a pulled image but only holds the local one, the
# node's import then fails on the missing content, and k3d still reports
# success. Saving the node's platform only and importing it directly avoids
# that and lets a failure stop the build. Older Docker without
# `save --platform` uses the classic store, which never has the problem.
load: helm-repos
	@imgs="$(BACKEND_IMAGE) $(FRONTEND_IMAGE)"; \
	[ "$(PRELOAD)" = 1 ] && for i in $$($(STACK_IMAGES)); do \
		docker image inspect "$$i" >/dev/null 2>&1 || continue; \
		docker exec $(K3D_NODE) crictl inspecti "$$i" >/dev/null 2>&1 && continue; \
		imgs="$$imgs $$i"; \
	done; \
	platform=; \
	docker save --help 2>/dev/null | grep -q -- '--platform' && platform="--platform linux/$(ARCH)"; \
	echo "[load]   importing into $(K3D_NODE):"; \
	printf '           %s\n' $$imgs; \
	docker save $$platform $$imgs \
		| docker exec -i $(K3D_NODE) ctr -n k8s.io images import - >/dev/null

## observability: install the LGTM stack and the OpenTelemetry Collector
observability: helm-repos
	@# Clusters set up before the switch still carry the mimir-distributed
	@# release, which owns the mimir-gateway Service; drop it and its volumes.
	@if helm status mimir -n $(OBS_NS) >/dev/null 2>&1; then \
		echo "removing the old mimir-distributed release"; \
		helm uninstall mimir -n $(OBS_NS) --wait; \
		kubectl -n $(OBS_NS) delete pvc -l app.kubernetes.io/instance=mimir --ignore-not-found; \
	fi
	kubectl apply -k k8s/observability
	@# The four backends do not depend on each other at install time (Tempo
	@# retries its remote write until Mimir is up), so wait for them together.
	@echo "[obs]    installing loki, tempo and grafana alongside mimir"
	@kubectl -n $(OBS_NS) rollout status statefulset/mimir --timeout=10m >/dev/null & mimir=$$!; \
	$(call helm_install,loki,grafana/loki,$(LOKI_VERSION)) & loki=$$!; \
	$(call helm_install,tempo,grafana-community/tempo,$(TEMPO_VERSION)) & tempo=$$!; \
	$(call helm_install,grafana,grafana-community/grafana,$(GRAFANA_VERSION)) & grafana=$$!; \
	failed=; \
	for job in mimir:$$mimir loki:$$loki tempo:$$tempo grafana:$$grafana; do \
		if wait $${job#*:}; then echo "[obs]    $${job%%:*} ready"; \
		else echo "[obs]    $${job%%:*} FAILED"; failed=1; fi; \
	done; \
	if [ -n "$$failed" ]; then \
		kubectl -n $(OBS_NS) get pods; \
		kubectl -n $(OBS_NS) get events --sort-by=.lastTimestamp | tail -20; \
		exit 1; \
	fi
	kubectl -n $(OBS_NS) rollout restart deployment/otel-collector
	kubectl -n $(OBS_NS) rollout status deployment/otel-collector --timeout=5m

## deploy: apply the application manifests
deploy:
	kubectl apply -k k8s/base
	kubectl -n $(APP_NS) rollout status deployment/backend --timeout=5m
	kubectl -n $(APP_NS) rollout status deployment/frontend --timeout=5m

## dashboards: provision the Grafana dashboards from dashboards/
dashboards:
	kubectl -n $(OBS_NS) create configmap grafana-dashboards \
		--from-file=dashboards/ --dry-run=client -o yaml | kubectl apply -f -
	kubectl -n $(OBS_NS) label configmap grafana-dashboards grafana_dashboard=1 --overwrite

## hosts: add the lgtm.local entries to /etc/hosts, asks for your sudo password
hosts:
	@if grep -q "lgtm.local" /etc/hosts; then \
		echo "/etc/hosts already has the entries:"; \
		grep "lgtm.local" /etc/hosts; \
	else \
		echo "Appending to /etc/hosts (sudo password required):"; \
		echo "  $(HOSTS_LINE)"; \
		sudo sh -c 'echo "$(HOSTS_LINE)" >> /etc/hosts' && echo "done."; \
	fi

## unhosts: remove the lgtm.local entries again
unhosts:
	@sudo sed -i'' -e '/lgtm\.local/d' /etc/hosts && echo "removed lgtm.local entries from /etc/hosts"

## status: show what is running
status:
	kubectl get pods,svc,ingress -n $(APP_NS)
	kubectl get pods,svc,ingress -n $(OBS_NS)

## logs: follow the backend logs
logs:
	kubectl -n $(APP_NS) logs -l app=backend -f --tail=100

# ---------------------------------------------------------------------------
# Local development, without the cluster
# ---------------------------------------------------------------------------

## dev: run the backend and the Vite dev server together, Ctrl-C stops both
dev:
	@trap 'kill 0' EXIT INT TERM; \
	$(MAKE) --no-print-directory back & \
	$(MAKE) --no-print-directory front & \
	wait

## back: run the backend alone, configured through the environment, see README
back:
	cd $(BACKEND_DIR) && $(RUSTUP_ENV) go run ./src

## front: run the Vite dev server, proxies /api to the backend
front:
	cd $(FRONTEND_DIR) && npm run dev

## build: compile the backend binary and the production frontend bundle
build: build-backend build-frontend

## build-backend: compile the Go binary to backend/bin/backend
build-backend:
	cd $(BACKEND_DIR) && go build -trimpath -o bin/backend ./src

## build-frontend: build the production bundle into frontend/dist
build-frontend:
	cd $(FRONTEND_DIR) && npm run build

## test: run the backend unit tests and the frontend checks
test:
	cd $(BACKEND_DIR) && go test ./...
	cd $(FRONTEND_DIR) && npm run lint && npm run type-check

## lint: static checks only
lint:
	cd $(BACKEND_DIR) && go vet ./...
	cd $(FRONTEND_DIR) && npm run lint

## fmt: format the Go sources
fmt:
	cd $(BACKEND_DIR) && go fmt ./...

# ---------------------------------------------------------------------------
# Teardown
# ---------------------------------------------------------------------------

## down: delete the cluster
down:
	-k3d cluster delete $(CLUSTER)

## clean: remove the build artifacts
clean:
	rm -rf $(BACKEND_DIR)/bin $(FRONTEND_DIR)/dist

## fclean: clean, delete the cluster, the node modules, the local images and the build cache
fclean: clean down
	rm -rf $(FRONTEND_DIR)/node_modules
	-docker rmi $(BACKEND_IMAGE) $(FRONTEND_IMAGE)
	-docker builder prune -af

## re: tear everything down and bring it back up
re: fclean up

## help: list the available targets
help:
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/^## //'
