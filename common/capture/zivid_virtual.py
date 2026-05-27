#!/usr/bin/env python3
"""Zivid File Camera smoke test — paths from env (see configs/extras/zivid.env)."""
from __future__ import annotations

import os
import sys


def main() -> int:
    module_dir = os.environ["MODULE_DIR"]
    workdir = os.path.join(module_dir, os.environ.get("CAPTURE_WORKDIR", "scripts/python_run"))
    sys.path.insert(0, workdir)
    os.chdir(workdir)

    from utils import CameraCaptureManager

    zivid_data = os.path.join(module_dir, os.environ["CAPTURE_VIRTUAL_DATA"])
    cfg = {
        "use_virtual_camera": True,
        "virtual_camera_path": zivid_data,
        "camera_config_path": os.path.join(module_dir, os.environ["CAPTURE_CONFIG"]),
    }
    project = os.environ.get("CAPTURE_PROJECT", "ZividCapture")
    node = os.environ.get("CAPTURE_NODE", "zivid_camera")
    camera_type = os.environ.get("CAPTURE_CAMERA_TYPE", "zivid")
    device_id = os.environ["CAPTURE_DEVICE_ID"]

    with CameraCaptureManager(node, project, use_virtual_camera=True) as manager:
        if not manager.initialize_camera(
            camera_type=camera_type,
            device_id=device_id,
            device_ip="",
            camera_config=cfg,
        ):
            return 1
    print(f"OK — {camera_type} virtual camera initialized ({device_id})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
