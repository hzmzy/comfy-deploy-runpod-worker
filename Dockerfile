# Build argument for base image selection
ARG BASE_IMAGE=nvcr.io/nvidia/cuda:12.6.3-cudnn-runtime-ubuntu24.04

# Stage 1: Base image with common dependencies
FROM ${BASE_IMAGE} AS base

# Build arguments for this stage (defaults provided by docker-bake.hcl)
ENV COMFYUI_VERSION=0.3.49

# Prevents prompts from packages asking for user input during installation
ENV DEBIAN_FRONTEND=noninteractive
# Prefer binary wheels over source distributions for faster pip installations
ENV PIP_PREFER_BINARY=1
# Ensures output from python is printed immediately to the terminal without buffering
ENV PYTHONUNBUFFERED=1
# Speed up some cmake builds
ENV CMAKE_BUILD_PARALLEL_LEVEL=8

# Install Python, git and other necessary tools
RUN apt-get update && apt-get install -y \
    python3.11 \
    python3.11-venv \
    python3.11-dev \
    libopenblas-dev \
    build-essential \
    git \
    wget \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    ffmpeg \
    && ln -sf /usr/bin/python3.12 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip

RUN apt-get install -y unzip

# Clean up to reduce image size
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Install uv (latest) using official installer and create isolated venv
RUN wget -qO- https://astral.sh/uv/install.sh | sh \
    && ln -s /root/.local/bin/uv /usr/local/bin/uv \
    && ln -s /root/.local/bin/uvx /usr/local/bin/uvx \
    && uv venv /opt/venv

# Use the virtual environment for all subsequent commands
ENV PATH="/opt/venv/bin:${PATH}"

# Install comfy-cli + dependencies needed by it to install ComfyUI
RUN uv pip install comfy-cli pip setuptools wheel matplotlib

# Install ComfyUI
RUN /usr/bin/yes | comfy --workspace /comfyui install --skip-manager --version "${COMFYUI_VERSION}" --nvidia;


# Change working directory to ComfyUI
WORKDIR /comfyui

RUN pip install --no-cache-dir numpy==1.26.4
# Install ComfyUI dependencies
# Torch + CUDA 12.1
RUN pip3 install --no-cache-dir torch==2.4.0 torchvision==0.18.1 torchaudio==2.3.1 --index-url https://download.pytorch.org/whl/cu121
# xformers 对应 2.4.1
RUN pip3 install --no-cache-dir xformers==0.0.27.post2

RUN pip3 install -r requirements.txt

# Install runpod
RUN pip3 install runpod requests websocket-client

WORKDIR /comfyui

ADD src/extra_model_paths.yaml ./

# Go back to the root
WORKDIR /

# Install Python runtime dependencies for the handler
RUN uv pip install runpod requests websocket-client

# Add script to install custom nodes
COPY scripts/comfy-node-install.sh /usr/local/bin/comfy-node-install
RUN chmod +x /usr/local/bin/comfy-node-install

# Prevent pip from asking for confirmation during uninstall steps in custom nodes
ENV PIP_NO_INPUT=1

# Copy helper script to switch Manager network mode at container start
COPY scripts/comfy-manager-set-mode.sh /usr/local/bin/comfy-manager-set-mode
RUN chmod +x /usr/local/bin/comfy-manager-set-mode

# Stage 2: Download models
FROM base AS downloader

# Change working directory to ComfyUI
WORKDIR /comfyui

# ReActor models
RUN  mkdir -p models/facerestore_models
RUN  wget -O models/facerestore_models/codeformer-v0.1.0.pth https://huggingface.co/FMNing/codeformer-v0.1.0/resolve/main/codeformer-v0.1.0.pth
RUN  mkdir -p models/facedetection
RUN  wget -O models/facedetection/parsing_parsenet.pth https://github.com/sczhou/CodeFormer/releases/download/v0.1.0/parsing_parsenet.pth
RUN  mkdir -p models/facedetection
RUN  wget -O models/facedetection/detection_Resnet50_Final.pth https://github.com/xinntao/facexlib/releases/download/v0.1.0/detection_Resnet50_Final.pth
RUN  mkdir -p models/insightface
RUN  wget -O models/insightface/inswapper_128.onnx https://huggingface.co/ezioruan/inswapper_128.onnx/resolve/main/inswapper_128.onnx
RUN  mkdir -p models/insightface/models/buffalo_l
RUN  wget -O models/insightface/models/buffalo_l/buffalo_l.zip https://github.com/deepinsight/insightface/releases/download/v0.7/buffalo_l.zip
#解压 buffalo_l.zip 到当前目录
RUN unzip models/insightface/models/buffalo_l/buffalo_l.zip -d models/insightface/models/buffalo_l
#loras
RUN  wget -O models/loras/Realism_Lora_By_Stable_yogi_SDXL8.1.safetensors https://huggingface.co/woods55/mine/resolve/main/Realism_Lora_By_Stable_yogi_SDXL8.1.safetensors?download=true
RUN  wget -O models/loras/Super_Skin_Detailer_By_Stable_Yogi_PD0_V1.safetensors https://huggingface.co/woods55/mine/resolve/main/Super_Skin_Detailer_By_Stable_Yogi_PD0_V1.safetensors?download=true
#embeddings
RUN  wget -O models/embeddings/Stable_Yogis_PDXL_Positives.safetensors https://huggingface.co/woods55/mine/resolve/main/Stable_Yogis_PDXL_Positives.safetensors?download=true
RUN  wget -O models/embeddings/Stable_Yogis_PDXL_Negatives-neg.safetensors https://huggingface.co/woods55/mine/resolve/main/Stable_Yogis_PDXL_Negatives-neg.safetensors?download=true

#checkpoints
RUN  #wget -O models/checkpoints/realismByStableYogi_v50FP16.safetensors https://huggingface.co/woods55/mine/resolve/main/realismByStableYogi_v50FP16.safetensors?download=true
RUN  wget -O models/checkpoints/realismByStableYogi_v50FP16.safetensors https://huggingface.co/woods55/mine/resolve/main/realismSDXLByStable_v70FP16.safetensors


# Stage 3: Final image
FROM base AS final

# Copy models from stage 2 to the final image
COPY --from=downloader /comfyui/models /comfyui/models

WORKDIR /comfyui/custom_nodes

# 安装 onnxruntime 运行时
RUN pip3 install --no-cache-dir onnxruntime-gpu
RUN git clone https://github.com/ZooHero500/comfyui-reactor-node.git
RUN cd comfyui-reactor-node && pip3 install --no-cache-dir -r requirements.txt

 # Go back to the root
WORKDIR /

VOLUME /comfyui/models
VOLUME /comfyui/input
VOLUME /comfyui/output

EXPOSE 8188

# Add application code and scripts
ADD src/start.sh handler.py test_input.json ./
RUN chmod +x /start.sh

# Set the default command to run when starting the container
CMD ["/start.sh"]

