# Use Nvidia CUDA base image (12.4.1 + cuDNN + Ubuntu 22.04)
FROM nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04 as base

# Prevents prompts from packages asking for user input during installation
ENV DEBIAN_FRONTEND=noninteractive
# Prefer binary wheels over source distributions for faster pip installations
ENV PIP_PREFER_BINARY=1
# Ensures output from python is printed immediately to the terminal without buffering
ENV PYTHONUNBUFFERED=1 

# Install Python, git and other necessary tools
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3-pip \
    git \
    wget

RUN pip install --upgrade pip

# Install dependencies for impact pack
RUN apt-get install -y libgl1-mesa-glx libglib2.0-0

# Clean up to reduce image size
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Clone ComfyUI repository
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /comfyui
# Force ComfyUI on a specific version
RUN cd /comfyui && git reset --hard 560d38f34c5bd532f89f2178f01ee819cf145820

# Change working directory to ComfyUI
WORKDIR /comfyui

# Install PyTorch (CUDA 12.4 build)
RUN pip3 install --no-cache-dir torch==2.5.1+cu124 torchvision==0.20.1+cu124 torchaudio==2.5.1+cu124 --index-url https://download.pytorch.org/whl/cu124

# Install latest xformers compatible with PyTorch 2.5.1 + cu124
RUN pip3 install --no-cache-dir xformers==0.0.29.post3 --index-url https://download.pytorch.org/whl/cu124


# Install ComfyUI dependencies
RUN pip3 install -r requirements.txt

# Install runpod
RUN pip3 install runpod requests websocket-client

# Support for the network volume
ADD src/extra_model_paths.yaml ./

# Go back to the root
WORKDIR /

# Stage 2: Download models
FROM base AS downloader

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

 # Go back to the root
WORKDIR /


# Add application code and scripts
ADD src/start.sh handler.py test_input.json ./
RUN chmod +x /start.sh

VOLUME /comfyui/models
VOLUME /comfyui/input
VOLUME /comfyui/output

EXPOSE 8188

# Set the default command to run when starting the container
CMD ["/start.sh"]

