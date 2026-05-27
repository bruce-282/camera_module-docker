# camera_module Docker

**Ubuntu 22.04 (네이티브)** 전제.

| 무엇 | 위치 |
|------|------|
| **모듈 코드 + `.venv`** | `~/camera_module` 등 (프로필별) |
| **설정·로그** | `~/.cmes/` |
| **이 repo** | `camera_module-docker` |

---

## repo 구조

```
camera_module-docker/
├── common/                 pass, clone/pip
├── configs/
│   └── modules/            모듈별 프로필 (*.env)
│       └── camera_module/extras/   pip extra (camera_module 전용)
├── examples/
│   └── capture/            Zivid capture smoke test (example only)
├── docker/                 Docker 설치·실행
├── host/                   호스트 설치
└── Makefile
```

---

## CRP modules

| Module | Host install | pass (clone) |
|--------|--------------|--------------|
| `camera_module` | `make install-host` (+ `MODULE_EXTRA=zivid`) | `gitlab/cmesrobotics/camera_module` |
| `reconstruction_module` | `make install-recon` | `gitlab/cmesrobotics/reconstruction_module` |
| `calibration_module` | `make install-cal` | `gitlab/cmesrobotics/calibration_module` |

All modules use `PASS_PIP=gitlab/cmesrobotics/crp_core`. Recon/cal have **no pip extra** (`pip install -e .`).

```bash
make install-recon          # ~/reconstruction_module
make install-cal            # ~/calibration_module
make install-host MODULE=reconstruction_module   # same
```

Profiles: `configs/modules/*.env`

**pip extra**는 `camera_module`만: `configs/modules/camera_module/extras/{zivid,orbbec-linux,none}.env`  
recon/cal 등 다른 모듈은 extra 없음 (`pip install -e .`).

---

## 모듈 + EXTRA (camera_module only)

**모듈** = clone 대상 (`configs/modules/<name>.env`)  
**EXTRA** = `pip install -e ".[extra]"` — **`camera_module` 전용** (`configs/modules/camera_module/extras/`)

```bash
# camera_module + Zivid (기본)
make install-host

# Orbbec extra
make install-host MODULE=camera_module MODULE_EXTRA=orbbec-linux

# 다른 모듈 (extra 없음)
make install-host MODULE=reconstruction_module
make install-host MODULE=calibration_module

./host/install.sh --list          # 등록된 모듈 목록
```

새 모듈 추가: `configs/modules/_template.env` 복사 → `configs/modules/your_module.env` 편집.

---

## Docker

```bash
make setup-host -- --gpg-key ~/gpg-private.asc
make install MODULE=camera_module MODULE_EXTRA=zivid
make shell
make capture MODULE=camera_module MODULE_EXTRA=zivid   # examples/capture/
```

## Host (Docker 없이)

```bash
make setup-host-native -- --gpg-key ~/gpg-private.asc
make install-host MODULE=camera_module MODULE_EXTRA=zivid
make capture-host
```

---

## pass (공통)

팀 store: `https://gitlab.cmes-ai.com/bruce/password-store.git`

모듈 프로필의 `PASS_CLONE`, `PASS_PIP` 항목이 필요합니다.  
`camera_module` 기본값: `gitlab/cmesrobotics/camera_module`, `gitlab/cmesrobotics/crp_core`.

```bash
make setup-pass
gpg --import ~/gpg-private.asc
```

---

## Make targets

| 명령 | 설명 |
|------|------|
| `make list-modules` | 모듈 프로필 목록 |
| `make install` / `install-host` | `MODULE` + `MODULE_EXTRA` |
| `make capture` / `capture-host` | `examples/capture/` (camera + zivid extra 예시) |
| `make build-orbbec` | `MODULE_EXTRA=orbbec-linux` shortcut |

환경 변수: `MODULE`, `MODULE_EXTRA` (구 `CAMERA_EXTRA` 호환)
