#!/bin/bash
# PartField RunPod Startup Script
# Quick restart: activates environment and launches Gradio
# Estimated time: ~10 seconds
# Note: This script is run on every pod start

# No set -e: we handle errors manually to guarantee sleep infinity on failure

# ============================================================================
# Configuration
# ============================================================================

WORKSPACE="/workspace"
REPO_DIR="${WORKSPACE}/partfield"
MARKER_FILE="${WORKSPACE}/.partfield_v4_installed"
JOBS_DIR="${WORKSPACE}/jobs"

# ============================================================================
# Logging Functions
# ============================================================================

# Colors for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    echo -e "${NC}[DEBUG]${NC} $1"
}

log_step() {
    echo -e "${GREEN}▶${NC} $1"
}

# Trap: if the script exits for ANY reason, keep the container alive
trap 'echo ""; log_error "Script exited unexpectedly. Container staying alive for debugging."; log_info "Connect via Web Terminal to inspect logs."; sleep infinity' EXIT

# ============================================================================
# Check Installation
# ============================================================================

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}PartField RunPod - Starting Up${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

if [ ! -f "${MARKER_FILE}" ]; then
    log_warning "PartField is not installed yet. Running installation..."
    echo ""
    echo "This will:"
    echo "  • Clone the repository"
    echo "  • Install pip dependencies"
    echo "  • Download model checkpoint (~300MB)"
    echo "  • Verify installation"
    echo ""
    echo "Installation takes ~5-8 minutes on first run."
    echo ""

    # Run installation automatically (don't exit on failure)
    bash /opt/partfield/install.sh || true

    # Check if installation succeeded
    if [ ! -f "${MARKER_FILE}" ]; then
        log_error "Installation failed! Container will stay alive for debugging."
        echo "You can connect via Web Terminal and run: bash /opt/partfield/install.sh"
        echo ""
        sleep infinity
    fi
fi

log_success "Installation verified (marker file found)"
log_info "Installed: $(head -n 2 ${MARKER_FILE} | tail -n 1)"

# ============================================================================
# Reinstall System Libraries
# ============================================================================

log_step "Reinstalling system libraries (RunPod doesn't persist /usr/lib)..."

# Update package lists (uses cache, fast)
apt-get update > /dev/null 2>&1 || log_warning "apt-get update failed (non-critical)"

# Reinstall OpenGL and X11 libraries
APT_OUTPUT=$(apt-get install -y --no-install-recommends \
    libx11-6 \
    libgl1 \
    libxrender1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxcb1 2>&1)

if [ $? -ne 0 ]; then
    log_warning "Some system libraries failed to install (may already exist)"
    log_debug "apt-get output: ${APT_OUTPUT}"
fi

log_success "System libraries reinstalled"

# ============================================================================
# GPU Verification
# ============================================================================

log_step "Checking GPU availability..."

python3 << 'PYTHON_GPU_CHECK'
import torch
import sys

if torch.cuda.is_available():
    gpu_name = torch.cuda.get_device_name(0)
    gpu_memory = torch.cuda.get_device_properties(0).total_memory / 1e9
    print(f"\033[0;32m✓ GPU detected: {gpu_name}\033[0m")
    print(f"\033[0;32m✓ GPU memory: {gpu_memory:.1f} GB\033[0m")

    # Check if it's an L4 (recommended GPU)
    if "L4" in gpu_name:
        print("\033[0;32m✓ Running on recommended NVIDIA L4 GPU\033[0m")
    elif gpu_memory < 20:
        print(f"\033[1;33m⚠ WARNING: GPU has only {gpu_memory:.1f} GB VRAM\033[0m")
        print("\033[1;33m  Recommended: 24GB+ (NVIDIA L4, A5000, or similar)\033[0m")
        print("\033[1;33m  You may encounter OOM errors on complex meshes\033[0m")
else:
    print("\033[0;31m✗ No GPU detected!\033[0m")
    print("\033[1;33m⚠ WARNING: PartField requires a GPU for inference\033[0m")
    print("\033[1;33m  The application may not work correctly without a GPU\033[0m")
    sys.exit(0)  # Don't fail, just warn
PYTHON_GPU_CHECK

# ============================================================================
# Prepare Jobs Directory
# ============================================================================

log_step "Preparing jobs directory..."

# Create jobs directory for Gradio temporary files
mkdir -p "${JOBS_DIR}"

log_info "Jobs directory: ${JOBS_DIR}"

# ============================================================================
# Launch Gradio Application
# ============================================================================

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Launching Gradio Application${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

log_info "Starting Gradio on port 7860..."
log_info "This may take a few seconds to initialize..."

# Verify repository directory
log_debug "Checking repository directory: ${REPO_DIR}"
if [ ! -d "${REPO_DIR}" ]; then
    log_error "Repository directory not found: ${REPO_DIR}"
    log_info "Installation may have failed. Run: bash /opt/partfield/install.sh"
    sleep infinity
fi

# Change to repository directory
cd "${REPO_DIR}" || {
    log_error "Cannot access repository directory: ${REPO_DIR}"
    sleep infinity
}
log_debug "Working directory: $(pwd)"

# Verify gradio_app.py exists
if [ ! -f "gradio_app.py" ]; then
    log_error "gradio_app.py not found in ${REPO_DIR}"
    log_debug "Directory contents:"
    ls -la
    sleep infinity
fi

# Verify model checkpoint exists
MODEL_PATH="model/model_objaverse.ckpt"
log_debug "Checking model checkpoint: ${MODEL_PATH}"
if [ ! -f "${MODEL_PATH}" ]; then
    log_error "Model checkpoint not found: ${MODEL_PATH}"
    log_info "Model download may have failed during installation."
    log_info "Try re-running installation: bash /opt/partfield/install.sh"
    sleep infinity
fi
MODEL_SIZE=$(du -h "${MODEL_PATH}" | cut -f1)
log_debug "Model checkpoint found (${MODEL_SIZE})"

# Verify config file exists
CONFIG_PATH="configs/final/demo.yaml"
log_debug "Checking config file: ${CONFIG_PATH}"
if [ ! -f "${CONFIG_PATH}" ]; then
    log_error "Config file not found: ${CONFIG_PATH}"
    sleep infinity
fi

# Quick import test
log_debug "Testing critical imports..."
python3 << 'PYTHON_TEST'
import sys
try:
    import torch
    import gradio
    import lightning
    print("[SUCCESS] Critical imports OK")
    if torch.cuda.is_available():
        print(f"[INFO] GPU: {torch.cuda.get_device_name(0)}")
    else:
        print("[WARNING] No GPU detected")
except ImportError as e:
    print(f"[ERROR] Import failed: {e}")
    sys.exit(1)
PYTHON_TEST

if [ $? -ne 0 ]; then
    log_error "Import test failed. Environment may be corrupted."
    log_info "Try re-running installation: bash /opt/partfield/install.sh"
    sleep infinity
fi

log_success "Pre-flight checks passed"
echo ""

# Launch Gradio (without exec so the shell survives if it crashes)
# --jobs-dir specifies where to store temporary job files
log_info "Launching Gradio application..."
log_debug "Command: python3 gradio_app.py --port 7860 --jobs-dir ${JOBS_DIR}"
echo ""

python3 gradio_app.py \
    --port 7860 \
    --jobs-dir "${JOBS_DIR}"

EXIT_CODE=$?

# If Gradio exits/crashes, keep container alive for debugging
echo ""
log_error "Gradio exited with code ${EXIT_CODE}"
log_warning "Container will stay alive for debugging."
log_info "Connect via Web Terminal and check the error above."
log_info "To restart manually: bash /opt/partfield/start.sh"
log_debug "Check logs above for the specific error that caused Gradio to exit"
echo ""
sleep infinity
