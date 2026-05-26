# camera_module Docker

**Ubuntu 22.04 (네이티브)** 전제. WSL/Docker Desktop은 지원하지 않습니다.

`pass`로 **한 번** `make build` → 이미지 안에 `camera_module` + venv.  
호스트 clone 없음. IDE는 컨테이너 안 `/build/camera_module`만 열면 됩니다.

## 전제 (Ubuntu 호스트)

```bash
# Docker (Ubuntu)
sudo apt install docker.io docker-buildx-plugin
sudo usermod -aG docker $USER   # 재로그인

# pass
sudo apt install pass gnupg
```

- 권장: **Ubuntu 22.04 amd64** (Zivid SDK `.deb`가 `u22` 기준)
- USB 카메라: 호스트 udev rule 적용 후 컨테이너에 `/dev/bus/usb` 패스스루 (`run_container.sh` 기본)

## 1. pass

```
pass show gitlab/cmesrobotics/camera_module
pass show gitlab/cmesrobotics/crp_core
```

## 2. 빌드 (토큰은 여기서만)

```bash
make build
```

## 3. Cursor / VS Code (Ubuntu)

```bash
cd ~/sources/camera_module-docker
make build
cursor .    # 또는 code .
# → Dev Containers: Reopen in Container
```

- workspace: `/build/camera_module` (이미지 안 코드 + `.venv`)
- devcontainer는 Dockerfile을 직접 빌드하지 않음 (`pass` secret 때문)

## 4. 실행

```bash
make shell          # bash @ /build/camera_module
make run-gui        # X11 (Ubuntu 데스크톱)
./run_container.sh --gpu   # Zivid 등 GPU/OpenCL 필요 시
```

## Zivid (Ubuntu)

Zivid는 **호스트 OpenCL**이 필요합니다. 컨테이너만으로는 `CL_PLATFORM_NOT_FOUND_KHR`가 납니다.

호스트에서:

```bash
sudo apt install clinfo
clinfo -l                    # platform 1개 이상
# NVIDIA: 드라이버 설치 후
sudo gpasswd -a $USER render
sudo gpasswd -a $USER video
```

컨테이너 실행 시 GPU 넘기기: `./run_container.sh --gpu`  
virtual camera 경로는 Linux 경로로 설정 (`/path/to/zfc`, `data/zivid.config.yml` 등).

## 참고

- 코드 변경은 컨테이너 안. 의존성 바뀌면 `make build` 재실행.
- Orbbec only: `make build-orbbec`
