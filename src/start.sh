#!/usr/bin/env bash

# Use libtcmalloc for better memory management
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"

echo "runpod-worker-comfy: Starting ComfyUI"
python3 /comfyui/main.py  --disable-auto-launch --disable-metadata &

# start local api server -rp_serve_api http://localhost:8000
echo "runpod-worker-comfy: Starting RunPod Handler " 
python3 -u /rp_handler.py