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

# ==================== Always use Conda for clean environment ====================
# System Python has version conflicts, so we always use Conda for isolation
log_info "Using Miniconda for clean, isolated environment..."
USE_CONDA=true
log_info "This will take approximately 15-20 minutes."

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

    # Use conda-forge channel (no ToS required)
    log_info "Configuring conda-forge channel..."
    conda config --add channels conda-forge
    conda config --set channel_priority strict

    # Create conda environment
    if ! conda env list | grep -q "^${CONDA_ENV} "; then
        log_info "Creating conda environment '$CONDA_ENV' with Python 3.10..."
        conda create -n "$CONDA_ENV" python=3.10 -y -q -c conda-forge
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

# Use --ignore-installed to avoid conflicts with distutils-installed packages
PIP_OPTS="--ignore-installed"

# Core dependencies
log_info "  [1/8] Installing core dependencies (lightning, scipy, numpy, etc.)..."
$PIP_CMD install $PIP_OPTS \
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
log_info "  [2/8] Installing mesh processing (open3d, plyfile, einops)..."
$PIP_CMD install $PIP_OPTS \
    plyfile \
    einops \
    open3d

# Install pymeshlab (may require special handling)
log_info "  [3/8] Installing pymeshlab..."
$PIP_CMD install $PIP_OPTS pymeshlab || log_warning "pymeshlab installation failed, some features may not work"

# Install torch-scatter (for PyTorch 2.4.0 + CUDA 12.4)
log_info "  [4/8] Installing torch-scatter..."
$PIP_CMD install torch-scatter -f https://data.pyg.org/whl/torch-2.4.0+cu124.html || \
    log_warning "torch-scatter installation failed"

# Optional visualization dependencies
log_info "  [5/8] Installing visualization (vtk, polyscope)..."
$PIP_CMD install $PIP_OPTS vtk polyscope potpourri3d || log_warning "Some visualization packages failed to install"

# Install libigl
log_info "  [6/8] Installing libigl..."
$PIP_CMD install $PIP_OPTS libigl || log_warning "libigl installation failed"

# Install mesh2sdf and tetgen (optional, for remeshing)
log_info "  [7/8] Installing mesh2sdf, tetgen..."
$PIP_CMD install $PIP_OPTS mesh2sdf tetgen || log_warning "mesh2sdf/tetgen installation failed, remeshing may not work"

# ==================== Install Gradio ====================
log_info "  [8/8] Installing Gradio..."
$PIP_CMD install $PIP_OPTS "gradio>=4.0.0"

log_success "All Python dependencies installed."

# ==================== Download Model Checkpoint ====================
log_info "Downloading PartField model from HuggingFace..."
mkdir -p "$MODEL_DIR"

# Use huggingface_hub to download
$PIP_CMD install -q $PIP_OPTS huggingface_hub

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
echo "conda" > "$MARKER_FILE"
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
log_info "Mode: Conda environment (isolated)"
echo ""
log_info "To start the Gradio server, run:"
echo "    bash $PARTFIELD_DIR/runpod/start.sh"
echo ""
log_info "Access the web interface at:"
echo "    https://<pod-id>-7860.proxy.runpod.net"
echo ""
