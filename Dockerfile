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
    python3.12 \
    python3.12-venv \
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
RUN uv pip install comfy-cli pip setuptools wheel

# Install ComfyUI
RUN /usr/bin/yes | comfy --workspace /comfyui install --version "${COMFYUI_VERSION}" --nvidia; 


# Change working directory to ComfyUI
WORKDIR /comfyui

# Support for the network volume
ADD src/extra_model_paths.yaml ./

# Go back to the root
WORKDIR /

# Install Python runtime dependencies for the handler
RUN uv pip install runpod requests websocket-client

# Add application code and scripts
ADD src/start.sh handler.py test_input.json ./
RUN chmod +x /start.sh

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

# Create necessary directories upfront wan2.2 i2v 14b
# RUN mkdir -p models/checkpoints models/vae models/unet models/clip
# upscale_models
#RUN  wget -O models/upscale_models/4x-UltraSharp.pth https://huggingface.co/woods55/mine/resolve/main/4xLSDIR.pth?download=true
#loras
RUN  wget -O models/loras/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors
#vae
RUN  wget -O models/vae/Wan2_1_VAE_bf16.safetensors https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1_VAE_bf16.safetensors
#diffusion_models
RUN  wget -O models/diffusion_models/Wan2_2-I2V-A14B-HIGH_fp8_e4m3fn_scaled_KJ.safetensors https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/I2V/Wan2_2-I2V-A14B-HIGH_fp8_e4m3fn_scaled_KJ.safetensors
RUN  wget -O models/diffusion_models/Wan2_2-I2V-A14B-LOW_fp8_e4m3fn_scaled_KJ.safetensors https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/I2V/Wan2_2-I2V-A14B-LOW_fp8_e4m3fn_scaled_KJ.safetensors
#text_encoders
RUN  wget -O models/text_encoders/umt5-xxl-enc-bf16.safetensors https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/umt5-xxl-enc-bf16.safetensors

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

 # Go back to the root
WORKDIR /

VOLUME /comfyui/models
VOLUME /comfyui/input
VOLUME /comfyui/output

EXPOSE 8188

# Set the default command to run when starting the container
CMD ["/start.sh"]

