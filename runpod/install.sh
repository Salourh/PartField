#!/bin/bash
# PartField Installation Script for RunPod NVIDIA L4
# This script installs all dependencies in /workspace (persistent storage)
# Run once after creating a new pod, then use start.sh for subsequent restarts
#
# Supports two modes:
# 1. If PyTorch+CUDA is pre-installed (e.g., runpod/pytorch template): uses system Python
# 2. Otherwise: installs Miniconda and creates a conda environment

set -e  # Exit on error

# ==================== Configuration ====================
WORKSPACE="/workspace"
PARTFIELD_DIR="$WORKSPACE/partfield"
MINICONDA_DIR="$WORKSPACE/miniconda3"
CONDA_ENV="partfield"
MARKER_FILE="$WORKSPACE/.partfield_installed"
MODEL_DIR="$PARTFIELD_DIR/model"
USE_CONDA=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ==================== Check if already installed ====================
if [ -f "$MARKER_FILE" ]; then
    log_warning "PartField is already installed!"
    log_info "To reinstall, delete $MARKER_FILE and run this script again."
    log_info "To start the server, run: bash $PARTFIELD_DIR/runpod/start.sh"
    exit 0
fi

log_info "Starting PartField installation on RunPod..."

# ==================== Install system dependencies ====================
log_info "Installing system dependencies..."
apt-get update -qq
apt-get install -y -qq \
    wget \
    git \
    build-essential \
    libx11-6 \
    libgl1 \
    libxrender1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxcb1 \
    > /dev/null 2>&1

log_success "System dependencies installed."

# ==================== Check for existing PyTorch installation ====================
log_info "Checking for existing PyTorch installation..."

PYTORCH_OK=false
if python3 -c "import torch; assert torch.cuda.is_available()" 2>/dev/null; then
    PYTORCH_VERSION=$(python3 -c "import torch; print(torch.__version__)" 2>/dev/null)
    CUDA_VERSION=$(python3 -c "import torch; print(torch.version.cuda)" 2>/dev/null)
    log_success "Found PyTorch $PYTORCH_VERSION with CUDA $CUDA_VERSION"
    PYTORCH_OK=true
fi

if [ "$PYTORCH_OK" = true ]; then
    log_info "Using system Python (PyTorch already installed)"
    USE_CONDA=false
    PYTHON_CMD="python3"
    PIP_CMD="pip3"
else
    log_info "PyTorch not found or no CUDA support. Will install via Miniconda."
    USE_CONDA=true
    log_info "This will take approximately 15-20 minutes."
fi

# ==================== Install Miniconda (if needed) ====================
if [ "$USE_CONDA" = true ]; then
    if [ ! -d "$MINICONDA_DIR" ]; then
        log_info "Installing Miniconda to $MINICONDA_DIR..."
        cd /tmp
        wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh
        bash miniconda.sh -b -p "$MINICONDA_DIR"
        rm miniconda.sh
        log_success "Miniconda installed."
    else
        log_info "Miniconda already exists at $MINICONDA_DIR"
    fi

    # Initialize conda for this script
    export PATH="$MINICONDA_DIR/bin:$PATH"
    eval "$($MINICONDA_DIR/bin/conda shell.bash hook)"

    # Create conda environment
    if ! conda env list | grep -q "^${CONDA_ENV} "; then
        log_info "Creating conda environment '$CONDA_ENV' with Python 3.10..."
        conda create -n "$CONDA_ENV" python=3.10 -y -q
        log_success "Conda environment created."
    else
        log_info "Conda environment '$CONDA_ENV' already exists."
    fi

    # Activate environment
    conda activate "$CONDA_ENV"
    PYTHON_CMD="python"
    PIP_CMD="pip"

    # Install PyTorch
    log_info "Installing PyTorch 2.4.0 with CUDA 12.4..."
    $PIP_CMD install -q torch==2.4.0 torchvision==0.19.0 torchaudio==2.4.0 --index-url https://download.pytorch.org/whl/cu124
fi

# ==================== Clone or update PartField repository ====================
if [ ! -d "$PARTFIELD_DIR" ]; then
    log_info "Cloning PartField repository..."
    cd "$WORKSPACE"
    git clone https://github.com/Salourh/PartField.git partfield
    log_success "Repository cloned."
else
    log_info "PartField directory already exists, updating..."
    cd "$PARTFIELD_DIR"
    git pull origin main || log_warning "Could not update repository (might have local changes)"
fi

cd "$PARTFIELD_DIR"

# ==================== Install Python dependencies ====================
log_info "Installing Python dependencies..."

# Core dependencies
$PIP_CMD install -q \
    lightning==2.2 \
    h5py \
    yacs \
    trimesh \
    scikit-image \
    scikit-learn \
    loguru \
    boto3 \
    networkx \
    scipy \
    numpy

# Mesh processing dependencies
$PIP_CMD install -q \
    plyfile \
    einops \
    open3d

# Install pymeshlab (may require special handling)
$PIP_CMD install -q pymeshlab || log_warning "pymeshlab installation failed, some features may not work"

# Install torch-scatter (needs to match PyTorch version)
log_info "Installing torch-scatter..."
if [ "$USE_CONDA" = true ]; then
    $PIP_CMD install -q torch-scatter -f https://data.pyg.org/whl/torch-2.4.0+cu124.html
else
    # Detect PyTorch version for correct torch-scatter
    TORCH_VER=$($PYTHON_CMD -c "import torch; print(torch.__version__.split('+')[0])")
    CUDA_VER=$($PYTHON_CMD -c "import torch; print(torch.version.cuda.replace('.', '')[:3])")
    $PIP_CMD install -q torch-scatter -f "https://data.pyg.org/whl/torch-${TORCH_VER}+cu${CUDA_VER}.html" || \
    $PIP_CMD install -q torch-scatter || \
    log_warning "torch-scatter installation failed"
fi

# Optional visualization dependencies
$PIP_CMD install -q vtk polyscope potpourri3d || log_warning "Some visualization packages failed to install"

# Install libigl
$PIP_CMD install -q libigl || log_warning "libigl installation failed"

# Install mesh2sdf and tetgen (optional, for remeshing)
$PIP_CMD install -q mesh2sdf tetgen || log_warning "mesh2sdf/tetgen installation failed, remeshing may not work"

# ==================== Install Gradio ====================
log_info "Installing Gradio for web interface..."
$PIP_CMD install -q "gradio>=4.0.0"

log_success "All Python dependencies installed."

# ==================== Download Model Checkpoint ====================
log_info "Downloading PartField model from HuggingFace..."
mkdir -p "$MODEL_DIR"

# Use huggingface_hub to download
$PIP_CMD install -q huggingface_hub

$PYTHON_CMD << 'EOF'
from huggingface_hub import hf_hub_download
import os

model_dir = os.environ.get('MODEL_DIR', '/workspace/partfield/model')
print(f"Downloading model to {model_dir}...")

try:
    # Download the main model checkpoint
    hf_hub_download(
        repo_id="TencentARC/PartField",
        filename="model_objaverse.ckpt",
        local_dir=model_dir,
        local_dir_use_symlinks=False
    )
    print("Model downloaded successfully!")
except Exception as e:
    print(f"Warning: Could not download model: {e}")
    print("You may need to download it manually from https://huggingface.co/TencentARC/PartField")
EOF

# ==================== Create jobs directory ====================
log_info "Creating jobs directory for Gradio uploads..."
mkdir -p "$WORKSPACE/jobs"

# ==================== Save installation mode ====================
if [ "$USE_CONDA" = true ]; then
    echo "conda" > "$MARKER_FILE"
else
    echo "system" > "$MARKER_FILE"
fi
echo "$(date)" >> "$MARKER_FILE"

# ==================== Verify installation ====================
log_info "Verifying installation..."

$PYTHON_CMD << 'EOF'
import torch
print(f"PyTorch version: {torch.__version__}")
print(f"CUDA available: {torch.cuda.is_available()}")
if torch.cuda.is_available():
    print(f"CUDA version: {torch.version.cuda}")
    print(f"GPU: {torch.cuda.get_device_name(0)}")
    print(f"GPU Memory: {torch.cuda.get_device_properties(0).total_memory / 1e9:.2f} GB")

import gradio
print(f"Gradio version: {gradio.__version__}")

import lightning
print(f"Lightning version: {lightning.__version__}")
EOF

# ==================== Final message ====================
echo ""
log_success "=========================================="
log_success "PartField installation complete!"
log_success "=========================================="
echo ""
if [ "$USE_CONDA" = true ]; then
    log_info "Mode: Conda environment"
else
    log_info "Mode: System Python (faster startup)"
fi
echo ""
log_info "To start the Gradio server, run:"
echo "    bash $PARTFIELD_DIR/runpod/start.sh"
echo ""
log_info "Access the web interface at:"
echo "    https://<pod-id>-7860.proxy.runpod.net"
echo ""
