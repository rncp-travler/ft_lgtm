##
## ft_lgtm — build, test and run the playground (frontend + backend).
##
## Quick start:  make install && make dev
##

BACKEND_DIR    := backend
FRONTEND_DIR   := frontend

FRONTEND_IMAGE := ft_lgtm/frontend:dev
BACKEND_IMAGE  := ft_lgtm/backend:dev

RUST_TARGET    := wasm32-wasip1

# The compile stage replaces HOME before calling rustc, so the rustup shim can
# only find its toolchain when RUSTUP_HOME/CARGO_HOME are set explicitly.
# See backend/src/internal/compiler/rust.go.
RUSTUP_ENV := RUSTUP_HOME=$${RUSTUP_HOME:-$$HOME/.rustup} \
              CARGO_HOME=$${CARGO_HOME:-$$HOME/.cargo}

.PHONY: all install dev back front build build-back build-front images \
        test lint fmt clean fclean re help

all: build

## install: install the frontend dependencies and the Rust wasm target
install:
	cd $(FRONTEND_DIR) && npm install
	@command -v rustup >/dev/null 2>&1 \
		&& rustup target add $(RUST_TARGET) \
		|| echo "rustup not found - install Rust, then: rustup target add $(RUST_TARGET)"

## dev: run the backend and the Vite dev server together (Ctrl-C stops both)
dev:
	@trap 'kill 0' EXIT INT TERM; \
	$(MAKE) --no-print-directory back & \
	$(MAKE) --no-print-directory front & \
	wait

## back: run the backend alone (configured through the environment, see README)
back:
	cd $(BACKEND_DIR) && $(RUSTUP_ENV) go run ./src

## front: run the Vite dev server (proxies /api to the backend)
front:
	cd $(FRONTEND_DIR) && npm run dev

## build: compile the backend binary and the production frontend bundle
build: build-back build-front

## build-back: compile the Go binary to backend/bin/backend
build-back:
	cd $(BACKEND_DIR) && go build -trimpath -o bin/backend ./src

## build-front: build the production bundle into frontend/dist
build-front:
	cd $(FRONTEND_DIR) && npm run build

## images: build both container images
images:
	docker build -t $(BACKEND_IMAGE) ./$(BACKEND_DIR)
	docker build -t $(FRONTEND_IMAGE) ./$(FRONTEND_DIR)

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

## clean: remove the build artifacts
clean:
	rm -rf $(BACKEND_DIR)/bin $(FRONTEND_DIR)/dist

## fclean: clean plus the node modules and the local images
fclean: clean
	rm -rf $(FRONTEND_DIR)/node_modules
	-docker rmi $(BACKEND_IMAGE) $(FRONTEND_IMAGE)

## re: rebuild everything from scratch
re: fclean install build

## help: list the available targets
help:
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/^## //'
