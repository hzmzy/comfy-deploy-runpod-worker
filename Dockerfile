# Use Nvidia CUDA base image
FROM nvidia/cuda:12.4.1-runtime-ubuntu20.04 as base

ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_PREFER_BINARY=1
ENV PYTHONUNBUFFERED=1

# Install Python, git, and dependencies in one layer
RUN apt-get update && apt-get install -y \
    python3.10 python3-pip git wget \
    libgl1-mesa-glx libglib2.0-0 \
 && rm -rf /var/lib/apt/lists/*

RUN pip install --upgrade pip

# Clone ComfyUI repo and checkout fixed commit
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /comfyui \
 && cd /comfyui \
 && git reset --hard 0a3d062e0660741146d50f6601e3eeca211d92d5

WORKDIR /comfyui

# Install PyTorch with CUDA 12.4
RUN pip3 install --no-cache-dir torch==2.4.1+cu124 torchvision==0.19.1+cu124 torchaudio==2.4.1+cu124 --index-url https://download.pytorch.org/whl/cu124

# Install xformers (compatible version for PyTorch 2.4.x)
RUN pip3 install --no-cache-dir xformers==0.0.28.post3 --index-url https://download.pytorch.org/whl/cu124

# Install ComfyUI dependencies
RUN pip3 install -r requirements.txt

# Install runpod client
RUN pip3 install runpod requests

# Create necessary directories upfront wan2.2 ti2v 5b
# RUN mkdir -p models/checkpoints models/vae models/unet models/clip
# upscale_models
RUN  #wget -O models/upscale_models/4x-UltraSharp.pth https://huggingface.co/woods55/mine/resolve/main/4xLSDIR.pth?download=true

#loras
RUN  #wget -O models/loras/Wan21_T2V_14B_lightx2v_cfg_step_distill_lora_rank32.safetensors https://huggingface.co/woods55/mine/resolve/main/Wan21_T2V_14B_lightx2v_cfg_step_distill_lora_rank32.safetensors?download=true
#vae
RUN  #wget -O models/vae/wan2.2_vae.safetensors https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan2.2_vae.safetensors
#diffusion_models
RUN  #wget -O models/diffusion_models/wan2.2_ti2v_5B_fp16.safetensors https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_ti2v_5B_fp16.safetensors
#text_encoders
#RUN  wget -O models/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors

# Create necessary directories upfront wan2.2 ti2v 5b kj
RUN mkdir -p models/checkpoints models/vae models/diffusion_models models/text_encoders
# upscale_models
RUN  wget -O models/upscale_models/4x-UltraSharp.pth https://huggingface.co/woods55/mine/resolve/main/4xLSDIR.pth?download=true
#vae
RUN  wget -O models/vae/wan2.2_vae.safetensors https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan2.2_vae.safetensors
#diffusion_models
RUN  wget -O models/diffusion_models/Wan2_2-TI2V-5B_fp8_e4m3fn_scaled_KJ.safetensors https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/TI2V/Wan2_2-TI2V-5B_fp8_e4m3fn_scaled_KJ.safetensors
#text_encoders
RUN  wget -O models/text_encoders/umt5-xxl-enc-bf16.safetensors https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/umt5-xxl-enc-bf16.safetensors

# Create necessary directories upfront wan2.2 i2v 14b
#RUN mkdir -p models/checkpoints models/vae models/unet models/clip
# upscale_models
#RUN  wget -O models/upscale_models/4x-UltraSharp.pth https://huggingface.co/woods55/mine/resolve/main/4xLSDIR.pth?download=true
#loras
#RUN  wget -O models/loras/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors
#vae
#RUN  wget -O models/vae/wan2.2_vae.safetensors https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan2.2_vae.safetensors
#diffusion_models
#RUN  wget -O models/diffusion_models/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors
#RUN  wget -O models/diffusion_models/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors
#text_encoders
#RUN  wget -O models/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors


# Create necessary directories upfront wan2.2 i2v 14b kj
#RUN mkdir -p models/checkpoints models/vae models/unet models/clip
# upscale_models
#RUN  wget -O models/upscale_models/4x-UltraSharp.pth https://huggingface.co/woods55/mine/resolve/main/4xLSDIR.pth?download=true
#loras
#RUN  wget -O models/loras/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors
#vae
#RUN  wget -O models/vae/Wan2_1_VAE_bf16.safetensors https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1_VAE_bf16.safetensors
#diffusion_models
#RUN  wget -O models/diffusion_models/Wan2_2-I2V-A14B-LOW_fp8_e4m3fn_scaled_KJ.safetensors https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/T2V/Wan2_2-T2V-A14B-LOW_fp8_e4m3fn_scaled_KJ.safetensors
#RUN  wget -O models/diffusion_models/Wan2_2-I2V-A14B-HIGH_fp8_e4m3fn_scaled_KJ.safetensors https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/T2V/Wan2_2-T2V-A14B_HIGH_fp8_e4m3fn_scaled_KJ.safetensors
#text_encoders
#RUN  wget -O models/text_encoders/umt5-xxl-enc-bf16.safetensors https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/umt5-xxl-enc-bf16.safetensors
# Install custom nodes

WORKDIR /comfyui/custom_nodes

RUN git clone https://github.com/BennyKok/comfyui-deploy.git && cd comfyui-deploy && git reset --hard 6e068590a0831d10009074e65d23a083b31dd2d7
RUN cd comfyui-deploy && pip3 install -r requirements.txt

# 安装 ComfyUI-ComfyUI_essentials
RUN git clone https://github.com/cubiq/ComfyUI_essentials.git
RUN cd ComfyUI_essentials && pip3 install -r requirements.txt
# 安装 ComfyUI-VideoHelperSuite
RUN git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git
RUN cd ComfyUI-VideoHelperSuite && pip3 install -r requirements.txt
# 安装 ComfyUI-WanVideoWrapper
#RUN git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git && git reset --hard 1e638a140b2f459595fafc73ade5ea5b4024d4b4
#RUN cd ComfyUI-WanVideoWrapper && pip3 install -r requirements.txt
## 安装 ComfyUI_LayerStyle
#RUN git clone https://github.com/chflame163/ComfyUI_LayerStyle.git
#RUN cd ComfyUI_LayerStyle && pip3 install -r requirements.txt
#
#RUN git clone https://github.com/kijai/ComfyUI-KJNodes.git
#RUN cd ComfyUI-KJNodes && pip3 install -r requirements.txt
#
#RUN git clone https://github.com/jamesWalker55/comfyui-various.git
 # Go back to the root
WORKDIR /

# Add the start and the handler
ADD src/start.sh src/handler.py test_input.json  ./

VOLUME /comfyui/models
VOLUME /comfyui/input
VOLUME /comfyui/output

EXPOSE 8188

RUN chmod +x /start.sh

# Start the container
CMD /start.sh