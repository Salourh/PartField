# RunPod Template for PartField - 3D Part Segmentation
# Base: NVIDIA PyTorch NGC 24.08 (PyTorch 2.4.0 + CUDA 12.4 + cuDNN pre-installed)
# Optimized for NVIDIA L4 GPU (24GB VRAM)

FROM nvcr.io/nvidia/pytorch:24.08-py3

# Metadata
LABEL maintainer="PartField Team"
LABEL description="RunPod template for PartField 3D part segmentation with Gradio interface"
LABEL version="1.0"
LABEL gpu.recommended="NVIDIA L4 (24GB VRAM)"

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV GRADIO_SERVER_PORT=7860
ENV GRADIO_SERVER_NAME=0.0.0.0

# Install system dependencies (required for OpenGL, X11, and conda)
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

# Install Miniconda to /opt/conda (persistent across rebuilds)
# Note: Conda environments will be created in /workspace/ for persistence
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh && \
    bash /tmp/miniconda.sh -b -p /opt/conda && \
    rm /tmp/miniconda.sh && \
    /opt/conda/bin/conda clean -a -y

# Add conda to PATH
ENV PATH="/opt/conda/bin:${PATH}"

# Configure conda channels (add conda-forge, remove defaults to avoid ToS requirement)
RUN conda config --add channels conda-forge && \
    conda config --remove channels defaults && \
    conda config --set channel_priority strict

# Create scripts directory in /workspace/
# RunPod mounts persistent volume at /workspace/, so scripts will be accessible
RUN mkdir -p /workspace/scripts

# Copy installation and startup scripts
COPY runpod/install.sh /workspace/scripts/install.sh
COPY runpod/start.sh /workspace/scripts/start.sh

# Make scripts executable
RUN chmod +x /workspace/scripts/install.sh && \
    chmod +x /workspace/scripts/start.sh

# Expose Gradio port
EXPOSE 7860

# Set working directory
WORKDIR /workspace

# Default command: run startup script
# This will check if installation is complete, then launch Gradio
CMD ["/workspace/scripts/start.sh"]
