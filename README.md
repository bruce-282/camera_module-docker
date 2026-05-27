# camera_module Docker

**Ubuntu 22.04 (네이티브)** 전제.

| 무엇 | 위치 |
|------|------|
| **모듈 코드 + `.venv`** | `~/camera_module` 등 (프로필별) |
| **설정·로그** | `~/.cmes/` |
| **이 repo** | `camera_module-docker` |

---

## 1. pass (공통 — 먼저)

모든 설치(`make install`, `make install-host`)는 **pass + GPG**가 먼저 필요합니다.

**GPG 한 줄:** GitLab 토큰은 password-store에 **암호화** 저장됨 → PC에 **GPG 개인키**(`gpg-private.asc`)를 import해야 `pass show`로 토큰을 읽을 수 있음.  
개인키는 **GitLab/Slack에 올리지 않음** (USB·예전 PC에서 새 PC로만 복사). `pass show` 시 묻는 **패스프레이즈**는 그 키의 비밀번호.

팀 store: `https://gitlab.cmes-ai.com/bruce/password-store.git`

| pass 항목 | 용도 |
|-----------|------|
| `gitlab/cmesrobotics/camera_module` | camera_module clone |
| `gitlab/cmesrobotics/reconstruction_module` | reconstruction_module clone |
| `gitlab/cmesrobotics/calibration_module` | calibration_module clone |
| `gitlab/cmesrobotics/crp_core` | pip install (모든 모듈 공통) |

```bash
# 새 PC — GPG 키 import (1회)
gpg --import ~/gpg-private.asc

# password-store clone + 항목 확인
make setup-pass # ~/.password-store 를 GitLab에서 clone/pull
make check-pass # 열리는지 확인
```

`make setup-pass` / `make check-pass` 실패 시 → GPG 키·store부터 해결한 뒤 아래로 진행.

---

## 2. 설치 (pass OK 이후)

### Host (Docker 없이)

```bash
make setup-host-native -- --gpg-key ~/gpg-private.asc   # 새 PC: apt + pass + install
# 또는 pass 이미 OK면:
make install-host MODULE=camera_module MODULE_EXTRA=zivid
make install-recon
make install-cal
```

### Docker

```bash
make setup-host -- --gpg-key ~/gpg-private.asc   # 새 PC: apt + docker + pass + install
# 또는 pass 이미 OK면:
make install MODULE=camera_module MODULE_EXTRA=zivid
make shell
```

### camera_module + pip extra (Zivid / Orbbec)

`EXTRA`는 **camera_module만**: `configs/modules/camera_module/extras/`

```bash
make install-host                                    # extra=zivid (기본)
make install-host MODULE=camera_module MODULE_EXTRA=orbbec-linux
make install-host MODULE=camera_module MODULE_EXTRA=none
```

recon / cal은 extra 없음 → `pip install -e .` 만.

```bash
make install-recon
make install-cal
./host/install.sh --list
```

---

## 3. 예시 (선택)

Zivid File Camera smoke test — **설치 필수 아님**, `examples/capture/` 참고.

```bash
make capture-host MODULE=camera_module MODULE_EXTRA=zivid
make capture
```

config 예시: `examples/capture/zivid_camera.config.example.yml`

---

## CRP modules

| Module | 설치 | clone pass |
|--------|------|------------|
| `camera_module` | `make install-host` (+ extra) | `gitlab/cmesrobotics/camera_module` |
| `reconstruction_module` | `make install-recon` | `gitlab/cmesrobotics/reconstruction_module` |
| `calibration_module` | `make install-cal` | `gitlab/cmesrobotics/calibration_module` |

새 모듈: `configs/modules/_template.env` 복사 → 편집.

---

## repo 구조

```
camera_module-docker/
├── common/                 pass, clone/pip
├── configs/modules/        모듈 프로필 (*.env)
│   └── camera_module/extras/   pip extra (camera_module 전용)
├── examples/capture/       Zivid smoke test (example)
├── docker/                 Docker 설치·실행
├── host/                   호스트 설치
└── Makefile
```

---

## Make targets

| 명령 | 설명 |
|------|------|
| `make setup-pass` / `check-pass` | **1단계** — pass store |
| `make setup-host-native` | Host 새 PC (pass + apt + install) |
| `make setup-host` | Docker 새 PC (pass + docker + install) |
| `make install-host` / `install` | 모듈 설치 (`MODULE`, `MODULE_EXTRA`) |
| `make install-recon` / `install-cal` | shortcut |
| `make capture-host` / `capture` | examples (camera + zivid) |
| `make list-modules` | 등록된 모듈 목록 |

환경 변수: `MODULE`, `MODULE_EXTRA` (구 `CAMERA_EXTRA` 호환)
