#!/bin/bash
# PartField Quick Start Script for RunPod
# Run this after pod restarts to quickly start the Gradio server
# System libraries must be reinstalled each time (not persistent)

set -e

# ==================== Configuration ====================
WORKSPACE="/workspace"
PARTFIELD_DIR="$WORKSPACE/partfield"
MINICONDA_DIR="$WORKSPACE/miniconda3"
CONDA_ENV="partfield"
MARKER_FILE="$WORKSPACE/.partfield_installed"
GRADIO_PORT=7860

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ==================== Check installation ====================
if [ ! -f "$MARKER_FILE" ]; then
    log_error "PartField is not installed!"
    log_info "Please run the installation script first:"
    echo "    bash $PARTFIELD_DIR/runpod/install.sh"
    exit 1
fi

# Detect installation mode (first line of marker file)
INSTALL_MODE=$(head -n 1 "$MARKER_FILE")
log_info "Starting PartField server (mode: $INSTALL_MODE)..."

# ==================== Install system libraries (non-persistent) ====================
log_info "Installing system libraries (required after each restart)..."
apt-get update -qq
apt-get install -y -qq \
    libx11-6 \
    libgl1 \
    libxrender1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxcb1 \
    > /dev/null 2>&1

log_success "System libraries installed."

# ==================== Setup Python environment ====================
if [ "$INSTALL_MODE" = "conda" ]; then
    log_info "Activating conda environment..."
    export PATH="$MINICONDA_DIR/bin:$PATH"
    eval "$($MINICONDA_DIR/bin/conda shell.bash hook)"
    conda activate "$CONDA_ENV"
    PYTHON_CMD="python"
else
    log_info "Using system Python..."
    PYTHON_CMD="python3"
fi

log_success "Python environment ready."

# ==================== Verify GPU ====================
log_info "Checking GPU availability..."
$PYTHON_CMD -c "import torch; print(f'GPU: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"Not available\"}')"

# ==================== Create jobs directory ====================
mkdir -p "$WORKSPACE/jobs"

# ==================== Start Gradio server ====================
cd "$PARTFIELD_DIR"

log_success "=========================================="
log_success "Starting Gradio server on port $GRADIO_PORT"
log_success "=========================================="
echo ""
log_info "Access the web interface at:"
echo "    https://<pod-id>-${GRADIO_PORT}.proxy.runpod.net"
echo ""
log_info "Or use Gradio's public share link (printed below)"
echo ""
log_info "Press Ctrl+C to stop the server"
echo ""

# Start Gradio app
$PYTHON_CMD gradio_app.py \
    --port $GRADIO_PORT \
    --share \
    --jobs-dir "$WORKSPACE/jobs"
