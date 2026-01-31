#!/bin/bash
# PartField RunPod Installation Script
# One-time setup: creates minimal conda env, pip installs dependencies, downloads model
# Estimated time: 5-8 minutes on first run
# Subsequent runs: skipped (idempotent via marker file)

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

WORKSPACE="/workspace"
REPO_DIR="${WORKSPACE}/partfield"
CONDA_ENV="partfield"
CONDA_ENV_PATH="${WORKSPACE}/miniconda3/envs/${CONDA_ENV}"
MARKER_FILE="${WORKSPACE}/.partfield_v3_installed"
VERSION="3.0"

# Model configuration
MODEL_REPO="mikaelaangel/partfield-ckpt"
MODEL_FILE="model_objaverse.ckpt"
MODEL_DIR="${REPO_DIR}/model"

# ============================================================================
# Logging Functions
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

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
    git clone https://github.com/Salourh/PartField.git partfield
    log_success "Repository cloned successfully"
fi

cd "${REPO_DIR}"

# ============================================================================
# Phase 2: Create Minimal Conda Environment
# ============================================================================

log_phase "PHASE 2: Creating Conda Environment (Python 3.10)"

source /opt/conda/etc/profile.d/conda.sh
conda config --set always_yes true

if [ -d "${CONDA_ENV_PATH}" ]; then
    log_warning "Conda environment already exists, removing..."
    conda env remove -p "${CONDA_ENV_PATH}" --yes
fi

log_info "Creating clean Python 3.10 environment..."
conda create --yes -p "${CONDA_ENV_PATH}" python=3.10

log_success "Conda environment created"

conda activate "${CONDA_ENV_PATH}"
log_info "Python: $(python3 --version) at $(which python3)"

# ============================================================================
# Phase 3: Install PyTorch 2.4.0 + CUDA 12.4
# ============================================================================

log_phase "PHASE 3: Installing PyTorch 2.4.0 with CUDA 12.4"

log_info "Installing PyTorch from cu124 wheel index..."

pip install --no-cache-dir \
    torch==2.4.0 \
    torchvision==0.19.0 \
    torchaudio==2.4.0 \
    --index-url https://download.pytorch.org/whl/cu124

log_success "PyTorch 2.4.0+cu124 installed"

python3 -c "import torch; print(f'PyTorch {torch.__version__}, CUDA available: {torch.cuda.is_available()}')"

# ============================================================================
# Phase 4: Install PartField Dependencies (from README)
# ============================================================================

log_phase "PHASE 4: Installing PartField Dependencies"

log_info "Installing core ML packages..."
pip install --no-cache-dir \
    lightning==2.2.0 \
    h5py \
    yacs \
    trimesh \
    scikit-image \
    loguru \
    boto3 \
    psutil

log_info "Installing 3D processing packages..."
pip install --no-cache-dir \
    mesh2sdf \
    tetgen \
    pymeshlab \
    plyfile \
    einops \
    libigl \
    polyscope \
    potpourri3d \
    simple_parsing \
    arrgh \
    open3d

log_info "Installing torch-scatter from PyG wheels..."
pip install --no-cache-dir \
    torch-scatter -f https://data.pyg.org/whl/torch-2.4.0+cu124.html

log_info "Installing visualization and web packages..."
pip install --no-cache-dir \
    vtk \
    gradio \
    huggingface_hub

log_success "All dependencies installed"

# ============================================================================
# Phase 5: Download Model Checkpoint
# ============================================================================

log_phase "PHASE 5: Downloading Model Checkpoint from HuggingFace"

log_info "Model repository: ${MODEL_REPO}"
log_info "Destination: ${MODEL_DIR}/${MODEL_FILE}"

mkdir -p "${MODEL_DIR}"

if [ -f "${MODEL_DIR}/${MODEL_FILE}" ]; then
    log_warning "Model file already exists, skipping download"
else
    log_info "Downloading model..."

    python3 << PYTHON_DOWNLOAD
from huggingface_hub import hf_hub_download

try:
    model_path = hf_hub_download(
        repo_id="${MODEL_REPO}",
        filename="${MODEL_FILE}",
        local_dir="${MODEL_DIR}",
        local_dir_use_symlinks=False
    )
    print(f"Model downloaded to: {model_path}")
except Exception as e:
    print(f"Error: {e}")
    print("Trying wget fallback...")
    import subprocess, sys
    result = subprocess.run([
        "wget", "-O", "${MODEL_DIR}/${MODEL_FILE}",
        "https://huggingface.co/${MODEL_REPO}/resolve/main/${MODEL_FILE}"
    ])
    if result.returncode != 0:
        sys.exit(1)
PYTHON_DOWNLOAD
fi

if [ -f "${MODEL_DIR}/${MODEL_FILE}" ]; then
    MODEL_SIZE=$(du -h "${MODEL_DIR}/${MODEL_FILE}" | cut -f1)
    log_success "Model checkpoint ready (${MODEL_SIZE})"
else
    log_error "Model checkpoint not found at ${MODEL_DIR}/${MODEL_FILE}"
    exit 1
fi

# ============================================================================
# Phase 6: Verification
# ============================================================================

log_phase "PHASE 6: Verifying Installation"

log_info "Testing critical imports..."

python3 << 'PYTHON_VERIFY'
import sys

packages = {}

import torch
packages["PyTorch"] = torch.__version__

import torch_scatter
packages["torch-scatter"] = torch_scatter.__version__

import lightning
packages["Lightning"] = lightning.__version__

import gradio
packages["Gradio"] = gradio.__version__

import trimesh
packages["trimesh"] = trimesh.__version__

import open3d
packages["Open3D"] = open3d.__version__

for name, version in packages.items():
    print(f"  {name}: {version}")

if torch.cuda.is_available():
    print(f"  GPU: {torch.cuda.get_device_name(0)}")
    print(f"  CUDA: {torch.version.cuda}")
    mem_gb = torch.cuda.get_device_properties(0).total_memory / 1e9
    print(f"  VRAM: {mem_gb:.1f} GB")
else:
    print("  GPU not detected (normal during Docker build)")

print("\nAll imports OK!")
PYTHON_VERIFY

log_success "Verification complete"

# ============================================================================
# Create Marker File
# ============================================================================

echo "PartField RunPod Template v${VERSION}" > "${MARKER_FILE}"
echo "Installed: $(date)" >> "${MARKER_FILE}"
echo "Conda env: ${CONDA_ENV_PATH}" >> "${MARKER_FILE}"
echo "Model: ${MODEL_DIR}/${MODEL_FILE}" >> "${MARKER_FILE}"

# ============================================================================
# Done
# ============================================================================

log_phase "Installation Complete!"

log_success "PartField is ready to use!"
echo ""
echo "  Conda env: ${CONDA_ENV_PATH}"
echo "  Repository: ${REPO_DIR}"
echo "  Model: ${MODEL_DIR}/${MODEL_FILE}"
echo ""
echo "  Next: bash /opt/partfield/start.sh"
echo ""
