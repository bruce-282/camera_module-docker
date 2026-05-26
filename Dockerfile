# syntax=docker/dockerfile:1.6
# Target: Ubuntu 22.04 host + Docker CE (not WSL).
# Build: make build  (pass → BuildKit secret)

ARG CAMERA_REPO=gitlab.cmes-ai.com/crp/module/camera_module.git
ARG CAMERA_BRANCH=dev/0.x
ARG CAMERA_EXTRA=zivid
ARG ZIVID_SDK_RELEASE=2.15.0+5fcc365b-1

FROM python:3.10-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    UV_LINK_MODE=copy

RUN apt-get update && apt-get install -y --no-install-recommends \
        git ca-certificates curl \
        build-essential pkg-config \
        libusb-1.0-0 libusb-1.0-0-dev \
        libudev1 libgl1 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh

ARG CAMERA_REPO
ARG CAMERA_BRANCH
ARG CAMERA_EXTRA
ARG ZIVID_SDK_RELEASE

# Zivid SDK (.deb) before camera_module — required to build `pip install zivid`.
RUN if [ "$CAMERA_EXTRA" = "zivid" ]; then \
        apt-get update && apt-get install -y --no-install-recommends wget python3-dev && \
        wget -q -O /tmp/zivid.deb \
            "https://downloads.zivid.com/sdk/releases/${ZIVID_SDK_RELEASE}/u22/amd64/zivid_${ZIVID_SDK_RELEASE}_amd64.deb" && \
        apt-get install -y /tmp/zivid.deb && \
        rm -f /tmp/zivid.deb && \
        rm -rf /var/lib/apt/lists/*; \
    fi

WORKDIR /build

RUN --mount=type=secret,id=camera_secret,required=true \
    set -eu; \
    TOKEN="$(sed -n '1p' /run/secrets/camera_secret)"; \
    USER="$(sed -nE 's/^login:[[:space:]]*//p' /run/secrets/camera_secret)"; \
    git clone --branch "${CAMERA_BRANCH}" \
        "https://${USER}:${TOKEN}@${CAMERA_REPO}" /build/camera_module; \
    git -C /build/camera_module remote set-url origin "https://${CAMERA_REPO}"; \
    unset TOKEN USER

WORKDIR /build/camera_module
RUN uv venv --python 3.10 .venv

ENV VIRTUAL_ENV=/build/camera_module/.venv \
    PATH="/build/camera_module/.venv/bin:$PATH"

# crp_core is a pyproject git dep — pass token via CRP_CORE_TOKEN + git credential helper.
RUN --mount=type=secret,id=crp_core_secret,required=true \
    set -eu; \
    export CRP_CORE_TOKEN="$(sed -n '1p' /run/secrets/crp_core_secret)"; \
    export CRP_CORE_USER="$(sed -nE 's/^login:[[:space:]]*//p' /run/secrets/crp_core_secret)"; \
    git config --global credential.https://gitlab.cmes-ai.com.helper \
        '!f() { echo "username=${CRP_CORE_USER}"; echo "password=${CRP_CORE_TOKEN}"; }; f'; \
    uv pip install -e ".[${CAMERA_EXTRA}]"; \
    git config --global --unset credential.https://gitlab.cmes-ai.com.helper; \
    unset CRP_CORE_TOKEN CRP_CORE_USER

RUN ! grep -RIE "https://[^/[:space:]]*:[^@[:space:]/]+@gitlab" /build/camera_module/.venv 2>/dev/null \
    || (echo "ERROR: token URL in venv" && exit 1)

FROM python:3.10-slim AS runtime

ARG CAMERA_EXTRA=zivid
ARG ZIVID_SDK_RELEASE=2.15.0+5fcc365b-1

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    VIRTUAL_ENV=/build/camera_module/.venv \
    PATH="/build/camera_module/.venv/bin:$PATH"

RUN set -eu; \
    apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates libusb-1.0-0 libudev1 libgl1 libglib2.0-0; \
    if [ "$CAMERA_EXTRA" = "zivid" ]; then \
        apt-get install -y --no-install-recommends wget && \
        wget -q -O /tmp/zivid.deb \
            "https://downloads.zivid.com/sdk/releases/${ZIVID_SDK_RELEASE}/u22/amd64/zivid_${ZIVID_SDK_RELEASE}_amd64.deb" && \
        apt-get install -y /tmp/zivid.deb && rm -f /tmp/zivid.deb; \
    fi; \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/camera_module /build/camera_module

RUN useradd --create-home --shell /bin/bash bruce \
    && chown -R bruce:bruce /build/camera_module
USER bruce
WORKDIR /build/camera_module

CMD ["python", "-c", "import crp_camera, crp_core; print('OK')"]
