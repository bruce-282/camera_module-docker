# crp-module-install — pass + host/Docker module install

SHELL             := /bin/bash
ROOT              := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

MODULE            ?= camera_module
MODULE_EXTRA      ?= zivid
SETUP_MODULE_EXTRA ?= none
SETUP_ARGS        ?=
# backward-compatible aliases
CAMERA_EXTRA      ?= $(MODULE_EXTRA)
IMAGE             ?= cmes/crp-module-install:dev
CAMERA_MODULE_DIR ?= $(HOME)/camera_module
PASS_CAMERA       ?= gitlab/cmesrobotics/camera_module
PASS_CRP_CORE     ?= gitlab/cmesrobotics/crp_core

export MODULE MODULE_EXTRA CAMERA_EXTRA

.PHONY: build build-orbbec install install-pull install-host install-host-pull \
        install-cam install-cam-host install-recon install-recon-host \
        install-cal install-cal-host install-recon-docker install-cal-docker \
        capture capture-host verify run run-gui shell clean check-pass \
        setup-pass setup-host setup-host-native setup-host-native-cam setup list-modules

list-modules:
	@./host/install.sh --list

# ── common ───────────────────────────────────────────────────────────────────

setup-pass:
	@$(ROOT)common/setup-pass.sh

check-pass:
	@$(ROOT)common/setup-pass.sh --check

# ── docker ───────────────────────────────────────────────────────────────────

setup-host:
	@$(ROOT)docker/setup.sh $(SETUP_ARGS)

setup: setup-host

build: check-pass
	@docker info >/dev/null 2>&1 || { echo "ERROR: Docker not running (Ubuntu: sudo systemctl start docker)"; exit 1; }
	@echo ">> building $(IMAGE) (module=$(MODULE) extra=$(MODULE_EXTRA))"
	@DOCKER_BUILDKIT=1 docker build \
		--build-arg CAMERA_EXTRA=$(MODULE_EXTRA) \
		-f $(ROOT)docker/Dockerfile \
		-t $(IMAGE) $(ROOT)docker

install: build
	@MODULE=$(MODULE) MODULE_EXTRA=$(MODULE_EXTRA) IMAGE=$(IMAGE) \
		$(ROOT)docker/install.sh $(MODULE) --extra $(MODULE_EXTRA)

install-pull:
	@MODULE=$(MODULE) MODULE_EXTRA=$(MODULE_EXTRA) IMAGE=$(IMAGE) \
		$(ROOT)docker/install.sh $(MODULE) --extra $(MODULE_EXTRA) --pull

build-orbbec:
	$(MAKE) build MODULE=camera_module MODULE_EXTRA=orbbec-linux
	$(MAKE) install MODULE=camera_module MODULE_EXTRA=orbbec-linux

run:
	MODULE=$(MODULE) MODULE_EXTRA=$(MODULE_EXTRA) IMAGE=$(IMAGE) \
		$(ROOT)docker/run_container.sh --module $(MODULE)

shell:
	MODULE=$(MODULE) MODULE_EXTRA=$(MODULE_EXTRA) IMAGE=$(IMAGE) \
		$(ROOT)docker/run_container.sh --gpu --module $(MODULE) --name $(MODULE)-dev bash

run-gui:
	MODULE=$(MODULE) MODULE_EXTRA=$(MODULE_EXTRA) IMAGE=$(IMAGE) \
		$(ROOT)docker/run_container.sh --gpu --x11 --module $(MODULE)

capture:
	MODULE=$(MODULE) MODULE_EXTRA=$(MODULE_EXTRA) $(ROOT)examples/capture/run_docker.sh $(MODULE) --extra $(MODULE_EXTRA)

# ── host (no Docker) ─────────────────────────────────────────────────────────

setup-host-native:
	@MODULE=$(MODULE) MODULE_EXTRA=$(SETUP_MODULE_EXTRA) $(ROOT)host/setup.sh --skip-install $(SETUP_ARGS)

setup-host-native-cam:
	@MODULE=camera_module MODULE_EXTRA=zivid $(ROOT)host/setup.sh $(SETUP_ARGS)

install-host: check-pass
	@MODULE=$(MODULE) MODULE_EXTRA=$(MODULE_EXTRA) \
		$(ROOT)host/install.sh $(MODULE) --extra $(MODULE_EXTRA)

install-host-pull: check-pass
	@MODULE=$(MODULE) MODULE_EXTRA=$(MODULE_EXTRA) \
		$(ROOT)host/install.sh $(MODULE) --extra $(MODULE_EXTRA) --pull

capture-host:
	@MODULE=$(MODULE) MODULE_EXTRA=$(MODULE_EXTRA) \
		$(ROOT)examples/capture/run_host.sh $(MODULE) --extra $(MODULE_EXTRA)

# pip install -e .  (no extras) — default for recon/cal modules

install-cam install-cam-host:
	$(MAKE) install-host MODULE=camera_module MODULE_EXTRA=$(MODULE_EXTRA)

install-recon install-recon-host:
	$(MAKE) install-host MODULE=reconstruction_module

install-cal install-cal-host:
	$(MAKE) install-host MODULE=calibration_module

install-recon-docker:
	$(MAKE) install MODULE=reconstruction_module

install-cal-docker:
	$(MAKE) install MODULE=calibration_module

# ── verify / clean ───────────────────────────────────────────────────────────

verify:
	@test -d "$(CAMERA_MODULE_DIR)/.venv" || (echo "run: make install-cam or make install-recon" && exit 1)
	@! docker history --no-trunc $(IMAGE) 2>/dev/null | grep -iE 'glpat-|gldt-|_token=' \
		|| (echo "LEAK in image history" && exit 1)
	@! grep -RIE 'https://[^/[:space:]]*:[^@[:space:]/]+@gitlab' "$(CAMERA_MODULE_DIR)/.venv" 2>/dev/null \
		|| (echo "LEAK in venv" && exit 1)
	@echo ">> verify OK"

clean:
	docker rmi $(IMAGE) || true

clean-all: clean
	rm -rf "$(CAMERA_MODULE_DIR)"
