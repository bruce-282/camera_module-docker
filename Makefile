# camera_module Docker build — tokens from `pass` only.

SHELL             := /bin/bash

IMAGE             ?= cmes/camera-module:dev
CAMERA_MODULE_DIR ?= $(HOME)/camera_module
CAMERA_EXTRA      ?= zivid
PASS_CAMERA       ?= gitlab/cmesrobotics/camera_module
PASS_CRP_CORE     ?= gitlab/cmesrobotics/crp_core

export CAMERA_MODULE_DIR

.PHONY: build build-orbbec install install-pull verify run run-gui shell clean check-pass setup-pass setup-host setup

setup-host:
	@./setup-host.sh

setup: setup-host

setup-pass:
	@./setup-pass.sh

check-pass:
	@for entry in $(PASS_CAMERA) $(PASS_CRP_CORE); do \
		pass show "$$entry" >/dev/null 2>&1 || { echo "ERROR: pass '$$entry' not found"; exit 1; }; \
		pass show "$$entry" | grep -qE '^login:[[:space:]]' || { echo "ERROR: pass '$$entry' needs 'login:' line"; exit 1; }; \
	done
	@echo ">> pass OK"

build: check-pass
	@docker info >/dev/null 2>&1 || { echo "ERROR: Docker not running (Ubuntu: sudo systemctl start docker)"; exit 1; }
	@echo ">> building base image $(IMAGE) (extra=$(CAMERA_EXTRA))"
	@DOCKER_BUILDKIT=1 docker build \
		--build-arg CAMERA_EXTRA=$(CAMERA_EXTRA) \
		-t $(IMAGE) .

install: build
	@CAMERA_EXTRA=$(CAMERA_EXTRA) IMAGE=$(IMAGE) ./install-camera-module.sh

install-pull:
	@CAMERA_EXTRA=$(CAMERA_EXTRA) IMAGE=$(IMAGE) ./install-camera-module.sh --pull

build-orbbec:
	$(MAKE) build CAMERA_EXTRA=orbbec-linux
	$(MAKE) install CAMERA_EXTRA=orbbec-linux

run:
	IMAGE=$(IMAGE) ./run_container.sh

shell:
	IMAGE=$(IMAGE) ./run_container.sh --gpu --name camera_module-dev bash

run-gui:
	IMAGE=$(IMAGE) ./run_container.sh --gpu --x11

verify:
	@test -d "$(CAMERA_MODULE_DIR)/.venv" || (echo "run: make install" && exit 1)
	@! docker history --no-trunc $(IMAGE) | grep -iE 'glpat-|gldt-|_token=' \
		|| (echo "LEAK in image history" && exit 1)
	@! grep -RIE 'https://[^/[:space:]]*:[^@[:space:]/]+@gitlab' "$(CAMERA_MODULE_DIR)/.venv" 2>/dev/null \
		|| (echo "LEAK in venv" && exit 1)
	@echo ">> verify OK"

clean:
	docker rmi $(IMAGE) || true

clean-all: clean
	rm -rf "$(CAMERA_MODULE_DIR)"
