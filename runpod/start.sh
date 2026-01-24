#!/bin/bash
# PartField RunPod Startup Script
# Quick restart: activates environment and launches Gradio
# Estimated time: ~10 seconds
# Note: This script is run on every pod start

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

WORKSPACE="/workspace"
REPO_DIR="${WORKSPACE}/partfield"
CONDA_ENV="partfield"
MARKER_FILE="${WORKSPACE}/.partfield_v2_installed"
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

log_step() {
    echo -e "${GREEN}▶${NC} $1"
}

# ============================================================================
# Check Installation
# ============================================================================

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}PartField RunPod - Starting Up${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

if [ ! -f "${MARKER_FILE}" ]; then
    log_error "PartField is not installed yet!"
    echo ""
    echo "Please run the installation script first:"
    echo "  bash /opt/partfield/install.sh"
    echo ""
    echo "This will:"
    echo "  • Clone the repository"
    echo "  • Create conda environment (~680 packages)"
    echo "  • Download model checkpoint (~300MB)"
    echo "  • Verify installation"
    echo ""
    echo "Installation takes ~10-15 minutes on first run."
    echo ""
    exit 1
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
apt-get install -y --no-install-recommends \
    libx11-6 \
    libgl1 \
    libxrender1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxcb1 \
    > /dev/null 2>&1 || log_warning "Some system libraries failed to install (may already exist)"

log_success "System libraries reinstalled"

# ============================================================================
# Activate Conda Environment
# ============================================================================

log_step "Activating conda environment..."

# Source conda
source /opt/conda/etc/profile.d/conda.sh

# Activate environment from /workspace/
conda activate ${WORKSPACE}/miniconda3/envs/${CONDA_ENV}

log_success "Conda environment activated: ${CONDA_ENV}"

# Verify Python path
log_info "Python: $(which python3)"

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

# Change to repository directory
cd "${REPO_DIR}"

# Launch Gradio with exec (replaces shell process for clean shutdown)
# --share flag enables public sharing (required for RunPod proxy)
# --jobs-dir specifies where to store temporary job files
exec python3 gradio_app.py \
    --port 7860 \
    --share \
    --jobs-dir "${JOBS_DIR}"

# Note: exec replaces this shell, so nothing after this line will execute
