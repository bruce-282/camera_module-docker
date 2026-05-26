# camera_module — pass tokens + Docker or host install

SHELL             := /bin/bash
ROOT              := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

IMAGE             ?= cmes/camera-module:dev
CAMERA_MODULE_DIR ?= $(HOME)/camera_module
CAMERA_EXTRA      ?= zivid
PASS_CAMERA       ?= gitlab/cmesrobotics/camera_module
PASS_CRP_CORE     ?= gitlab/cmesrobotics/crp_core

export CAMERA_MODULE_DIR

.PHONY: build build-orbbec install install-pull install-host install-host-pull \
        verify run run-gui shell clean check-pass setup-pass setup-host setup-host-native setup

# ── common ───────────────────────────────────────────────────────────────────

setup-pass:
	@$(ROOT)common/setup-pass.sh

check-pass:
	@$(ROOT)common/setup-pass.sh --check

# ── docker ───────────────────────────────────────────────────────────────────

setup-host:
	@$(ROOT)docker/setup.sh

setup: setup-host

build: check-pass
	@docker info >/dev/null 2>&1 || { echo "ERROR: Docker not running (Ubuntu: sudo systemctl start docker)"; exit 1; }
	@echo ">> building base image $(IMAGE) (extra=$(CAMERA_EXTRA))"
	@DOCKER_BUILDKIT=1 docker build \
		--build-arg CAMERA_EXTRA=$(CAMERA_EXTRA) \
		-f $(ROOT)docker/Dockerfile \
		-t $(IMAGE) $(ROOT)docker

install: build
	@CAMERA_EXTRA=$(CAMERA_EXTRA) IMAGE=$(IMAGE) $(ROOT)docker/install.sh

install-pull:
	@CAMERA_EXTRA=$(CAMERA_EXTRA) IMAGE=$(IMAGE) $(ROOT)docker/install.sh --pull

build-orbbec:
	$(MAKE) build CAMERA_EXTRA=orbbec-linux
	$(MAKE) install CAMERA_EXTRA=orbbec-linux

run:
	IMAGE=$(IMAGE) $(ROOT)docker/run_container.sh

shell:
	IMAGE=$(IMAGE) $(ROOT)docker/run_container.sh --gpu --name camera_module-dev bash

run-gui:
	IMAGE=$(IMAGE) $(ROOT)docker/run_container.sh --gpu --x11

# ── host (no Docker) ─────────────────────────────────────────────────────────

setup-host-native:
	@$(ROOT)host/setup.sh

install-host: check-pass
	@CAMERA_EXTRA=$(CAMERA_EXTRA) $(ROOT)host/install.sh

install-host-pull: check-pass
	@CAMERA_EXTRA=$(CAMERA_EXTRA) $(ROOT)host/install.sh --pull

# ── verify / clean ───────────────────────────────────────────────────────────

verify:
	@test -d "$(CAMERA_MODULE_DIR)/.venv" || (echo "run: make install or make install-host" && exit 1)
	@! docker history --no-trunc $(IMAGE) 2>/dev/null | grep -iE 'glpat-|gldt-|_token=' \
		|| (echo "LEAK in image history" && exit 1)
	@! grep -RIE 'https://[^/[:space:]]*:[^@[:space:]/]+@gitlab' "$(CAMERA_MODULE_DIR)/.venv" 2>/dev/null \
		|| (echo "LEAK in venv" && exit 1)
	@echo ">> verify OK"

clean:
	docker rmi $(IMAGE) || true

clean-all: clean
	rm -rf "$(CAMERA_MODULE_DIR)"
