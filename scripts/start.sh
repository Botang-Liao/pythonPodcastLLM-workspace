#!/usr/bin/env bash
set -euo pipefail

echo "🔍 檢查 GPU 與 CUDA 版本..."

# 預設值
TORCH_VERSION=2.4.1
TORCHVISION_VERSION=0.19.1
TORCHAUDIO_VERSION=2.4.1
TORCH_CUDA="cpu"

# 判斷是否有 GPU
if command -v nvidia-smi >/dev/null 2>&1; then
  CUDA_VERSION="$(nvidia-smi | grep -oP 'CUDA Version:\s*\K[0-9.]+' || true)"
  if [[ -n "${CUDA_VERSION}" ]]; then
    echo "✅ 偵測到 NVIDIA GPU，CUDA 版本為 ${CUDA_VERSION}"
    case "${CUDA_VERSION}" in
      12.8*|12.7*|12.6*|12.5*|12.4*) TORCH_CUDA="cu124" ;;
      12.3*|12.2*|12.1*)             TORCH_CUDA="cu121" ;;
      11.8*)                          TORCH_CUDA="cu118" ;;
      *)                              TORCH_CUDA="cpu" ; echo "ℹ️ 未對應的 CUDA 版本，改裝 CPU 版。" ;;
    esac
  else
    echo "⚠️ 取得 CUDA 版本失敗，改裝 CPU 版。"
    TORCH_CUDA="cpu"
  fi
else
  echo "❌ 沒有偵測到 GPU，將安裝 CPU 版本"
  TORCH_CUDA="cpu"
fi

echo "🛠 更新 pip..."
python3 -m pip install -U --quiet pip setuptools wheel

echo "⬇️ 安裝 torch==${TORCH_VERSION} with ${TORCH_CUDA} backend..."
python3 -m pip install \
  "torch==${TORCH_VERSION}" \
  "torchvision==${TORCHVISION_VERSION}" \
  "torchaudio==${TORCHAUDIO_VERSION}" \
  --index-url "https://download.pytorch.org/whl/${TORCH_CUDA}"

echo "⬇️ 安裝 sentence-transformers..."
python3 -m pip install "sentence-transformers>=2.6.1,<3.0.0"

# === 啟動並設定 OLLAMA ===
export OLLAMA_HOST=0.0.0.0:11434
# 如需固定共用路徑，取消下一行註解（要與 Dockerfile 中目錄/權限一致）
export OLLAMA_MODELS=/opt/ollama

# 背景啟動 daemon
nohup ollama serve > /home/"$(id -un)"/ollama.log 2>&1 &

# 等待服務就緒（最多 60 秒）
for i in $(seq 1 60); do
  if curl -fsS "http://127.0.0.1:11434/api/tags" >/dev/null; then
    echo "✅ ollama 就緒"
    break
  fi
  sleep 1
done

# （可選）第一次啟動時預拉模型；失敗不阻斷容器啟動
if [[ "${PREPULL_MODELS:-1}" == "1" ]]; then
  ollama pull deepseek-r1:14b || echo "⚠️ 預拉模型失敗，之後可手動 docker exec 再拉"
fi

# 準備資料夾並設定權限
mkdir -p "/home/$(id -un)/.vscode-server" "/home/$(id -un)/projects"
sudo chown "$(id -u)":"$(id -g)" /home/"$(id -un)"/.vscode-server && chmod 755 /home/"$(id -un)"/.vscode-server
sudo chown "$(id -u)":"$(id -g)" /home/"$(id -un)"/projects && chmod 755 /home/"$(id -un)"/projects

# keep the container running
tail -f /dev/null
