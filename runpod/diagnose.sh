#!/bin/bash
# PartField RunPod Diagnostic Script
# Run this if you encounter issues to get detailed diagnostic information
# Usage: bash /opt/partfield/diagnose.sh

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[FAIL]${NC} $1"; }
log_section() { echo ""; echo -e "${GREEN}=== $1 ===${NC}"; }

WORKSPACE="/workspace"
REPO_DIR="${WORKSPACE}/partfield"
CONDA_ENV="partfield"
CONDA_ENV_PATH="${WORKSPACE}/miniconda3/envs/${CONDA_ENV}"
MARKER_FILE="${WORKSPACE}/.partfield_v3_installed"

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}PartField RunPod Diagnostics${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""

# System Information
log_section "System Information"
echo "Date: $(date)"
echo "Hostname: $(hostname)"
echo "User: $(whoami)"
echo "Working directory: $(pwd)"
echo "Disk usage:"
df -h / /workspace 2>&1 | grep -E "(Filesystem|/)"

# GPU Check
log_section "GPU Information"
if command -v nvidia-smi &> /dev/null; then
    GPU_INFO=$(nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader 2>&1)
    if [ $? -eq 0 ]; then
        echo "${GPU_INFO}"
    else
        log_error "nvidia-smi query failed"
    fi
else
    log_error "nvidia-smi not found"
fi

# Installation Status
log_section "Installation Status"
if [ -f "${MARKER_FILE}" ]; then
    log_success "Installation marker file found"
    cat "${MARKER_FILE}"
else
    log_error "Installation marker NOT found at ${MARKER_FILE}"
    echo "Installation has not completed successfully"
fi

# Repository Check
log_section "Repository Check"
if [ -d "${REPO_DIR}" ]; then
    log_success "Repository directory exists: ${REPO_DIR}"
    echo "Files in repository:"
    ls -lh "${REPO_DIR}" | head -20

    # Check critical files
    for file in gradio_app.py configs/final/demo.yaml partfield/__init__.py; do
        if [ -f "${REPO_DIR}/${file}" ]; then
            log_success "Found: ${file}"
        else
            log_error "Missing: ${file}"
        fi
    done
else
    log_error "Repository directory NOT found: ${REPO_DIR}"
fi

# Model Checkpoint
log_section "Model Checkpoint"
MODEL_PATH="${REPO_DIR}/model/model_objaverse.ckpt"
if [ -f "${MODEL_PATH}" ]; then
    MODEL_SIZE=$(du -h "${MODEL_PATH}" | cut -f1)
    MODEL_SIZE_BYTES=$(stat -c%s "${MODEL_PATH}" 2>/dev/null || stat -f%z "${MODEL_PATH}" 2>/dev/null)
    MODEL_SIZE_MB=$((MODEL_SIZE_BYTES / 1024 / 1024))

    if [ ${MODEL_SIZE_MB} -gt 200 ]; then
        log_success "Model checkpoint found: ${MODEL_SIZE} (${MODEL_SIZE_MB} MB)"
    else
        log_warning "Model file exists but is small: ${MODEL_SIZE} (${MODEL_SIZE_MB} MB) - expected ~300MB"
    fi
else
    log_error "Model checkpoint NOT found: ${MODEL_PATH}"
fi

# Conda Check
log_section "Conda Environment"
if [ -f "/opt/conda/etc/profile.d/conda.sh" ]; then
    log_success "Conda installation found"
    source /opt/conda/etc/profile.d/conda.sh

    echo "Conda version: $(conda --version 2>&1)"

    if [ -d "${CONDA_ENV_PATH}" ]; then
        log_success "Conda environment exists: ${CONDA_ENV_PATH}"
        echo "Environment size: $(du -sh ${CONDA_ENV_PATH} 2>&1 | cut -f1)"

        # Try to activate
        if conda activate "${CONDA_ENV_PATH}" 2>&1; then
            log_success "Conda environment activated"
            echo "Python: $(which python3)"
            echo "Python version: $(python3 --version 2>&1)"
        else
            log_error "Failed to activate conda environment"
        fi
    else
        log_error "Conda environment NOT found: ${CONDA_ENV_PATH}"
        echo "Available environments in ${WORKSPACE}/miniconda3/envs/:"
        ls -la "${WORKSPACE}/miniconda3/envs/" 2>&1 || echo "Directory not found"
    fi
else
    log_error "Conda NOT found at /opt/conda"
fi

# Python Package Check
log_section "Python Packages"
if [ -f "/opt/conda/etc/profile.d/conda.sh" ]; then
    source /opt/conda/etc/profile.d/conda.sh

    if conda activate "${CONDA_ENV_PATH}" 2>/dev/null; then
        echo "Testing critical package imports..."

        python3 << 'PYTHON_CHECK'
import sys

packages_to_check = [
    ("torch", "PyTorch"),
    ("torch_scatter", "torch-scatter"),
    ("lightning", "Lightning"),
    ("gradio", "Gradio"),
    ("trimesh", "trimesh"),
    ("open3d", "Open3D"),
    ("h5py", "h5py"),
    ("yacs", "yacs"),
]

ok_count = 0
fail_count = 0

for module, name in packages_to_check:
    try:
        mod = __import__(module)
        version = getattr(mod, '__version__', 'unknown')
        print(f"  ✓ {name}: {version}")
        ok_count += 1
    except ImportError as e:
        print(f"  ✗ {name}: FAILED - {e}")
        fail_count += 1

print(f"\nResult: {ok_count} OK, {fail_count} FAILED")

# GPU check
try:
    import torch
    if torch.cuda.is_available():
        print(f"\n✓ GPU detected in PyTorch: {torch.cuda.get_device_name(0)}")
        print(f"  CUDA version: {torch.version.cuda}")
    else:
        print("\n✗ No GPU detected in PyTorch")
except:
    pass
PYTHON_CHECK
    else
        log_error "Cannot activate conda environment for package check"
    fi
else
    log_error "Cannot check packages - conda not available"
fi

# Network Check
log_section "Network Connectivity"
echo "Testing network connectivity..."

if ping -c 1 8.8.8.8 &> /dev/null; then
    log_success "Internet connectivity OK"
else
    log_warning "Cannot ping 8.8.8.8 (may be firewall)"
fi

if curl -s --max-time 5 https://huggingface.co &> /dev/null; then
    log_success "Can reach HuggingFace"
else
    log_error "Cannot reach HuggingFace (needed for model download)"
fi

if curl -s --max-time 5 https://download.pytorch.org &> /dev/null; then
    log_success "Can reach PyTorch downloads"
else
    log_warning "Cannot reach PyTorch download site"
fi

# Port Check
log_section "Port Check"
if netstat -tuln 2>/dev/null | grep -q ":7860 "; then
    log_success "Port 7860 is in use (Gradio may be running)"
else
    log_info "Port 7860 is not in use"
fi

# Process Check
log_section "Running Processes"
if ps aux | grep -v grep | grep -q "gradio_app.py"; then
    log_success "Gradio process is running"
    ps aux | grep -v grep | grep "gradio_app.py"
else
    log_info "Gradio is not running"
fi

# Summary
log_section "Summary"
echo ""
echo "Diagnostic complete. Review the output above for issues."
echo ""
echo "Common issues:"
echo "  • No installation marker → Run: bash /opt/partfield/install.sh"
echo "  • Missing model file → Re-run installation or download manually"
echo "  • Conda environment missing → Re-run installation"
echo "  • Import failures → Check conda environment or re-run installation"
echo "  • No GPU detected → Check RunPod GPU assignment"
echo ""
echo "For help, see: /workspace/partfield/runpod/README_RUNPOD.md"
echo ""
