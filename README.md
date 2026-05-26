# camera_module Docker

`pass`로 **한 번** `make build` → 이미지 안에 `camera_module` + venv 설치.  
호스트에 clone 없음. Cursor/VS Code는 **컨테이너 안** `/build/camera_module`만 열면 됩니다.

## 1. pass

```
pass show gitlab/cmesrobotics/camera_module
pass show gitlab/cmesrobotics/crp_core
```

## 2. 빌드 (토큰은 여기서만)

```bash
make build
```

## 3. Cursor / VS Code에서 편집

```bash
cd ~/sources/camera_module-docker
make build          # 최초 1회, 또는 Dockerfile 변경 시
cursor .            # 이 repo 열기
# → "Reopen in Container"
```

- `.devcontainer`가 `cmes/camera-module:dev` 이미지에 attach
- workspace: **`/build/camera_module`** (이미지에 들어 있는 코드 + `.venv`)
- Dockerfile을 devcontainer가 직접 빌드하지 않음 (`pass` secret 때문)

## 4. 터미널만

```bash
make shell          # /build/camera_module 에서 bash
make run-gui        # X11
```

## 참고

- 코드 변경은 **컨테이너 안** `/build/camera_module`. `make build` 다시 하면 이미지가 새로 만들어짐.
- git / pass는 호스트에서 (이 docker repo용).
- Orbbec: `make build-orbbec`
