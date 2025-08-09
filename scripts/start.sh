#!/usr/bin/env bash
set -euo pipefail

log() { printf "%s %s\n" "$(date '+%F %T')" "$*"; }

# === Config ===
TORCH_VERSION="${TORCH_VERSION:-2.4.1}"
TORCHVISION_VERSION="${TORCHVISION_VERSION:-0.19.1}"
TORCHAUDIO_VERSION="${TORCHAUDIO_VERSION:-2.4.1}"

TORCH_CUDA="cpu"

log "🔍 Checking GPU and CUDA version ..."

if command -v nvidia-smi >/dev/null 2>&1; then
  CUDA_VERSION="$(nvidia-smi | grep -oP 'CUDA Version:\s*\K[0-9.]+' || true)"
  if [[ -n "${CUDA_VERSION}" ]]; then
    log "✅ NVIDIA GPU detected. CUDA ${CUDA_VERSION}"
    case "${CUDA_VERSION}" in
      12.8*|12.7*|12.6*|12.5*|12.4*) TORCH_CUDA="cu124" ;; # 12.4+ 使用 cu124
      12.3*|12.2*|12.1*)             TORCH_CUDA="cu121" ;;
      11.8*)                          TORCH_CUDA="cu118" ;;
      *)                               TORCH_CUDA="cpu" ; log "ℹ️ Unmapped CUDA (${CUDA_VERSION}); fallback to CPU wheels." ;;
    esac
  else
    log "⚠️ nvidia-smi found but failed to parse CUDA version; installing CPU wheels."
  fi
else
  log "❌ No GPU detected; installing CPU wheels."
fi

# === Optional: start sshd if available (容器啟動即能 SSH 登入) ===
if command -v service >/dev/null 2>&1 && service --status-all 2>/dev/null | grep -q ssh; then
  log "🚀 Starting ssh service ..."
  sudo service ssh start || true
fi

# === Pip bootstrap ===
log "🛠  Bootstrapping pip ..."
python3 -m pip install -U --quiet pip setuptools wheel

# === Install PyTorch with the right index ===
WHEEL_INDEX="https://download.pytorch.org/whl/${TORCH_CUDA}"
log "⬇️ Installing torch==${TORCH_VERSION} torchvision==${TORCHVISION_VERSION} torchaudio==${TORCHAUDIO_VERSION} from ${WHEEL_INDEX}"

retry() {
  local n=0 max=3 delay=5
  until "$@"; do
    n=$((n+1))
    if [[ $n -ge $max ]]; then
      log "❌ Command failed after ${max} attempts: $*"
      return 1
    fi
    log "⏳ Retry $n/$max in ${delay}s: $*"
    sleep "$delay"
  done
}

retry python3 -m pip install \
  "torch==${TORCH_VERSION}" \
  "torchvision==${TORCHVISION_VERSION}" \
  "torchaudio==${TORCHAUDIO_VERSION}" \
  --index-url "${WHEEL_INDEX}"

# === Extra libs ===
log "⬇️ Installing sentence-transformers ..."
retry python3 -m pip install "sentence-transformers>=2.6.1,<3.0.0"

# === Dev folders & permissions ===
USER_NAME="$(id -un)"
USER_UID="$(id -u)"
USER_GID="$(id -g)"

for d in "/home/${USER_NAME}/.vscode-server" "/home/${USER_NAME}/projects"; do
  mkdir -p "$d"
  sudo chown "${USER_UID}:${USER_GID}" "$d"
  chmod 755 "$d"
done

log "✅ Setup finished. Keeping the container alive."
tail -f /dev/null
