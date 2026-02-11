# Building PartField Docker Image on RunPod

This guide walks through building and testing the PartField Docker image directly on RunPod.

## Why Build on RunPod?

- No local Docker setup required
- GPU available for testing
- Build in the actual deployment environment
- Direct push to Docker Hub from cloud

## Prerequisites

1. RunPod account with credits
2. Docker Hub account (for pushing the image)
3. Git repository access (PartField on GitHub)

## Step 1: Deploy a Build Pod

1. Go to RunPod Console → Pods → Deploy
2. Select any GPU pod (cheapest option works - we just need Docker)
   - **Recommended**: RTX A4000 or L4 (for testing GPU functionality)
   - **Budget**: Any NVIDIA GPU pod
3. Use a template with Docker pre-installed:
   - **Option A**: "RunPod Pytorch" (has Docker + GPU drivers)
   - **Option B**: "RunPod Ubuntu" (has Docker)
4. Set volume size: 30GB minimum (for Docker build cache + testing)
5. Deploy the pod

## Step 2: Connect to Pod

1. Wait for pod to start (Status: Running)
2. Click "Connect" → "Start Web Terminal" or use SSH
3. You should see a terminal in your browser

## Step 3: Verify Docker is Available

In the pod terminal, run:

```bash
docker --version
nvidia-smi  # Verify GPU is detected
```

Expected output:
```
Docker version 24.x.x
```

If Docker is not installed, install it:

```bash
# Install Docker (Ubuntu/Debian)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
```

## Step 4: Clone the Repository

```bash
cd /workspace
git clone https://github.com/Salourh/PartField.git
cd PartField
```

## Step 5: Build the Docker Image

```bash
# Build the image (this will take 5-10 minutes)
docker build -t partfield-runpod:test -f runpod/Dockerfile .
```

**What happens during build:**
1. Downloads NVIDIA PyTorch NGC base image (~8GB, first time only)
2. Installs system libraries (libgl1, libx11, etc.)
3. Copies scripts (install.sh, start.sh, diagnose.sh)
4. Sets up working directory and CMD

**Expected time**: 5-10 minutes (first build), 1-2 minutes (subsequent builds with cache)

**Watch for errors**: If build fails, check the error message. Common issues:
- Network timeout downloading base image → retry
- Missing files → verify you're in PartField directory
- Permission denied → use `sudo` if needed

## Step 6: Verify Image Built Successfully

```bash
# List Docker images
docker images | grep partfield

# Should show:
# partfield-runpod   test   <image-id>   <size>   <time-ago>
```

Check image size (should be ~8-10GB):

```bash
docker images partfield-runpod:test --format "{{.Repository}}:{{.Tag}} - {{.Size}}"
```

## Step 7: Test the Image (Quick Smoke Test)

Create a test workspace:

```bash
# Create test directory
mkdir -p /workspace/test-partfield

# Run container interactively (without GPU for quick test)
docker run --rm -it \
  -v /workspace/test-partfield:/workspace \
  partfield-runpod:test \
  /bin/bash
```

Inside the container, verify:

```bash
# Check scripts are executable
ls -la /opt/partfield/

# Check Python is available
python3 --version

# Exit container
exit
```

## Step 8: Test with GPU (Full Test)

Run the container with GPU support:

```bash
# Run with GPU
docker run --gpus all -it \
  -p 7860:7860 \
  -v /workspace/test-partfield:/workspace \
  partfield-runpod:test \
  /bin/bash
```

Inside the container:

```bash
# Test GPU is accessible
nvidia-smi

# Run installation script
bash /opt/partfield/install.sh

# This will take 5-8 minutes - watch for errors
# Should complete with "Installation Complete!" message
```

**What to watch for:**
- ✓ All 5 phases complete successfully
- ✓ PyTorch installed with CUDA support
- ✓ All pip dependencies installed
- ✓ Model downloaded (~300MB)
- ✓ GPU detected in verification phase
- ✓ Marker file created

If installation succeeds, test startup:

```bash
# Exit and restart container to test start.sh
exit

# Restart container (workspace persists)
docker run --gpus all -it \
  -p 7860:7860 \
  -v /workspace/test-partfield:/workspace \
  partfield-runpod:test \
  /bin/bash

# Run startup script
bash /opt/partfield/start.sh

# Should start Gradio in ~10 seconds
# Press Ctrl+C to stop Gradio
# Type 'exit' to exit container
```

**Success criteria:**
- ✓ Installation takes 5-8 minutes (first run)
- ✓ Restart takes ~10 seconds
- ✓ GPU detected on both runs
- ✓ Gradio starts without errors

## Step 9: Push to Docker Hub

If tests pass, push the image to Docker Hub:

```bash
# Login to Docker Hub
docker login
# Enter your Docker Hub username and password

# Tag the image for Docker Hub
docker tag partfield-runpod:test timfredfred/partfield-runpod:v4.0
docker tag partfield-runpod:test timfredfred/partfield-runpod:latest

# Push both tags (this will take 10-15 minutes for ~8-10GB image)
docker push timfredfred/partfield-runpod:v4.0
docker push timfredfred/partfield-runpod:latest
```

**Upload progress**: You'll see upload progress for each layer. The base image layers may already exist on Docker Hub, so only new layers are uploaded.

**Expected upload size**: ~1-2GB (only new layers, not the full 8GB)

## Step 10: Verify on Docker Hub

1. Go to https://hub.docker.com/r/timfredfred/partfield-runpod
2. Verify both tags are present: `v4.0` and `latest`
3. Check image size and last updated timestamp
4. Optionally add description and README

## Step 11: Clean Up Build Pod

Once the image is pushed:

```bash
# Remove test workspace
rm -rf /workspace/test-partfield

# Remove Docker images to free space (optional)
docker rmi partfield-runpod:test
docker rmi timfredfred/partfield-runpod:v4.0
docker rmi timfredfred/partfield-runpod:latest
```

Then stop/terminate the build pod from RunPod Console to avoid charges.

## Quick Command Reference

```bash
# Full build and push workflow
cd /workspace
git clone https://github.com/Salourh/PartField.git
cd PartField

# Build
docker build -t partfield-runpod:test -f runpod/Dockerfile .

# Quick test (no GPU)
docker run --rm -it partfield-runpod:test /bin/bash

# Full test (with GPU and installation)
mkdir -p /workspace/test-partfield
docker run --gpus all -it -p 7860:7860 \
  -v /workspace/test-partfield:/workspace \
  partfield-runpod:test /bin/bash
# Inside: bash /opt/partfield/install.sh

# Push to Docker Hub
docker login
docker tag partfield-runpod:test timfredfred/partfield-runpod:v4.0
docker tag partfield-runpod:test timfredfred/partfield-runpod:latest
docker push timfredfred/partfield-runpod:v4.0
docker push timfredfred/partfield-runpod:latest
```

## Troubleshooting

### Build Fails: "Cannot connect to Docker daemon"

**Solution**: Docker is not running. Install Docker:
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

### Build Fails: "No space left on device"

**Solution**: Increase volume size or clean up:
```bash
docker system prune -a  # Remove unused images/containers
```

### Test Fails: "CUDA out of memory" during installation

**Solution**: Use a GPU with more VRAM (24GB+ recommended)

### Push Fails: "denied: requested access to the resource is denied"

**Solution**: Login with correct credentials:
```bash
docker logout
docker login
# Enter correct username/password
```

### Installation Script Hangs at Model Download

**Solution**: Network issue. Ctrl+C and retry, or manually download:
```bash
cd /workspace/partfield
mkdir -p model
wget -O model/model_objaverse.ckpt \
  https://huggingface.co/mikaelaangel/partfield-ckpt/resolve/main/model_objaverse.ckpt
```

## Cost Estimate

Building on RunPod (one-time):

| Task | Time | Cost (@ $0.50/hr for L4) |
|------|------|--------------------------|
| Docker build | 10 min | $0.08 |
| Installation test | 15 min | $0.13 |
| Restart test | 5 min | $0.04 |
| Docker push | 15 min | $0.13 |
| **Total** | **45 min** | **~$0.38** |

**Note**: Using a cheaper GPU (RTX A4000 @ $0.30/hr) reduces cost to ~$0.23.

## Next Steps

After successful build and push:

1. ✓ Docker image is on Docker Hub: `timfredfred/partfield-runpod:latest`
2. → Create RunPod template (see README_RUNPOD.md)
3. → Deploy production pod using the template
4. → Test end-to-end workflow with real 3D models
5. → Update main README.md with "Run on RunPod" section
6. → Commit runpod/ directory to GitHub

---

**Ready to deploy!** 🚀

Once the image is on Docker Hub, anyone can deploy PartField on RunPod with a single click.
