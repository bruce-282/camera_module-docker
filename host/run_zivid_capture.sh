#!/usr/bin/env bash
# Zivid File Camera on host (no Docker)
set -euo pipefail

CAMERA_MODULE_DIR="${CAMERA_MODULE_DIR:-$HOME/camera_module}"
VENV="${CAMERA_MODULE_DIR}/.venv"

if [[ ! -x "${VENV}/bin/python" ]]; then
    echo "ERROR: ${VENV} not ready — run: make install-host" >&2
    exit 1
fi

export CAMERA_MODULE_DIR
# shellcheck disable=SC1091
source "${VENV}/bin/activate"
cd "${CAMERA_MODULE_DIR}/scripts/python_run"

python3 <<'PY'
import os
from utils import CameraCaptureManager

mod = os.environ.get("CAMERA_MODULE_DIR") or os.path.join(
    os.environ["HOME"], "camera_module"
)
zivid_data = os.path.join(mod, "src", "crp_camera", "cam", "zivid", "data")
cfg = {
    "use_virtual_camera": True,
    "virtual_camera_path": zivid_data,
    "camera_config_path": os.path.join(mod, "configs", "zivid.config.yml"),
}
with CameraCaptureManager("zivid_camera", "ZividCapture", use_virtual_camera=True) as m:
    if not m.initialize_camera(
        camera_type="zivid",
        device_id="FileCameraZivid2PlusMR130.zfc",
        device_ip="",
        camera_config=cfg,
    ):
        raise SystemExit(1)
    print("OK — Zivid virtual camera initialized")
PY
