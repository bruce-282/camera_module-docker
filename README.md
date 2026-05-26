# camera_module Docker

**Ubuntu 22.04 (네이티브)** 전제. WSL/Docker Desktop은 지원하지 않습니다.

| 무엇 | 위치 |
|------|------|
| **camera_module 코드 + `.venv`** | `~/camera_module` (호스트, git clone) |
| **설정·로그** | `~/.cmes/` |
| **이 repo** | `camera_module-docker` |

---

## repo 구조

```
camera_module-docker/
├── common/          pass + clone/pip 공통
│   ├── setup-pass.sh
│   └── install-common.sh
├── docker/          Docker 경로 (Zivid SDK in image)
│   ├── Dockerfile
│   ├── setup.sh
│   ├── install.sh
│   ├── run_container.sh
│   └── run_zivid_capture.sh
├── host/            호스트 경로 (Zivid SDK on Ubuntu)
│   ├── setup.sh
│   ├── install.sh
│   ├── deps.sh
│   └── run_zivid_capture.sh
├── configs/
└── Makefile
```

---

## 두 가지 설치 경로

### Docker (SDK를 이미지에)

```bash
cd camera_module-docker
make setup-host -- --gpg-key ~/gpg-private.asc   # 새 PC 1회
make install                                      # clone + venv
make shell                                        # 컨테이너 bash (--gpu)
./docker/run_zivid_capture.sh                     # Zivid 가상 카메라
```

### Host (Docker 없이)

```bash
cd camera_module-docker
make setup-host-native -- --gpg-key ~/gpg-private.asc   # 새 PC 1회
# 또는: make install-host

source ~/camera_module/.venv/bin/activate
./host/run_zivid_capture.sh
```

---

## pass (공통)

팀 store: `https://gitlab.cmes-ai.com/bruce/password-store.git`

| 항목 | pass 경로 |
|------|-----------|
| camera_module clone | `gitlab/cmesrobotics/camera_module` |
| crp_core pip | `gitlab/cmesrobotics/crp_core` |

```bash
make setup-pass          # common/setup-pass.sh
make check-pass
gpg --import ~/gpg-private.asc   # PC마다 1회
```

---

## Make targets

| 명령 | 경로 |
|------|------|
| `make setup-host` | `docker/setup.sh` |
| `make setup-host-native` | `host/setup.sh` |
| `make build` / `make install` | Docker |
| `make install-host` | Host |
| `make shell` | `docker/run_container.sh --gpu` |

---

## Zivid

- **Docker:** `make shell` 또는 `./docker/run_container.sh --gpu` + nvidia-container-toolkit
- **Host:** Zivid SDK `.deb`는 `host/deps.sh`가 설치 (`make install-host`)
- File Camera config 예시: [`configs/zivid_virtual_camera.config.example.yml`](configs/zivid_virtual_camera.config.example.yml)

---

## Cursor / Dev Container

`make build` 후 `.devcontainer/devcontainer.json` — workspace `~/camera_module`, 이미지 `cmes/camera-module:dev`.
