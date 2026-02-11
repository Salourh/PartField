#!/bin/bash
# PartField RunPod Installation Script
# One-time setup: pip installs dependencies, downloads model
# Estimated time: 5-8 minutes on first run
# Subsequent runs: skipped (idempotent via marker file)

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

WORKSPACE="/workspace"
REPO_DIR="${WORKSPACE}/partfield"
MARKER_FILE="${WORKSPACE}/.partfield_v4_installed"
VERSION="4.0"

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
log_debug()   { echo -e "${NC}[DEBUG]${NC} $1"; }

log_phase() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
}

# Error handler
error_exit() {
    log_error "$1"
    log_error "Installation failed. Container will stay alive for debugging."
    log_info "Check the error message above and retry with: bash /opt/partfield/install.sh"
    exit 1
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
    log_debug "Checking repository integrity..."
    if [ ! -f "${REPO_DIR}/gradio_app.py" ]; then
        log_error "Repository appears corrupted (missing gradio_app.py)"
        log_info "Removing and re-cloning..."
        rm -rf "${REPO_DIR}"
    fi
fi

if [ ! -d "${REPO_DIR}" ]; then
    log_info "Cloning repository to ${REPO_DIR}..."
    cd "${WORKSPACE}" || error_exit "Cannot access ${WORKSPACE}"

    log_debug "Running: git clone https://github.com/Salourh/PartField.git partfield"
    GIT_OUTPUT=$(git clone --quiet https://github.com/Salourh/PartField.git partfield 2>&1)
    if [ $? -ne 0 ]; then
        echo "${GIT_OUTPUT}"
        error_exit "Failed to clone repository. Check network connection."
    fi

    log_success "Repository cloned successfully"
fi

cd "${REPO_DIR}" || error_exit "Cannot access ${REPO_DIR}"
log_debug "Working directory: $(pwd)"

# Verify critical files exist
log_debug "Verifying repository files..."
for file in gradio_app.py configs/final/demo.yaml partfield/__init__.py; do
    if [ ! -f "${file}" ] && [ ! -d "${file%/*}" ]; then
        error_exit "Missing critical file/directory: ${file}"
    fi
done
log_success "Repository verification complete"

# ============================================================================
# Phase 2: Install PyTorch 2.4.0 + CUDA 12.4
# ============================================================================

log_phase "PHASE 2: Installing PyTorch 2.4.0 with CUDA 12.4"

log_info "Python: $(python3 --version) at $(which python3)"
log_debug "Pip version: $(pip --version)"

log_info "Installing PyTorch 2.4.0+cu124 (this may take 2-3 minutes)..."

log_debug "Running: pip install torch==2.4.0 torchvision==0.19.0 torchaudio==2.4.0"
PIP_OUTPUT=$(pip install --no-cache-dir --quiet \
    torch==2.4.0 \
    torchvision==0.19.0 \
    torchaudio==2.4.0 \
    --index-url https://download.pytorch.org/whl/cu124 2>&1)
if [ $? -ne 0 ]; then
    echo "${PIP_OUTPUT}"
    error_exit "Failed to install PyTorch. Check network connection and disk space."
fi

log_success "PyTorch 2.4.0+cu124 installed"

log_debug "Verifying PyTorch installation..."
python3 << 'PYTHON_CHECK'
import torch
import sys

print(f"PyTorch version: {torch.__version__}")
print(f"CUDA available: {torch.cuda.is_available()}")
print(f"CUDA version: {torch.version.cuda if torch.cuda.is_available() else 'N/A'}")

if not torch.__version__.startswith("2.4."):
    print(f"ERROR: Expected PyTorch 2.4.x but got {torch.__version__}")
    sys.exit(1)
PYTHON_CHECK

if [ $? -ne 0 ]; then
    error_exit "PyTorch verification failed"
fi

log_success "PyTorch verification complete"

# ============================================================================
# Phase 3: Install PartField Dependencies (from README)
# ============================================================================

log_phase "PHASE 3: Installing PartField Dependencies"

log_info "Installing core ML packages (lightning, scipy, sklearn, etc.)..."
PIP_OUTPUT=$(pip install --no-cache-dir --quiet \
    lightning==2.2.0 \
    h5py \
    yacs \
    trimesh \
    scikit-image \
    scikit-learn \
    scipy \
    matplotlib \
    networkx \
    loguru \
    boto3 \
    psutil 2>&1)
if [ $? -ne 0 ]; then
    echo "${PIP_OUTPUT}"
    error_exit "Failed to install core ML packages"
fi
log_success "Core ML packages installed (12 packages)"

log_info "Installing 3D processing packages (open3d, pymeshlab, trimesh, etc.)..."
PIP_OUTPUT=$(pip install --no-cache-dir --quiet \
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
    open3d 2>&1)
if [ $? -ne 0 ]; then
    echo "${PIP_OUTPUT}"
    error_exit "Failed to install 3D processing packages"
fi
log_success "3D processing packages installed (11 packages)"

log_info "Installing torch-scatter from PyG wheels..."
log_debug "Running: pip install torch-scatter -f https://data.pyg.org/whl/torch-2.4.0+cu124.html"
PIP_OUTPUT=$(pip install --no-cache-dir --quiet \
    torch-scatter -f https://data.pyg.org/whl/torch-2.4.0+cu124.html 2>&1)
if [ $? -ne 0 ]; then
    echo "${PIP_OUTPUT}"
    error_exit "Failed to install torch-scatter. This is a critical dependency."
fi
log_success "torch-scatter installed"

log_info "Installing visualization and web packages (gradio, vtk, huggingface_hub)..."
PIP_OUTPUT=$(pip install --no-cache-dir --quiet \
    vtk \
    "gradio>=4.0,<5.0" \
    huggingface_hub 2>&1)
if [ $? -ne 0 ]; then
    echo "${PIP_OUTPUT}"
    error_exit "Failed to install visualization packages"
fi
log_success "Visualization packages installed (3 packages)"

log_success "All dependencies installed successfully"

# ============================================================================
# Phase 4: Download Model Checkpoint
# ============================================================================

log_phase "PHASE 4: Downloading Model Checkpoint from HuggingFace"

log_info "Model repository: ${MODEL_REPO}"
log_info "Destination: ${MODEL_DIR}/${MODEL_FILE}"

log_debug "Creating model directory..."
mkdir -p "${MODEL_DIR}" || error_exit "Failed to create model directory at ${MODEL_DIR}"

if [ -f "${MODEL_DIR}/${MODEL_FILE}" ]; then
    MODEL_SIZE=$(du -h "${MODEL_DIR}/${MODEL_FILE}" | cut -f1)
    log_warning "Model file already exists (${MODEL_SIZE}), skipping download"
    log_debug "Existing model: ${MODEL_DIR}/${MODEL_FILE}"
else
    log_info "Downloading model checkpoint (~300MB, this may take 2-5 minutes)..."
    log_debug "Using HuggingFace Hub API with wget fallback"

    python3 << PYTHON_DOWNLOAD
import sys
import os

print("[DEBUG] Starting model download...")
print(f"[DEBUG] Repository: ${MODEL_REPO}")
print(f"[DEBUG] File: ${MODEL_FILE}")
print(f"[DEBUG] Destination: ${MODEL_DIR}")

try:
    from huggingface_hub import hf_hub_download
    print("[INFO] Using huggingface_hub for download...")

    model_path = hf_hub_download(
        repo_id="${MODEL_REPO}",
        filename="${MODEL_FILE}",
        local_dir="${MODEL_DIR}",
        local_dir_use_symlinks=False
    )
    print(f"[SUCCESS] Model downloaded to: {model_path}")

    # Verify file exists and has reasonable size
    if os.path.exists(model_path):
        size_mb = os.path.getsize(model_path) / (1024 * 1024)
        print(f"[DEBUG] Downloaded file size: {size_mb:.1f} MB")
        if size_mb < 100:
            print(f"[ERROR] Downloaded file is too small ({size_mb:.1f} MB). Expected ~300MB")
            sys.exit(1)
    else:
        print(f"[ERROR] Downloaded file not found at {model_path}")
        sys.exit(1)

except Exception as e:
    print(f"[ERROR] HuggingFace download failed: {e}")
    print("[INFO] Trying wget fallback...")

    import subprocess

    wget_url = f"https://huggingface.co/${MODEL_REPO}/resolve/main/${MODEL_FILE}"
    output_path = "${MODEL_DIR}/${MODEL_FILE}"

    print(f"[DEBUG] wget URL: {wget_url}")
    print(f"[DEBUG] Output: {output_path}")

    result = subprocess.run([
        "wget",
        "--quiet",
        "--show-progress",
        "--tries=3",
        "--timeout=60",
        "-O", output_path,
        wget_url
    ], capture_output=False)

    if result.returncode != 0:
        print(f"[ERROR] wget failed with exit code {result.returncode}")
        sys.exit(1)

    # Verify wget download
    if os.path.exists(output_path):
        size_mb = os.path.getsize(output_path) / (1024 * 1024)
        print(f"[DEBUG] Downloaded file size: {size_mb:.1f} MB")
        if size_mb < 100:
            print(f"[ERROR] Downloaded file is too small ({size_mb:.1f} MB)")
            os.remove(output_path)
            sys.exit(1)
        print(f"[SUCCESS] Model downloaded successfully via wget")
    else:
        print(f"[ERROR] wget download failed - file not found")
        sys.exit(1)
PYTHON_DOWNLOAD

    DOWNLOAD_STATUS=$?
    if [ $DOWNLOAD_STATUS -ne 0 ]; then
        error_exit "Model download failed. Check network connection and HuggingFace availability."
    fi
fi

# Final verification
if [ -f "${MODEL_DIR}/${MODEL_FILE}" ]; then
    MODEL_SIZE=$(du -h "${MODEL_DIR}/${MODEL_FILE}" | cut -f1)
    MODEL_SIZE_BYTES=$(stat -f%z "${MODEL_DIR}/${MODEL_FILE}" 2>/dev/null || stat -c%s "${MODEL_DIR}/${MODEL_FILE}" 2>/dev/null)
    MODEL_SIZE_MB=$((MODEL_SIZE_BYTES / 1024 / 1024))

    log_success "Model checkpoint ready (${MODEL_SIZE})"
    log_debug "Model file: ${MODEL_DIR}/${MODEL_FILE}"
    log_debug "Size: ${MODEL_SIZE_MB} MB"

    # Verify size is reasonable (should be ~300MB)
    if [ "${MODEL_SIZE_MB}" -lt 100 ]; then
        error_exit "Model file is too small (${MODEL_SIZE_MB} MB). Download may have failed. Expected ~300MB."
    fi
else
    error_exit "Model checkpoint not found at ${MODEL_DIR}/${MODEL_FILE}"
fi

# ============================================================================
# Phase 5: Verification
# ============================================================================

log_phase "PHASE 5: Verifying Installation"

log_info "Testing critical imports..."
log_debug "This verifies all packages are installed correctly"

python3 << 'PYTHON_VERIFY'
import sys

print("[DEBUG] Starting import verification...")
packages = {}
failed_imports = []

def try_import(module_name, display_name=None):
    """Try to import a module and track the result."""
    if display_name is None:
        display_name = module_name
    try:
        mod = __import__(module_name)
        if hasattr(mod, '__version__'):
            packages[display_name] = mod.__version__
            print(f"[SUCCESS] {display_name}: {mod.__version__}")
        else:
            packages[display_name] = "installed"
            print(f"[SUCCESS] {display_name}: installed (no version)")
        return True
    except ImportError as e:
        failed_imports.append((display_name, str(e)))
        print(f"[ERROR] Failed to import {display_name}: {e}")
        return False

# Core dependencies
print("\n[INFO] Checking core dependencies...")
try_import("torch", "PyTorch")
try_import("torch_scatter", "torch-scatter")
try_import("lightning", "Lightning")
try_import("gradio", "Gradio")

# 3D processing
print("\n[INFO] Checking 3D processing libraries...")
try_import("trimesh")
try_import("open3d", "Open3D")
try_import("mesh2sdf")
try_import("pymeshlab")

# Additional dependencies
print("\n[INFO] Checking additional dependencies...")
try_import("h5py")
try_import("yacs")
try_import("scipy")
try_import("sklearn", "scikit-learn")

# GPU check
print("\n[INFO] Checking GPU availability...")
try:
    import torch
    if torch.cuda.is_available():
        print(f"[SUCCESS] GPU detected: {torch.cuda.get_device_name(0)}")
        print(f"[INFO] CUDA version: {torch.version.cuda}")
        mem_gb = torch.cuda.get_device_properties(0).total_memory / 1e9
        print(f"[INFO] VRAM: {mem_gb:.1f} GB")
    else:
        print("[WARNING] No GPU detected (normal during Docker build)")
except Exception as e:
    print(f"[ERROR] GPU check failed: {e}")

# Summary
print("\n" + "="*50)
if failed_imports:
    print(f"[ERROR] {len(failed_imports)} package(s) failed to import:")
    for name, error in failed_imports:
        print(f"  - {name}: {error}")
    print("\nInstallation verification FAILED")
    sys.exit(1)
else:
    print(f"[SUCCESS] All {len(packages)} critical packages imported successfully")
    print("\n[SUCCESS] Installation verification PASSED")
PYTHON_VERIFY

VERIFY_STATUS=$?
if [ $VERIFY_STATUS -ne 0 ]; then
    error_exit "Package verification failed. Some dependencies are not installed correctly."
fi

log_success "Verification complete - all packages working correctly"

# ============================================================================
# Create Marker File
# ============================================================================

echo "PartField RunPod Template v${VERSION}" > "${MARKER_FILE}"
echo "Installed: $(date)" >> "${MARKER_FILE}"
echo "Model: ${MODEL_DIR}/${MODEL_FILE}" >> "${MARKER_FILE}"

# ============================================================================
# Done
# ============================================================================

log_phase "Installation Complete!"

log_success "PartField is ready to use!"
echo ""
echo "  Repository: ${REPO_DIR}"
echo "  Model: ${MODEL_DIR}/${MODEL_FILE}"
echo ""
echo "  Next: bash /opt/partfield/start.sh"
echo ""
