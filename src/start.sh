#!/usr/bin/env bash

# Use libtcmalloc for better memory management
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"

# Ensure ComfyUI-Manager runs in offline network mode inside the container
comfy-manager-set-mode offline || echo "worker-comfyui - Could not set ComfyUI-Manager network_mode" >&2

echo "worker-comfyui: Starting ComfyUI"
export WAN_LOWVRAM=0
export WAN_FORCE_OFFLOAD=0

# Allow operators to tweak verbosity; default is DEBUG.
: "${COMFY_LOG_LEVEL:=DEBUG}"

if python3 -c "import sageattention" 2>/dev/null; then
    echo "🔧 SageAttention detected - using optimized mode"
else
    echo "Building SageAttention in the background"
    (
      git clone https://github.com/thu-ml/SageAttention.git
      cd SageAttention || exit 1
      python3 setup.py install
#      cd /
#      pip install --no-cache-dir triton
    ) &> /var/log/sage_build.log &      # run in background, log output

    BUILD_PID=$!
    echo "Background build started (PID: $BUILD_PID)"

    # poll every 5 s until the PID is gone
    while kill -0 "$BUILD_PID" 2>/dev/null; do
      echo "🛠️ Building SageAttention in progress... (this can take around 5 minutes)"
      sleep 10
    done

# Check if sageattention is installed and available
if python3 -c "import sageattention" 2>/dev/null; then
    python -u /comfyui/main.py --disable-auto-launch --disable-metadata --use-sage-attention --disable-lowvram --listen --verbose "${COMFY_LOG_LEVEL}" --log-stdout &
else
    echo "**************************************************************"
    echo "⚠️  WARNING: SageAttention not available - using standard mode"
    echo "🐌 This will result in slower video generation performance"
    echo ""
    echo "💡 To fix this issue:"
    echo "   • Deploy using another GPU (Recommended: H100/H200/5090/PRO 6000)"
    echo "   • Make sure you select CUDA version 12.8 or 12.9"
    echo "   • Check the additional filters tab before deploying"
    echo "**************************************************************"
    python -u /comfyui/main.py --disable-auto-launch --disable-metadata ---disable-lowvram -listen --verbose "${COMFY_LOG_LEVEL}" --log-stdout &
fi

SERVE_API_LOCALLY="${SERVE_API_LOCALLY:-false}"

# Serve the API and don't shutdown the container
if [ "$SERVE_API_LOCALLY" == "true" ]; then
    echo "worker-comfyui: Starting RunPod Handler"
    python -u /handler.py --rp_serve_api --rp_api_host=0.0.0.0
else
    echo "worker-comfyui: Starting RunPod Handler"
    python -u /handler.py
fi

