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
# grafana-community repo, loki and mimir are still in the grafana repo.
GRAFANA_REPO    := https://grafana.github.io/helm-charts
COMMUNITY_REPO  := https://grafana-community.github.io/helm-charts
LOKI_VERSION    := 7.3.0
MIMIR_VERSION   := 6.2.0
TEMPO_VERSION   := 3.0.0
GRAFANA_VERSION := 13.2.5

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
        install-helm check-docker install toolchain install-go install-rust \
        versions check-wasm cluster images load observability deploy dashboards \
        hosts unhosts status logs dev back front build build-backend \
        build-frontend test lint fmt down clean fclean re help

all: up

## up: install the tooling, create the cluster, build and deploy everything
up: packages check-docker cluster images load observability deploy dashboards hosts
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
	@if command -v docker >/dev/null 2>&1; then \
		echo "[docker] $$(docker --version), skipping"; \
	elif [ "$(UNAME_S)" != "Linux" ] || ! command -v apt-get >/dev/null 2>&1; then \
		echo "[docker] not found; install Docker Desktop on $(UNAME_S)"; \
		exit 1; \
	else \
		echo "[docker] installing docker.io"; \
		sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends docker.io; \
		sudo systemctl enable --now docker; \
		sudo usermod -aG docker $$USER; \
		echo "[docker] added $$USER to the docker group - log out and back in before 'make up'"; \
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

## images: build both container images
images:
	docker build -t $(BACKEND_IMAGE) ./$(BACKEND_DIR)
	docker build -t $(FRONTEND_IMAGE) ./$(FRONTEND_DIR)

## load: import the locally built images into the cluster
load:
	k3d image import $(BACKEND_IMAGE) $(FRONTEND_IMAGE) -c $(CLUSTER)

## observability: install the LGTM stack and the OpenTelemetry Collector
observability:
	helm repo add grafana $(GRAFANA_REPO) >/dev/null
	helm repo add grafana-community $(COMMUNITY_REPO) >/dev/null
	helm repo update >/dev/null
	kubectl apply -k k8s/observability
	helm upgrade --install mimir grafana/mimir-distributed \
		--version $(MIMIR_VERSION) -n $(OBS_NS) \
		-f k8s/observability/values/mimir-values.yaml --wait --timeout 10m
	helm upgrade --install loki grafana/loki \
		--version $(LOKI_VERSION) -n $(OBS_NS) \
		-f k8s/observability/values/loki-values.yaml --wait --timeout 10m
	helm upgrade --install tempo grafana-community/tempo \
		--version $(TEMPO_VERSION) -n $(OBS_NS) \
		-f k8s/observability/values/tempo-values.yaml --wait --timeout 10m
	helm upgrade --install grafana grafana-community/grafana \
		--version $(GRAFANA_VERSION) -n $(OBS_NS) \
		-f k8s/observability/values/grafana-values.yaml --wait --timeout 10m
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

## fclean: clean, delete the cluster, the node modules and the local images
fclean: clean down
	rm -rf $(FRONTEND_DIR)/node_modules
	-docker rmi $(BACKEND_IMAGE) $(FRONTEND_IMAGE)

## re: tear everything down and bring it back up
re: fclean up

## help: list the available targets
help:
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/^## //'
