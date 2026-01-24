#!/bin/bash
# PartField RunPod Installation Script
# One-time setup: installs conda environment, downloads model, configures workspace
# Estimated time: 10-15 minutes on first run
# Subsequent runs: skipped (idempotent via marker file)

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

WORKSPACE="/workspace"
REPO_DIR="${WORKSPACE}/partfield"
CONDA_ENV="partfield"
MARKER_FILE="${WORKSPACE}/.partfield_v2_installed"
VERSION="2.0"

# Model configuration
MODEL_REPO="mikaelaangel/partfield-ckpt"
MODEL_FILE="model_objaverse.ckpt"
MODEL_DIR="${REPO_DIR}/model"

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

log_phase() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
}

# ============================================================================
# Check if Already Installed
# ============================================================================

if [ -f "${MARKER_FILE}" ]; then
    log_success "PartField is already installed (marker file found)"
    log_info "Installed version: $(cat ${MARKER_FILE})"
    log_info "To reinstall, delete: ${MARKER_FILE}"
    exit 0
fi

# ============================================================================
# Phase 1: Clone Repository
# ============================================================================

log_phase "PHASE 1: Cloning PartField Repository"

if [ -d "${REPO_DIR}" ]; then
    log_warning "Repository directory already exists at ${REPO_DIR}"
    log_info "Using existing repository"
else
    log_info "Cloning repository to ${REPO_DIR}..."
    cd "${WORKSPACE}"
    git clone https://github.com/3dlg-hcvc/PartField.git partfield
    log_success "Repository cloned successfully"
fi

cd "${REPO_DIR}"

# ============================================================================
# Phase 2: Modify environment.yml (Remove PyTorch Packages)
# ============================================================================

log_phase "PHASE 2: Preparing Conda Environment Configuration"

log_info "Creating modified environment.yml without PyTorch packages..."

# Use Python to modify environment.yml
python3 << 'PYTHON_SCRIPT'
import yaml
import sys

# Read original environment.yml
with open('environment.yml', 'r') as f:
    env = yaml.safe_load(f)

# Packages to remove (PyTorch-related)
pytorch_packages = [
    'pytorch', 'torch', 'torchvision', 'torchaudio',
    'pytorch-cuda', 'cudatoolkit'
]

# Filter out PyTorch packages from dependencies
if 'dependencies' in env:
    original_count = len(env['dependencies'])

    # Handle both string and dict dependencies
    filtered_deps = []
    for dep in env['dependencies']:
        if isinstance(dep, str):
            # Check if it's a PyTorch package
            pkg_name = dep.split('=')[0].split('[')[0].strip()
            if pkg_name.lower() not in [p.lower() for p in pytorch_packages]:
                filtered_deps.append(dep)
        elif isinstance(dep, dict):
            # Keep pip dependencies as-is
            filtered_deps.append(dep)

    env['dependencies'] = filtered_deps
    removed_count = original_count - len(filtered_deps)

    print(f"Removed {removed_count} PyTorch-related packages")
    print(f"Remaining dependencies: {len(filtered_deps)}")

# Write modified environment.yml
with open('environment_no_torch.yml', 'w') as f:
    yaml.dump(env, f, default_flow_style=False, sort_keys=False)

print("Created environment_no_torch.yml successfully")
PYTHON_SCRIPT

log_success "Modified environment configuration created"

# ============================================================================
# Phase 3: Create Conda Environment
# ============================================================================

log_phase "PHASE 3: Creating Conda Environment (This may take 10-12 minutes)"

# Source conda
source /opt/conda/etc/profile.d/conda.sh

log_info "Creating conda environment from environment_no_torch.yml..."
log_info "This will install ~680 packages, please be patient..."

conda env create -f environment_no_torch.yml -p ${WORKSPACE}/miniconda3/envs/${CONDA_ENV}

log_success "Conda environment created successfully"

# Activate the environment
conda activate ${WORKSPACE}/miniconda3/envs/${CONDA_ENV}

# ============================================================================
# Phase 4: Install Additional Pip Packages
# ============================================================================

log_phase "PHASE 4: Installing Additional Python Packages"

log_info "Installing lightning, gradio, huggingface_hub, psutil..."

pip install --no-cache-dir \
    lightning==2.2.0 \
    gradio \
    huggingface_hub \
    psutil

log_success "Additional packages installed"

# ============================================================================
# Phase 5: Install PyTorch (CRITICAL: Install LAST to avoid conflicts)
# ============================================================================

log_phase "PHASE 5: Installing PyTorch 2.4.0 with CUDA 12.4"

log_info "Installing PyTorch from cu124 wheel index..."
log_info "This ensures compatibility with NVIDIA L4 GPU and CUDA 12.4"

pip install --force-reinstall \
    torch==2.4.0 \
    torchvision==0.19.0 \
    torchaudio==2.4.0 \
    --index-url https://download.pytorch.org/whl/cu124

log_success "PyTorch 2.4.0+cu124 installed"

# Verify PyTorch installation
python3 -c "import torch; print(f'PyTorch version: {torch.__version__}')"
python3 -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}')"

# ============================================================================
# Phase 6: Install torch-scatter
# ============================================================================

log_phase "PHASE 6: Installing torch-scatter"

log_info "Installing torch-scatter from PyG wheels..."

pip install torch-scatter -f https://data.pyg.org/whl/torch-2.4.0+cu124.html

log_success "torch-scatter installed"

# ============================================================================
# Phase 7: Download Model Checkpoint
# ============================================================================

log_phase "PHASE 7: Downloading Model Checkpoint from HuggingFace"

log_info "Model repository: ${MODEL_REPO}"
log_info "Model file: ${MODEL_FILE}"
log_info "Destination: ${MODEL_DIR}/${MODEL_FILE}"

# Create model directory
mkdir -p "${MODEL_DIR}"

# Download using HuggingFace Hub
log_info "Downloading model (this may take a few minutes)..."

python3 << PYTHON_DOWNLOAD
from huggingface_hub import hf_hub_download
import os

try:
    model_path = hf_hub_download(
        repo_id="${MODEL_REPO}",
        filename="${MODEL_FILE}",
        local_dir="${MODEL_DIR}",
        local_dir_use_symlinks=False
    )
    print(f"Model downloaded to: {model_path}")
except Exception as e:
    print(f"Error downloading model: {e}")
    print("\nFallback: You can manually download the model using:")
    print(f"  wget -O ${MODEL_DIR}/${MODEL_FILE} https://huggingface.co/${MODEL_REPO}/resolve/main/${MODEL_FILE}")
    raise
PYTHON_DOWNLOAD

# Verify model file exists
if [ -f "${MODEL_DIR}/${MODEL_FILE}" ]; then
    MODEL_SIZE=$(du -h "${MODEL_DIR}/${MODEL_FILE}" | cut -f1)
    log_success "Model checkpoint downloaded successfully (${MODEL_SIZE})"
else
    log_error "Model checkpoint not found at ${MODEL_DIR}/${MODEL_FILE}"
    exit 1
fi

# ============================================================================
# Phase 8: Verification
# ============================================================================

log_phase "PHASE 8: Verifying Installation"

log_info "Testing critical imports..."

python3 << 'PYTHON_VERIFY'
import sys
import torch
import torch_scatter
import lightning
import gradio

print("✓ PyTorch:", torch.__version__)
print("✓ torch-scatter:", torch_scatter.__version__)
print("✓ Lightning:", lightning.__version__)
print("✓ Gradio:", gradio.__version__)

# Check GPU
if torch.cuda.is_available():
    print(f"✓ GPU: {torch.cuda.get_device_name(0)}")
    print(f"✓ CUDA version: {torch.version.cuda}")
    print(f"✓ GPU memory: {torch.cuda.get_device_properties(0).total_memory / 1e9:.1f} GB")
else:
    print("⚠ WARNING: GPU not detected (this is normal during build)")
    print("  GPU will be available when running on RunPod")

print("\nAll critical packages imported successfully!")
PYTHON_VERIFY

log_success "Installation verification complete"

# ============================================================================
# Create Marker File
# ============================================================================

log_phase "Finalizing Installation"

# Create marker file with version and timestamp
echo "PartField RunPod Template v${VERSION}" > "${MARKER_FILE}"
echo "Installed: $(date)" >> "${MARKER_FILE}"
echo "Conda environment: ${WORKSPACE}/miniconda3/envs/${CONDA_ENV}" >> "${MARKER_FILE}"
echo "Model: ${MODEL_DIR}/${MODEL_FILE}" >> "${MARKER_FILE}"

log_success "Marker file created: ${MARKER_FILE}"

# ============================================================================
# Installation Complete
# ============================================================================

log_phase "Installation Complete!"

echo ""
log_success "PartField is ready to use!"
log_info "Next steps:"
echo "  1. Run: bash /opt/partfield/start.sh"
echo "  2. Access Gradio at: http://<pod-url>:7860"
echo "  3. Upload 3D models and start segmenting!"
echo ""
log_info "Installation details:"
echo "  • Conda environment: ${WORKSPACE}/miniconda3/envs/${CONDA_ENV}"
echo "  • Repository: ${REPO_DIR}"
echo "  • Model: ${MODEL_DIR}/${MODEL_FILE}"
echo "  • Marker file: ${MARKER_FILE}"
echo ""
log_info "For help, see: ${REPO_DIR}/runpod/README_RUNPOD.md"
echo ""
