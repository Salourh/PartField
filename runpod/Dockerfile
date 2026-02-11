# RunPod Template for PartField - 3D Part Segmentation
# Base: NVIDIA PyTorch NGC 24.05 (PyTorch 2.4.0a0 + CUDA 12.4 + cuDNN pre-installed)
# Requires NVIDIA Driver 550.54.14+ (compatible with RunPod's 550.127.x drivers)
# Optimized for NVIDIA L4 GPU (24GB VRAM)

FROM nvcr.io/nvidia/pytorch:24.05-py3

# Metadata
LABEL maintainer="PartField Team"
LABEL description="RunPod template for PartField 3D part segmentation with Gradio interface"
LABEL version="4.0"
LABEL gpu.recommended="NVIDIA L4 (24GB VRAM)"

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV GRADIO_SERVER_PORT=7860
ENV GRADIO_SERVER_NAME=0.0.0.0

# Install system dependencies (required for OpenGL, X11)
# These need to be in Docker because they require root and don't persist on RunPod
RUN apt-get update && apt-get install -y --no-install-recommends \
    libx11-6 \
    libgl1 \
    libxrender1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxcb1 \
    wget \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy scripts to /opt/partfield/ (NOT /workspace/ which gets overwritten by RunPod volume mount)
RUN mkdir -p /opt/partfield
COPY runpod/install.sh /opt/partfield/install.sh
COPY runpod/start.sh /opt/partfield/start.sh
COPY runpod/diagnose.sh /opt/partfield/diagnose.sh
RUN chmod +x /opt/partfield/install.sh && \
    chmod +x /opt/partfield/start.sh && \
    chmod +x /opt/partfield/diagnose.sh

# Expose Gradio port
EXPOSE 7860

# Set working directory
WORKDIR /workspace

# Default command: run startup script from /opt/partfield/ (persists across volume mounts)
CMD ["/opt/partfield/start.sh"]
