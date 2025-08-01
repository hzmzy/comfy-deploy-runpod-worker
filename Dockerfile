# Use Nvidia CUDA base image
FROM nvidia/cuda:12.1.0-cudnn8-runtime-ubuntu22.04 as base

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

# Impact pack deps
RUN apt-get install -y libgl1-mesa-glx libglib2.0-0

# Clean up to reduce image size
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Clone ComfyUI repository
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /comfyui
# Force comfyui on a specific version
RUN cd /comfyui && git reset --hard 1e638a140b2f459595fafc73ade5ea5b4024d4b4

# Change working directory to ComfyUI
WORKDIR /comfyui

RUN pip install --no-cache-dir numpy==1.26.4
# Install ComfyUI dependencies
RUN pip3 install --no-cache-dir torch==2.1.1 torchvision==0.16.1 torchaudio==2.1.1 --index-url https://download.pytorch.org/whl/cu121
RUN pip3 install --no-cache-dir xformers==0.0.23 --index-url https://download.pytorch.org/whl/cu121
RUN pip3 install -r requirements.txt

# Install runpod
RUN pip3 install runpod requests


# upscale_models
RUN  wget -O models/upscale_models/4x-UltraSharp.pth https://huggingface.co/woods55/mine/resolve/main/4xLSDIR.pth?download=true

#loras
RUN  wget -O models/loras/Wan21_T2V_14B_lightx2v_cfg_step_distill_lora_rank32.safetensors https://huggingface.co/woods55/mine/resolve/main/Wan21_T2V_14B_lightx2v_cfg_step_distill_lora_rank32.safetensors?download=true
#vae
RUN  wget -O models/vae/wan2.2_vae.safetensors https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan2.2_vae.safetensors
#diffusion_models
RUN  wget -O models/diffusion_models/wan2.2_ti2v_5B_fp16.safetensors https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_ti2v_5B_fp16.safetensors
#vae
RUN  wget -O models/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors


# Install custom nodes

WORKDIR /comfyui/custom_nodes

#RUN git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Manager.git
#RUN cd ComfyUI-Manager && pip3 install -r requirements.txt

#WORKDIR /comfyui/custom_nodes/ComfyUI-Manager/startup-scripts
#ADD *_snapshot.json ./
#RUN mv *_snapshot.json restore-snapshot.json

WORKDIR /comfyui

ADD src/extra_model_paths.yaml ./

# Go back to the root
WORKDIR /

# ADD src/install_deps.py src/deps.json ./
# RUN python3 install_deps.py

WORKDIR /comfyui/custom_nodes

RUN git clone https://github.com/BennyKok/comfyui-deploy.git && cd comfyui-deploy && git reset --hard 6e068590a0831d10009074e65d23a083b31dd2d7
RUN cd comfyui-deploy && pip3 install -r requirements.txt


# 安装 onnxruntime 运行时
RUN git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git
RUN cd ComfyUI-VideoHelperSuite && pip3 install -r requirements.txt


WORKDIR /

# Add the start and the handler
ADD src/start.sh src/rp_handler.py test_input.json  ./


RUN chmod +x /start.sh


# Start the container
CMD /start.sh
