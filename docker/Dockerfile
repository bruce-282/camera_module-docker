# syntax=docker/dockerfile:1.6
# Runtime base for camera_module — code/venv live on host at ~/camera_module (make install).
# Target: Ubuntu 22.04 host + Docker CE (not WSL).

ARG CAMERA_EXTRA=zivid
ARG ZIVID_SDK_RELEASE=2.15.0+5fcc365b-1

FROM python:3.10-slim

ARG CAMERA_EXTRA
ARG ZIVID_SDK_RELEASE

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
        git ca-certificates curl \
        build-essential pkg-config \
        libusb-1.0-0 libusb-1.0-0-dev libudev1 \
        libgl1 libglib2.0-0 \
        ocl-icd-libopencl1 \
    && rm -rf /var/lib/apt/lists/*

RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh

ARG CAMERA_EXTRA
ARG ZIVID_SDK_RELEASE
RUN set -eu; \
    if [ "$CAMERA_EXTRA" = "zivid" ]; then \
        apt-get update && apt-get install -y --no-install-recommends wget python3-dev && \
        wget -q -O /tmp/zivid.deb \
            "https://downloads.zivid.com/sdk/releases/${ZIVID_SDK_RELEASE}/u22/amd64/zivid_${ZIVID_SDK_RELEASE}_amd64.deb" && \
        apt-get install -y /tmp/zivid.deb && rm -f /tmp/zivid.deb && \
        rm -rf /var/lib/apt/lists/*; \
    fi

WORKDIR /tmp
CMD ["python3", "-c", "print('camera_module base image OK — run: make install')"]
