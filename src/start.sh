#!/usr/bin/env bash


echo "worker-comfyui: Starting ComfyUI"

SERVE_API_LOCALLY="${SERVE_API_LOCALLY:-false}"

# Serve the API and don't shutdown the container
if [ "$SERVE_API_LOCALLY" == "true" ]; then
    python -u /comfyui/main.py --disable-auto-launch --disable-metadata --listen --log-stdout &

    echo "worker-comfyui: Starting RunPod Handler"
    python -u /handler.py --rp_serve_api --rp_api_host=0.0.0.0
else
    python -u /comfyui/main.py --disable-auto-launch --disable-metadata --log-stdout &

    echo "worker-comfyui: Starting RunPod Handler"
    python -u /handler.py
fi
