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

RUN apt-get install -y unzip

# Clean up to reduce image size
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Clone ComfyUI repository
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /comfyui
# Force comfyui on a specific version
RUN cd /comfyui && git reset --hard b12b48e170ccff156dc6ec11242bb6af7d8437fd

# Change working directory to ComfyUI
WORKDIR /comfyui

RUN pip install --no-cache-dir numpy==1.26.4
# Install ComfyUI dependencies
RUN pip3 install --no-cache-dir torch==2.1.1 torchvision==0.16.1 torchaudio==2.1.1 --index-url https://download.pytorch.org/whl/cu121
RUN pip3 install --no-cache-dir xformers==0.0.23 --index-url https://download.pytorch.org/whl/cu121
RUN pip3 install -r requirements.txt

# Install runpod
RUN pip3 install runpod requests


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
RUN pip3 install --no-cache-dir onnxruntime-gpu
RUN git clone https://github.com/ZooHero500/comfyui-reactor-node.git
RUN cd comfyui-reactor-node && pip3 install -r requirements.txt


WORKDIR /

# Add the start and the handler
ADD src/start.sh src/rp_handler.py test_input.json  ./


RUN chmod +x /start.sh


# Start the container
CMD /start.sh
