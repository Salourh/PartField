#!/bin/bash
# Quick test script for PartField RunPod Docker image
# Usage: bash runpod/test-build.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()    { echo -e "${GREEN}▶${NC} $1"; }

IMAGE_NAME="partfield-runpod"
IMAGE_TAG="test-$(date +%Y%m%d-%H%M%S)"
TEST_WORKSPACE="$(pwd)/test-workspace-runpod"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}PartField RunPod - Build Test${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Verify we're in the right directory
if [ ! -f "runpod/Dockerfile" ]; then
    log_error "Must be run from PartField root directory"
    log_info "Current directory: $(pwd)"
    exit 1
fi

# ============================================================================
# Step 1: Build Docker Image
# ============================================================================

log_step "Building Docker image..."
log_info "Image: ${IMAGE_NAME}:${IMAGE_TAG}"
log_info "This will take 5-10 minutes on first build..."

if docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" -f runpod/Dockerfile .; then
    log_success "Docker image built successfully"
else
    log_error "Docker build failed"
    exit 1
fi

# Check image size
IMAGE_SIZE=$(docker images "${IMAGE_NAME}:${IMAGE_TAG}" --format "{{.Size}}")
log_info "Image size: ${IMAGE_SIZE}"

# ============================================================================
# Step 2: Test Scripts Exist
# ============================================================================

log_step "Verifying scripts in image..."

docker run --rm "${IMAGE_NAME}:${IMAGE_TAG}" /bin/bash -c "
    if [ ! -f /opt/partfield/install.sh ]; then
        echo 'ERROR: install.sh not found'
        exit 1
    fi
    if [ ! -f /opt/partfield/start.sh ]; then
        echo 'ERROR: start.sh not found'
        exit 1
    fi
    if [ ! -f /opt/partfield/diagnose.sh ]; then
        echo 'ERROR: diagnose.sh not found'
        exit 1
    fi
    echo 'All scripts present'
"

if [ $? -eq 0 ]; then
    log_success "All scripts verified"
else
    log_error "Script verification failed"
    exit 1
fi

# ============================================================================
# Step 3: Test Diagnostic Script (Quick)
# ============================================================================

log_step "Testing diagnostic script (without GPU)..."

docker run --rm "${IMAGE_NAME}:${IMAGE_TAG}" /opt/partfield/diagnose.sh 2>&1 | head -50

log_success "Diagnostic script executed (partial output shown)"

# ============================================================================
# Step 4: Test with GPU (Optional)
# ============================================================================

echo ""
log_info "To test with GPU and full installation:"
echo ""
echo "  1. Create test workspace:"
echo "     mkdir -p ${TEST_WORKSPACE}"
echo ""
echo "  2. Run with GPU:"
echo "     docker run --gpus all -it -p 7860:7860 \\"
echo "       -v ${TEST_WORKSPACE}:/workspace \\"
echo "       ${IMAGE_NAME}:${IMAGE_TAG} \\"
echo "       /bin/bash"
echo ""
echo "  3. Inside container, run installation:"
echo "     bash /opt/partfield/install.sh"
echo ""
echo "  4. Test startup:"
echo "     bash /opt/partfield/start.sh"
echo ""
echo "  5. Test diagnostic:"
echo "     bash /opt/partfield/diagnose.sh"
echo ""

# ============================================================================
# Summary
# ============================================================================

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Build Test Complete${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

log_success "Docker image built and tested successfully"
log_info "Image: ${IMAGE_NAME}:${IMAGE_TAG}"
log_info "Size: ${IMAGE_SIZE}"
echo ""

log_info "Next steps:"
echo "  1. Test with GPU (see commands above)"
echo "  2. Tag for Docker Hub:"
echo "     docker tag ${IMAGE_NAME}:${IMAGE_TAG} timfredfred/partfield-runpod:v3.0"
echo "     docker tag ${IMAGE_NAME}:${IMAGE_TAG} timfredfred/partfield-runpod:latest"
echo "  3. Push to Docker Hub:"
echo "     docker push timfredfred/partfield-runpod:v3.0"
echo "     docker push timfredfred/partfield-runpod:latest"
echo ""

log_success "All tests passed! 🎉"
