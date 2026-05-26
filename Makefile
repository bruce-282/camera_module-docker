# camera_module Docker build — tokens from `pass` only.

SHELL             := /bin/bash

IMAGE             ?= cmes/camera-module:dev
CAMERA_EXTRA      ?= zivid
PASS_CAMERA       ?= gitlab/cmesrobotics/camera_module
PASS_CRP_CORE     ?= gitlab/cmesrobotics/crp_core

.PHONY: build build-orbbec verify run run-gui shell clean check-pass

check-pass:
	@for entry in $(PASS_CAMERA) $(PASS_CRP_CORE); do \
		pass show "$$entry" >/dev/null 2>&1 || { echo "ERROR: pass '$$entry' not found"; exit 1; }; \
		pass show "$$entry" | grep -qE '^login:[[:space:]]' || { echo "ERROR: pass '$$entry' needs 'login:' line"; exit 1; }; \
	done
	@echo ">> pass OK"

build: check-pass
	@docker info >/dev/null 2>&1 || { echo "ERROR: Docker not running"; exit 1; }
	@echo ">> building $(IMAGE) (extra=$(CAMERA_EXTRA))"
	@DOCKER_BUILDKIT=1 docker build \
		--build-arg CAMERA_EXTRA=$(CAMERA_EXTRA) \
		--secret id=camera_secret,src=<(pass show $(PASS_CAMERA)) \
		--secret id=crp_core_secret,src=<(pass show $(PASS_CRP_CORE)) \
		-t $(IMAGE) .

build-orbbec:
	$(MAKE) build CAMERA_EXTRA=orbbec-linux

run:
	IMAGE=$(IMAGE) ./run_container.sh

shell:
	IMAGE=$(IMAGE) ./run_container.sh --name camera_module-dev bash

run-gui:
	IMAGE=$(IMAGE) ./run_container.sh --x11

verify:
	@! docker history --no-trunc $(IMAGE) | grep -iE 'glpat-|gldt-|_token=' \
		|| (echo "LEAK in image history" && exit 1)
	@! docker run --rm --entrypoint /bin/sh $(IMAGE) -c \
		"grep -RIE 'https://[^/[:space:]]*:[^@[:space:]/]+@gitlab' /build /opt 2>/dev/null" \
		|| (echo "LEAK in /build or /opt" && exit 1)
	@echo ">> verify OK"

clean:
	docker rmi $(IMAGE) || true
