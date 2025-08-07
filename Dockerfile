# Build argument for base image selection
ARG BASE_IMAGE=nvidia/cuda:12.6.3-cudnn-runtime-ubuntu24.04

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

VOLUME /comfyui/models
VOLUME /comfyui/input
VOLUME /comfyui/output

EXPOSE 8188

# Set the default command to run when starting the container
CMD ["/start.sh"]

# Stage 2: Download models
FROM base AS downloader

ARG HUGGINGFACE_ACCESS_TOKEN
# Set default model type if none is provided
ARG MODEL_TYPE=flux1-dev-fp8

# Change working directory to ComfyUI
WORKDIR /comfyui

# Create necessary directories upfront
# RUN mkdir -p models/checkpoints models/vae models/unet models/clip
# upscale_models
RUN  wget -O models/upscale_models/4x-UltraSharp.pth https://huggingface.co/woods55/mine/resolve/main/4xLSDIR.pth?download=true

#loras
RUN  wget -O models/loras/Wan21_T2V_14B_lightx2v_cfg_step_distill_lora_rank32.safetensors https://huggingface.co/woods55/mine/resolve/main/Wan21_T2V_14B_lightx2v_cfg_step_distill_lora_rank32.safetensors?download=true
#vae
RUN  wget -O models/vae/wan2.2_vae.safetensors https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan2.2_vae.safetensors
#diffusion_models
RUN  wget -O models/diffusion_models/wan2.2_ti2v_5B_fp16.safetensors https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_ti2v_5B_fp16.safetensors
#text_encoders
RUN  wget -O models/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors

# Stage 3: Final image
FROM base AS final

# Copy models from stage 2 to the final image
COPY --from=downloader /comfyui/models /comfyui/models

WORKDIR /comfyui/custom_nodes

# 安装 ComfyUI-VideoHelperSuite
RUN git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git
RUN cd ComfyUI-VideoHelperSuite && pip3 install -r requirements.txt
# 安装 ComfyUI-ComfyUI_essentials
RUN git clone https://github.com/cubiq/ComfyUI_essentials.git
RUN cd ComfyUI_essentials && pip3 install -r requirements.txt
