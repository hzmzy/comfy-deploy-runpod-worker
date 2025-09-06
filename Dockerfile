# Build argument for base image selection
ARG BASE_IMAGE=nvcr.io/nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04

# Stage 1: Base image with common dependencies
FROM ${BASE_IMAGE} AS base

# Build arguments for this stage (defaults provided by docker-bake.hcl)
ENV COMFYUI_VERSION=0.3.49

# Prevents prompts from packages asking for user input during installation
ENV DEBIAN_FRONTEND=noninteractive \
   PIP_PREFER_BINARY=1 \
   PYTHONUNBUFFERED=1 \
   CMAKE_BUILD_PARALLEL_LEVEL=8

# Install Python, git and other necessary tools
RUN apt-get update && apt-get install -y \
    python3.12 \
    python3.12-venv \
    python3.12-dev \
    python3-pip \
    git \
    wget \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    ffmpeg \
    ninja-build \
    aria2 \
    build-essential \
    gcc \
    && ln -sf /usr/bin/python3.12 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip

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
RUN uv pip install triton comfy-cli pip setuptools wheel

# Install ComfyUI
RUN /usr/bin/yes | comfy --workspace /comfyui install --skip-manager --version "${COMFYUI_VERSION}" --nvidia;

RUN uv pip install opencv-python

# Change working directory to ComfyUI
WORKDIR /comfyui

# Support for the network volume
ADD src/extra_model_paths.yaml ./

# Go back to the root
WORKDIR /

# Install Python runtime dependencies for the handler
RUN uv pip install runpod requests websocket-client sageattention

# Add application code and scripts
ADD src/start.sh handler.py test_input.json ./
RUN chmod +x /start.sh

# Add script to install custom nodes
COPY scripts/comfy-node-install.sh /usr/local/bin/comfy-node-install
RUN chmod +x /usr/local/bin/comfy-node-install

# Prevent pip from asking for confirmation during uninstall steps in custom nodes
ENV PIP_NO_INPUT=1

## Copy helper script to switch Manager network mode at container start
COPY scripts/comfy-manager-set-mode.sh /usr/local/bin/comfy-manager-set-mode
RUN chmod +x /usr/local/bin/comfy-manager-set-mode

# Stage 2: Download models
FROM base AS downloader

# Change working directory to ComfyUI
WORKDIR /comfyui

# Create necessary directories upfront wan2.2 i2v 14b
# RUN mkdir -p models/checkpoints models/vae models/unet models/clip
# upscale_models
#RUN  wget -O models/upscale_models/4x-UltraSharp.pth https://huggingface.co/woods55/mine/resolve/main/4xLSDIR.pth?download=true

# Stage 3: Final image
FROM base AS final

# Copy models from stage 2 to the final image
COPY --from=downloader /comfyui/models /comfyui/models

WORKDIR /comfyui/custom_nodes


# 安装 ComfyUI-ComfyUI_essentials
RUN git clone https://github.com/cubiq/ComfyUI_essentials.git
RUN cd ComfyUI_essentials && pip3 install -r requirements.txt
# 安装 ComfyUI-VideoHelperSuite
RUN git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git
RUN cd ComfyUI-VideoHelperSuite && pip3 install -r requirements.txt
# 安装 ComfyUI-WanVideoWrapper

RUN git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git && cd ComfyUI-WanVideoWrapper && git reset --hard 4eeaf1ea194ed32e0a2fef2a16201c450a8da40f
RUN cd ComfyUI-WanVideoWrapper && pip3 install -r requirements.txt
# 安装 ComfyUI_LayerStyle
RUN git clone https://github.com/chflame163/ComfyUI_LayerStyle.git
RUN cd ComfyUI_LayerStyle && pip3 install -r requirements.txt
#安装 ComfyUI-KJNodes
RUN git clone https://github.com/kijai/ComfyUI-KJNodes.git
RUN cd ComfyUI-KJNodes && pip3 install -r requirements.txt
#安装 ComfyUI-Nudenet
RUN git clone https://github.com/phuvinh010701/ComfyUI-Nudenet.git
RUN cd ComfyUI-Nudenet && pip3 install -r requirements.txt
#安装 ComfyUI-segment-anything-2
RUN git clone https://github.com/kijai/ComfyUI-segment-anything-2.git
#安装 ComfyUI-Florence2
RUN git clone https://github.com/kijai/ComfyUI-Florence2.git
RUN cd ComfyUI-Florence2 && pip3 install -r requirements.txt
#安装 ComfyUI-Addoor
RUN git clone https://github.com/Eagle-CN/ComfyUI-Addoor.git
RUN cd ComfyUI-Addoor && pip3 install -r requirements.txt
#安装 ComfyUI-Custom-Scripts
RUN git clone https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git
#安装 ComfyUI-TeaCache
RUN git clone https://github.com/welltop-cn/ComfyUI-TeaCache.git
RUN cd ComfyUI-TeaCache && pip3 install -r requirements.txt
#安装 ComfyUI_JPS-Nodes
RUN git clone https://github.com/JPS-GER/ComfyUI_JPS-Nodes.git



 # Go back to the root
WORKDIR /

VOLUME /comfyui/models
VOLUME /comfyui/input
VOLUME /comfyui/output

EXPOSE 8188

# Set the default command to run when starting the container
CMD ["/start.sh"]

