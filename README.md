# crp-module-install

CRP private 모듈 설치 (pass + host / Docker). **Ubuntu 22.04**

---

## 새 PC (한 번에)

`gpg-private.asc`는 **USB/예전 PC에서 복사** (GitLab에서 받지 않음).

```bash
# Host — apt + pass + install
make setup-host-native -- --gpg-key ~/gpg-private.asc

# Docker — 위 + docker + Zivid runtime
make setup-host -- --gpg-key ~/gpg-private.asc
```

---

## pass 이미 OK (모듈만 설치)

```bash
make check-pass

# Host
make install-cam               # camera_module + zivid (기본)
make install-recon
make install-cal

# Docker
make install
make shell
```

| Module | Host | pip extra |
|--------|------|-----------|
| camera_module | `make install-cam` | zivid / orbbec-linux / none |
| reconstruction_module | `make install-recon` | 없음 |
| calibration_module | `make install-cal` | 없음 |

extra 변경: `make install-cam MODULE_EXTRA=orbbec-linux`

---

## pass / GPG (수동으로 할 때)

| | 어디서 | 뭐 |
|---|--------|-----|
| `gpg --import ~/gpg-private.asc` | 로컬 파일 | **개인키** (열쇠) |
| `make setup-pass` | GitLab clone | **암호화된** 토큰 store |
| `make check-pass` | — | 열리는지 확인 |

토큰은 store에 암호화 저장 → **GPG 개인키 + 패스프레이즈**로만 `pass show` 가능.  
store: `https://gitlab.cmes-ai.com/bruce/password-store.git`

---

## 예시 (선택)

```bash
make capture-host    # Zivid File Camera — examples/capture/
```

---

## 개발용

- 모듈 프로필: `configs/modules/*.env` · camera extra: `configs/modules/camera_module/extras/`
- 새 모듈: `configs/modules/_template.env` 복사
