# -------- Stage 1: Base Builder --------
ARG BASE_IMAGE=nvcr.io/nvidia/cuda:12.6.3-cudnn-runtime-ubuntu24.04
FROM ${BASE_IMAGE} AS base-builder

ENV COMFYUI_VERSION=0.3.49 \
    DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    PYTHONUNBUFFERED=1 \
    CMAKE_BUILD_PARALLEL_LEVEL=8 \
    PATH="/opt/venv/bin:${PATH}"

# 安装运行和构建所需依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-dev \
    git wget curl ca-certificates \
    libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 ffmpeg \
    build-essential ninja-build gcc-11 g++-11 \
 && ln -sf /usr/bin/python3 /usr/bin/python \
 && ln -sf /usr/bin/pip3 /usr/bin/pip \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

# 设置 GCC
ENV CC=/usr/bin/gcc-11 \
    CXX=/usr/bin/g++-11

# 安装 uv 并创建 venv
RUN wget -qO- https://astral.sh/uv/install.sh | sh \
    && ln -s /root/.local/bin/uv /usr/local/bin/uv \
    && uv venv /opt/venv --python /usr/bin/python3

# 安装 comfy-cli
RUN uv pip install comfy-cli pip setuptools wheel

# 安装 ComfyUI
RUN /usr/bin/yes | comfy --workspace /comfyui install --version "${COMFYUI_VERSION}" --nvidia

# 复制配置文件
WORKDIR /comfyui
ADD src/extra_model_paths.yaml ./
WORKDIR /

# 安装运行依赖
RUN uv pip install runpod requests websocket-client

# 添加启动脚本
ADD src/start.sh handler.py test_input.json ./
RUN chmod +x /start.sh

# 自定义节点安装脚本
COPY scripts/comfy-node-install.sh /usr/local/bin/comfy-node-install
RUN chmod +x /usr/local/bin/comfy-node-install
ENV PIP_NO_INPUT=1

# 网络模式切换脚本
COPY scripts/comfy-manager-set-mode.sh /usr/local/bin/comfy-manager-set-mode
RUN chmod +x /usr/local/bin/comfy-manager-set-mode

# Stage 2: Download models
FROM base-builder AS downloader

# Change working directory to ComfyUI
WORKDIR /comfyui

# Create necessary directories upfront wan2.2 ti2v 5b
# RUN mkdir -p models/checkpoints models/vae models/unet models/clip
# upscale_models
# RUN  wget -O models/upscale_models/4x-UltraSharp.pth https://huggingface.co/woods55/mine/resolve/main/4xLSDIR.pth?download=true

#loras
# RUN  wget -O models/loras/Wan21_T2V_14B_lightx2v_cfg_step_distill_lora_rank32.safetensors https://huggingface.co/woods55/mine/resolve/main/Wan21_T2V_14B_lightx2v_cfg_step_distill_lora_rank32.safetensors?download=true
#vae
# RUN  wget -O models/vae/wan2.2_vae.safetensors https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan2.2_vae.safetensors
#diffusion_models
# RUN  wget -O models/diffusion_models/wan2.2_ti2v_5B_fp16.safetensors https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_ti2v_5B_fp16.safetensors
#text_encoders
# RUN  wget -O models/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors



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
# RUN mkdir -p models/checkpoints models/vae models/unet models/clip
# upscale_models
# RUN  wget -O models/upscale_models/4x-UltraSharp.pth https://huggingface.co/woods55/mine/resolve/main/4xLSDIR.pth?download=true
#loras
# RUN  wget -O models/loras/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/lightx2v_I2V_14B_480p_cfg_step_distill_rank64_bf16.safetensors
#vae
# RUN  wget -O models/vae/wan2.2_vae.safetensors https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan2.2_vae.safetensors
#diffusion_models
# RUN  wget -O models/diffusion_models/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors
# RUN  wget -O models/diffusion_models/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors
#text_encoders
# RUN  wget -O models/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors



# Stage 3: Final image
FROM ${BASE_IMAGE} AS final

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:${PATH}"

# 安装最小运行依赖（不含编译工具）
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip \
    git wget ca-certificates \
    libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 ffmpeg \
 && ln -sf /usr/bin/python3 /usr/bin/python \
 && ln -sf /usr/bin/pip3 /usr/bin/pip \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

# 从 builder 拷贝 venv 和 ComfyUI
COPY --from=base-builder /opt/venv /opt/venv
COPY --from=base-builder /comfyui /comfyui
COPY --from=base-builder /start.sh /start.sh
COPY --from=base-builder /usr/local/bin/comfy-node-install /usr/local/bin/comfy-node-install
COPY --from=base-builder /usr/local/bin/comfy-manager-set-mode /usr/local/bin/comfy-manager-set-mode

# 从 downloader 拷贝模型
COPY --from=downloader /comfyui/models /comfyui/models

WORKDIR /comfyui/custom_nodes

# 安装 ComfyUI-ComfyUI_essentials
RUN git clone https://github.com/cubiq/ComfyUI_essentials.git
RUN cd ComfyUI_essentials && pip3 install -r requirements.txt
# 安装 ComfyUI-VideoHelperSuite
RUN git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git
RUN cd ComfyUI-VideoHelperSuite && pip3 install -r requirements.txt
# 安装 ComfyUI-WanVideoWrapper
RUN git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git
RUN cd ComfyUI-WanVideoWrapper && pip3 install -r requirements.txt
# 安装 ComfyUI_LayerStyle
RUN git clone https://github.com/chflame163/ComfyUI_LayerStyle.git
RUN cd ComfyUI_LayerStyle && pip3 install -r requirements.txt


 # Go back to the root
WORKDIR /
RUN pip3 install sageattention

VOLUME /comfyui/models
VOLUME /comfyui/input
VOLUME /comfyui/output

EXPOSE 8188

# Set the default command to run when starting the container
CMD ["/start.sh"]

