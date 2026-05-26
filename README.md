# camera_module Docker

**Ubuntu 22.04 (네이티브)** 전제. WSL/Docker Desktop은 지원하지 않습니다.

| 무엇 | 위치 |
|------|------|
| **camera_module 코드 + `.venv`** | `~/camera_module` (호스트, git clone) |
| **Docker 이미지** | Zivid SDK / Python / uv 런타임만 (코드 없음) |
| **설정·로그** | `~/.cmes/` |
| **이 repo** | `camera_module-docker` (빌드/실행 스크립트) |

IDE·터미널 작업 디렉터리: **`~/camera_module`** (`/build/...` 아님).

---

## 한 번에 세팅 (새 PC)

```bash
cd camera_module-docker
./setup-host.sh --gpg-key ~/Downloads/gpg-private.asc   # 또는 ./setup-host.sh
# = apt + pass + make install  →  ~/camera_module 생성
```

옵션: `--skip-build`(install 생략) · `--skip-nvidia` · `--check`

---

## 빠른 시작 (이미 pass + install 완료)

```bash
cd camera_module-docker
./setup-pass.sh --check
make shell          # Zivid: GPU/OpenCL 포함 (내부 --gpu)
```

처음이거나 venv 없으면:

```bash
make build          # base Docker 이미지만
make install        # ~/camera_module clone + uv venv
```

---

## 디렉터리 구조

```
~/camera_module/              ← git clone, .venv, 코드 (여기서 작업)
~/camera_module/.venv/
~/.cmes/ZividCapture/         ← 프로젝트 config / 로그
~/Documents/.../camera_module-docker/   ← Docker/Makefile
```

---

## pass가 하는 일 (한 번 이해하면 PC 바꿀 때 덜 헷갈림)

| 무엇 | 어디 | 설명 |
|------|------|------|
| GitLab 토큰 (암호화됨) | `password-store.git` | `*.gpg` 파일. 팀이 공유 |
| GPG **개인키** | 각 PC `~/.gnupg` | 복호화용. **GitLab에 올리지 않음** |
| GPG 패스프레이즈 | 본인만 | 개인키 파일 유출 시 추가 방어 |
| `make build` | 이 repo | Docker **base** 이미지 (Zivid SDK 등) |
| `make install` | 이 repo | `~/camera_module` clone + `.venv` |

- **웹/GitLab에 매번 토큰 등록할 필요 없음** — store에 이미 있음.
- **새 개발 PC마다** GPG 개인키 import + store clone **한 번**만 하면 됨.
- 일상 작업(`make build`, `pass show`)은 **같은 PC에서 반복 설정 불필요**.

팀 store:

- 저장소: `https://gitlab.cmes-ai.com/bruce/password-store.git`
- 빌드에 필요한 항목: `gitlab/cmesrobotics/camera_module`, `gitlab/cmesrobotics/crp_core`
- `.gpg-id`: 이 store를 암호화한 GPG ID (예: `juntae.kim`) — **이 ID와 맞는 개인키**가 PC에 있어야 함

---

## 새 PC / 새 Ubuntu 세팅 (전체 순서)

### 0. 전제 패키지

자동: `./setup-host.sh` · 수동:

```bash
# Docker
sudo apt install docker.io docker-buildx
sudo usermod -aG docker $USER   # 재로그인

# pass (또는 make setup-pass)
sudo apt install pass gnupg git
```

- 권장: **Ubuntu 22.04 amd64** (Zivid SDK `.deb`가 `u22` 기준)
- USB 카메라: 호스트 udev rule 후 컨테이너 `/dev/bus/usb` 패스스루 (`run_container.sh` 기본)

### 1. GPG 개인키 import (PC마다 1회)

예전 PC·USB 등에서 `gpg-private.asc` (또는 팀 백업)를 받아:

```bash
gpg --import ~/Downloads/gpg-private.asc
gpg --list-secret-keys --keyid-format LONG
# .gpg-id와 맞는 키(예: juntae.kim@cmesrobotics.ai)가 sec 로 보여야 함
```

**다른 PC에서 scp로 보내기** (IP는 `hostname -I`로 확인):

```bash
# 예전 PC에서
scp ~/gpg-private.asc bruce@<새PC-IP>:~/Downloads/gpg-private.asc
```

import 후 Downloads 복사본 삭제:

```bash
rm ~/Downloads/gpg-private.asc
```

> **주의:** `setup-pass.sh`가 제안하는 **새 GPG 키 생성은 팀 store용이 아님.**  
> 실수로 `pass init`만 한 로컬 store는 팀 repo와 맞지 않음.

### 2. password-store clone + 확인

```bash
cd camera_module-docker
make setup-pass
# 또는: ./setup-pass.sh
```

스크립트가 하는 일: `pass`/`git` 설치 → GitLab에서 store clone (기존 잘못된 `~/.password-store` 있으면 교체 확인) → 항목 검증.

수동으로 할 경우:

```bash
rm -rf ~/.password-store   # 잘못된 pass init 잔여물 있을 때만
git clone https://gitlab.cmes-ai.com/bruce/password-store.git ~/.password-store
pass show gitlab/cmesrobotics/camera_module
pass show gitlab/cmesrobotics/crp_core
```

### 3. 빌드

```bash
make build
```

토큰은 **여기서만** Docker BuildKit secret으로 들어감 (이미지 history에 남지 않도록 설계).

---

## setup-pass.sh

| 명령 | 용도 |
|------|------|
| `./setup-pass.sh` / `make setup-pass` | 설치 + clone/pull + 항목 확인 |
| `./setup-pass.sh --check` | `make check-pass`와 동일 검증 |
| `./setup-pass.sh --pull` | store만 git pull |
| `./setup-pass.sh --install` | apt로 pass/gnupg/git만 |
| `./setup-pass.sh --local` | **팀 store 아님** — 로컬 전용 빈 store |

환경 변수 (Makefile과 동일):

- `PASS_STORE_REPO` — 기본 `https://gitlab.cmes-ai.com/bruce/password-store.git`
- `PASS_CAMERA` — 기본 `gitlab/cmesrobotics/camera_module`
- `PASS_CRP_CORE` — 기본 `gitlab/cmesrobotics/crp_core`

---

## GPG 개인키 백업 (어디에 둘지)

**올리면 안 되는 곳:** GitLab/GitHub, Slack, 메일, 클라우드 Drive 등 — store의 `*.gpg`와 **같은 곳에 두면 pass 의미 없음**.

**권장 백업 (1~2벌):**

1. **예전/주 PC** — `~/gpg-private.asc` 또는 `~/.gnupg` (새 PC 세팅 시 scp/USB로 import)
2. **집 USB 1개** — 가방에 매일 휴대 X. 가능하면 `zip -e`로 추가 암호

```bash
# USB 백업 예 (선택)
zip -e gpg-backup.zip ~/gpg-private.asc
```

**일상:** 키는 `~/.gnupg`에만 두고 들고 다니지 않음.  
**새 PC:** 백업에서 import → `make setup-pass` → `make build` (5분 루틴).

---

## 문제 해결

### `pass show` / `--check` 실패 (No secret key)

- 팀 `.gpg-id`와 **다른** GPG 키만 PC에 있음 → 올바른 `gpg-private.asc` import
- 실수로 만든 로컬 키 삭제 (예):

```bash
gpg --delete-secret-key <잘못된_KEY_ID>
gpg --delete-key <잘못된_KEY_ID>
```

### clone 후 GitLab 토큰 입력 프롬프트

- 항목은 store에 **이미 있음**. 프롬프트는 **복호화 실패**를 잘못 안내한 것 → **Ctrl+C**, GPG 키부터 맞추기
- `./setup-pass.sh --check`로 확인

### `pass git clone` / `not a git repository`

- `pass init` 잔여 `~/.password-store` 때문 → `make setup-pass` (자동 삭제 후 `git clone`)

### GPG 패스프레이즈

- `pass show` 시 물어볼 수 있음 — 키 생성/export 때 설정한 비밀번호. 파일과 별개로 기억해 둘 것.

---

## Cursor / VS Code

```bash
cd camera_module-docker
make build
cursor .    # 또는 code .
# → Dev Containers: Reopen in Container
```

- workspace: `~/camera_module`
- devcontainer는 Dockerfile을 직접 빌드하지 않음 (`pass` secret 때문)

---

## 실행

```bash
make shell          # bash @ ~/camera_module (--gpu)
make run-gui        # X11 (Ubuntu 데스크톱)
./run_container.sh --gpu   # Zivid 등 GPU/OpenCL 필요 시
```

---

## Zivid (Ubuntu)

Zivid는 **OpenCL** 필요 (`CL_PLATFORM_NOT_FOUND_KHR` = OpenCL 미설정).

**호스트:**

```bash
sudo apt install clinfo
clinfo -l                    # NVIDIA platform 1개 이상
sudo gpasswd -a $USER render video   # 실제 USB 카메라 시, 재로그인
```

**컨테이너** (호스트 GPU/OpenCL + ICD 전달):

```bash
sudo apt install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

make build                   # 이미지에 ocl-icd-libopencl1 포함
./run_container.sh --gpu     # --gpus all + /etc/OpenCL/vendors 마운트
```

컨테이너 안 확인:

```bash
python3 -c "import ctypes; o=ctypes.CDLL('libOpenCL.so.1'); n=ctypes.c_uint32(); o.clGetPlatformIDs(0,None,ctypes.byref(n)); print('platforms', n.value)"
# platforms 1 이면 OK
```

컨테이너 안 `sudo`/`apt` 불필요 — OpenCL은 호스트 드라이버 + `--gpu`로 들어옴.

### File Camera (가상 Zivid) — Windows 경로 오류

`Failed to load file camera 'C:\ProgramData\Zivid/...'` → **Windows에서 쓰던 기본 경로**를 Linux/컨테이너가 찾는 경우입니다.

프로젝트 config (예: `~/.cmes/ZividCapture/configs/zivid_camera.config.yml`)에서:

```yaml
common:
  use_virtual_camera: true
  device_id: FileCameraZivid2PlusMR130.zfc   # data/ 아래 파일명
  enabled_camera_types: [zivid]
zivid:
  virtual_camera_path: /home/USER/camera_module/src/crp_camera/cam/zivid/data
```

- `.zfc` 파일: `~/camera_module/src/crp_camera/cam/zivid/data/`
- 예시 전체: [`configs/zivid_virtual_camera.config.example.yml`](configs/zivid_virtual_camera.config.example.yml)
- `use_virtual_camera: false`이면 실제 USB Zivid 또는 SDK 기본 FileCamera(MR60, Windows 경로)로 연결 시도 → Linux에서 실패

MR60 파일을 쓸 경우: `.zfc`를 위 `data/`에 복사하고 `device_id`만 `FileCameraZivid2PlusMR60.zfc`로 변경.

virtual camera 경로는 Linux 경로 (`/path/to/zfc`, `configs/zivid.config.yml` 등).

---

## 참고

- 코드 변경은 컨테이너 안. 의존성 바뀌면 `make build` 재실행.
- Orbbec only: `make build-orbbec`
- store 동기화: `./setup-pass.sh --pull`
