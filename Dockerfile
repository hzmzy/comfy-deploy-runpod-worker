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
# RUN cd /comfyui && git reset --hard b12b48e170ccff156dc6ec11242bb6af7d8437fd

# Change working directory to ComfyUI
WORKDIR /comfyui

# Install ComfyUI dependencies
RUN pip3 install --no-cache-dir torch==2.1.1 torchvision==0.16.1 torchaudio==2.1.1 --index-url https://download.pytorch.org/whl/cu121
RUN pip3 install --no-cache-dir xformers==0.0.23 --index-url https://download.pytorch.org/whl/cu121
RUN pip3 install -r requirements.txt

# Install runpod
RUN pip3 install runpod requests

# Download checkpoints/vae/LoRA to include in image
# RUN wget -O models/checkpoints/sd_xl_base_1.0.safetensors https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors
# RUN wget -O models/vae/sdxl_vae.safetensors https://huggingface.co/stabilityai/sdxl-vae/resolve/main/sdxl_vae.safetensors
# RUN wget -O models/vae/sdxl-vae-fp16-fix.safetensors https://huggingface.co/madebyollin/sdxl-vae-fp16-fix/resolve/main/sdxl_vae.safetensors
# RUN wget -O models/loras/xl_more_art-full_v1.safetensors https://civitai.com/api/download/models/152309

# Example for adding specific models into image
# ADD models/checkpoints/sd_xl_base_1.0.safetensors models/checkpoints/
# ADD models/vae/sdxl_vae.safetensors models/vae/

# ADD  models/loras/Hyper-FLUX.1-dev-8steps-lora_rank1.safetensors models/loras/
# ADD  models/loras/pixel-art-flux-v3-learning-rate-4.safetensors models/loras/

# ADD  models/checkpoints/flux1-dev-fp8.safetensors models/checkpoints/
# ADD  models/controlnet/diffusion_pytorch_model.safetensors models/controlnet/


#RUN wget -O models/checkpoints/flux1-dev-fp8.safetensors https://huggingface.co/Comfy-Org/flux1-dev/resolve/main/flux1-dev-fp8.safetensors
#RUN wget -O models/controlnet/diffusion_pytorch_model.safetensors https://huggingface.co/Shakker-Labs/FLUX.1-dev-ControlNet-Union-Pro/resolve/main/diffusion_pytorch_model.safetensors

# Install custom nodes

WORKDIR /comfyui/custom_nodes

RUN git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Manager.git
RUN cd ComfyUI-Manager && pip3 install -r requirements.txt

#WORKDIR /comfyui/custom_nodes/ComfyUI-Manager/startup-scripts
#ADD *_snapshot.json ./
#RUN mv *_snapshot.json restore-snapshot.json

WORKDIR /comfyui

ADD src/extra_model_paths.yaml ./

# Go back to the root
WORKDIR /

# RUN git clone https://github.com/ssitu/ComfyUI_UltimateSDUpscale --recursive
# ADD src/install_deps.py src/deps.json ./
# RUN python3 install_deps.py

WORKDIR /comfyui/custom_nodes

RUN git clone https://github.com/BennyKok/comfyui-deploy.git && cd comfyui-deploy && git reset --hard 6e068590a0831d10009074e65d23a083b31dd2d7
RUN cd comfyui-deploy && pip3 install -r requirements.txt

RUN git clone https://github.com/yolain/ComfyUI-Easy-Use.git
RUN cd ComfyUI-Easy-Use && pip3 install -r requirements.txt
RUN git clone https://github.com/kijai/ComfyUI-KJNodes.git
RUN cd ComfyUI-KJNodes && pip3 install -r requirements.txt
RUN git clone https://github.com/EllangoK/ComfyUI-post-processing-nodes.git
RUN git clone https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git
RUN git clone https://github.com/chflame163/ComfyUI_LayerStyle.git

RUN cd ComfyUI_LayerStyle && pip install  whl/docopt-0.6.2-py2.py3-none-any.whl && pip3 install whl/hydra_core-1.3.2-py3-none-any.whl 
RUN cd ComfyUI_LayerStyle && pip install -r requirements.txt --use-deprecated legacy-resolver
RUN cd ComfyUI_LayerStyle && pip uninstall -y onnxruntime 
RUN cd ComfyUI_LayerStyle && pip uninstall -y opencv-python opencv-contrib-python opencv-python-headless opencv-contrib-python-headless
RUN cd ComfyUI_LayerStyle && pip install -r repair_dependency_list.txt 
		
	


WORKDIR /

# Add the start and the handler
ADD src/start.sh src/rp_handler.py test_input.json  ./

VOLUME /comfyui/models
VOLUME /comfyui/output

RUN chmod +x /start.sh


# Start the container
CMD /start.sh
