#!/bin/bash

echo "🔍 檢查 GPU 與 CUDA 版本..."

# 預設值
TORCH_VERSION=2.4.1
TORCHVISION_VERSION=0.19.1
TORCHAUDIO_VERSION=2.4.1

# 判斷是否有 GPU
if command -v nvidia-smi &> /dev/null; then
    CUDA_VERSION=$(nvidia-smi | grep -oP 'CUDA Version: \K[0-9.]+')

    echo "✅ 偵測到 NVIDIA GPU，CUDA 版本為 $CUDA_VERSION"

    # 判斷適用的 PyTorch CUDA wheel
    case "$CUDA_VERSION" in
        12.4*) TORCH_CUDA=cu124 ;;
        12.1*) TORCH_CUDA=cu121 ;;
        11.8*) TORCH_CUDA=cu118 ;;
        *) TORCH_CUDA=cpu ;; # 未知版本則回退到 CPU
    esac
else
    echo "❌ 沒有偵測到 GPU，將安裝 CPU 版本"
    TORCH_CUDA=cpu
fi

echo "⬇️ 安裝 torch==${TORCH_VERSION} with ${TORCH_CUDA} backend..."
pip3 install torch==${TORCH_VERSION} \
              torchvision==${TORCHVISION_VERSION} \
              torchaudio==${TORCHAUDIO_VERSION} \
              --index-url https://download.pytorch.org/whl/${TORCH_CUDA}

pip3 install "sentence-transformers>=2.6.1,<3.0.0"

sudo chown "$(id -u)":"$(id -g)" /home/"$(id -un)"/.vscode-server && chmod 755 /home/"$(id -un)"/.vscode-server
sudo chown "$(id -u)":"$(id -g)" /home/"$(id -un)"/projects && chmod 755 /home/"$(id -un)"/projects

# keep the container running
tail -f /dev/null
