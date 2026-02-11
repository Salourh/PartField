# PartField on RunPod - Deployment Guide

Complete guide for deploying PartField (3D Part Segmentation) on RunPod with Gradio interface.

## Table of Contents

- [Quick Start](#quick-start)
- [Manual Control](#manual-control)
- [Using the Gradio Interface](#using-the-gradio-interface)
- [Troubleshooting](#troubleshooting)
- [File Locations](#file-locations)
- [Performance and Costs](#performance-and-costs)
- [GPU Recommendations](#gpu-recommendations)
- [Support](#support)

---

## Quick Start

### 1. Deploy the Pod

**Via RunPod Template** (Recommended):
1. Go to RunPod Console → Templates
2. Find "PartField - 3D Part Segmentation" template
3. Click "Deploy"
4. Select **NVIDIA L4 GPU** (24GB VRAM, recommended)
5. Wait for pod to start (~30 seconds)

**Manual Deployment**:
1. Create a new GPU pod on RunPod
2. Select **NVIDIA L4** or any GPU with 24GB+ VRAM
3. Use Docker image: `timfredfred/partfield-runpod:latest`
4. Set volume size: 25GB minimum
5. Expose port: 7860 (HTTP)
6. Set environment variables:
   - `GRADIO_SERVER_PORT=7860`
   - `GRADIO_SERVER_NAME=0.0.0.0`

### 2. Run Installation (First Time Only)

Open the pod terminal and run:

```bash
bash /opt/partfield/install.sh
```

This will:
- Clone the PartField repository
- Install PyTorch 2.4.0 with CUDA 12.4 and all dependencies via pip
- Download model checkpoint (~300MB)
- Verify installation

**Expected time**: 5-8 minutes (one-time only)

### 3. Access the Application

Once installation completes, the Gradio interface will launch automatically.

Access it at:
```
https://<pod-id>-7860.proxy.runpod.net
```

You can find this URL in:
- RunPod pod details → "Connect" → "HTTP Service [7860]"
- Terminal output after startup

---

## Manual Control

### Start the Application

If the application isn't running, start it with:

```bash
bash /opt/partfield/start.sh
```

This will:
- Verify installation
- Reinstall system libraries
- Check GPU availability
- Launch Gradio on port 7860

**Expected time**: ~10 seconds

### Stop the Application

Press `Ctrl+C` in the terminal, or stop the pod from RunPod console.

### Reinstall from Scratch

If you need to reinstall:

```bash
# Delete marker file
rm /workspace/.partfield_v4_installed

# Run installation again
bash /opt/partfield/install.sh
```

### Check Installation Status

```bash
# Check if installed
cat /workspace/.partfield_v4_installed

# Verify Python packages
python3 -c "import torch; print(f'PyTorch: {torch.__version__}, CUDA: {torch.cuda.is_available()}')"
```

---

## Using the Gradio Interface

### Supported File Formats

Upload 3D models in these formats:
- `.obj` - Wavefront OBJ (most common)
- `.glb` - Binary GLTF
- `.off` - Object File Format
- `.ply` - Polygon File Format

### Segmentation Parameters

Configure the segmentation with these parameters:

**Feature Extraction**:
- **points_per_face**: Number of sample points per face (default: 2000)
  - Higher = more detail, more memory
  - Lower if you get GPU OOM errors (try 1000 or 500)
- **features_per_sample**: Features per sampling iteration (default: 10000)
  - Affects processing speed
  - Reduce for faster processing on simple meshes

**Clustering**:
- **n_clusters**: Number of parts to segment into (default: 5)
  - Increase for more detailed segmentation
  - Decrease for simpler, coarser parts
- **pca_components**: PCA dimensions for visualization (default: 3)
  - Usually keep at 3 for 3D visualization

### Workflow

1. **Upload Model**: Click "Upload 3D Model" and select your file
2. **Configure Parameters**: Adjust as needed (defaults work for most models)
3. **Run Segmentation**: Click "Segment 3D Model"
4. **Wait for Processing**:
   - Feature extraction: 1-3 minutes
   - Clustering: 30-60 seconds
   - Total: 2-5 minutes (typical)
5. **View Results**:
   - Segmented model with color-coded parts
   - PCA visualization of feature space
6. **Download**: Click "Download Segmented Model" to get the result

### Tips for Best Results

- **Start simple**: Test with a small model first (~10K faces)
- **Monitor GPU**: Check pod logs for memory warnings
- **Adjust parameters**: If OOM occurs, reduce `points_per_face`
- **Multiple runs**: Try different `n_clusters` to find optimal segmentation
- **File size**: Models up to 50MB typically work well

---

## Troubleshooting

### GPU Out of Memory (OOM)

**Symptoms**: Error message mentioning "CUDA out of memory" or "OOM"

**Solutions**:
1. Reduce `points_per_face` to 1000 or 500
2. Reduce `features_per_sample` to 5000
3. Use a simpler mesh (fewer faces)
4. Restart the pod to clear GPU memory
5. Upgrade to GPU with more VRAM (e.g., A100 40GB)

**Example settings for complex meshes**:
```
points_per_face: 1000
features_per_sample: 5000
n_clusters: 4
```

### Model Download Failed

**Symptoms**: Installation fails at "Phase 7: Downloading Model Checkpoint"

**Solutions**:

1. **Retry installation** (network issues are common):
   ```bash
   rm /workspace/.partfield_v3_installed
   bash /opt/partfield/install.sh
   ```

2. **Manual download**:
   ```bash
   cd /workspace/partfield
   mkdir -p model
   wget -O model/model_objaverse.ckpt \
     https://huggingface.co/mikaelaangel/partfield-ckpt/resolve/main/model_objaverse.ckpt
   ```

3. **Verify download**:
   ```bash
   ls -lh /workspace/partfield/model/model_objaverse.ckpt
   # Should show ~300MB file
   ```

### No GPU Detected

**Symptoms**: Warning message "No GPU detected!" during startup

**Solutions**:
1. Verify GPU assigned to pod (RunPod console)
2. Check `nvidia-smi` output in terminal
3. Restart the pod
4. If persists, contact RunPod support

### Server Won't Start

**Symptoms**: Gradio doesn't launch, or port 7860 not accessible

**Solutions**:

1. **Check if installation completed**:
   ```bash
   cat /workspace/.partfield_v3_installed
   ```

2. **Check for errors in startup**:
   ```bash
   bash /opt/partfield/start.sh
   # Look for error messages in red
   ```

3. **Verify port binding**:
   ```bash
   # In another terminal
   curl http://localhost:7860
   # Should return HTML
   ```

4. **Check Gradio process**:
   ```bash
   ps aux | grep gradio_app.py
   ```

### Import Errors or Missing Packages

**Symptoms**: Import errors or missing packages

**Solutions**:

1. **Test imports manually**:
   ```bash
   python3 -c "import torch, gradio, lightning; print('OK')"
   ```

2. **Reinstall** (last resort):
   ```bash
   rm /workspace/.partfield_v4_installed
   bash /opt/partfield/install.sh
   ```

### Upload Fails or Invalid File Error

**Symptoms**: Error when uploading 3D model file

**Solutions**:
1. Verify file format is supported (OBJ, GLB, OFF, PLY)
2. Check file isn't corrupted (open in Blender or MeshLab)
3. Try a different model file
4. Check file size (very large files may timeout)
5. Check pod logs for specific error message

---

## File Locations

### Workspace Structure

After installation, `/workspace/` contains:

```
/workspace/
├── .partfield_v4_installed          # Installation marker (version + timestamp)
├── (scripts are in /opt/partfield/ inside the Docker image)
│   # /opt/partfield/install.sh       # One-time installation
│   # /opt/partfield/start.sh         # Quick restart script
├── partfield/                        # Cloned repository
│   ├── gradio_app.py                 # Main Gradio application
│   ├── configs/
│   │   └── final/demo.yaml           # Inference configuration
│   ├── partfield/                    # Core package
│   ├── model/
│   │   └── model_objaverse.ckpt      # Downloaded checkpoint (300MB)
│   └── runpod/                       # RunPod deployment files
│       ├── Dockerfile
│       ├── install.sh
│       ├── start.sh
│       └── README_RUNPOD.md (this file)
└── jobs/                             # Gradio temporary results
    └── <job-id>/                     # Auto-deleted after 24 hours
        ├── upload/                   # Uploaded model
        ├── features/                 # Extracted features
        └── clustering/               # Segmentation results
```

### Important Files

- **Installation marker**: `/workspace/.partfield_v4_installed`
- **Model checkpoint**: `/workspace/partfield/model/model_objaverse.ckpt`
- **Gradio app**: `/workspace/partfield/gradio_app.py`
- **Job results**: `/workspace/jobs/<job-id>/`

### Persistent vs. Temporary

**Persistent** (survives pod restarts):
- `/workspace/` and all contents
- Model checkpoint
- Installed pip packages (in system Python)
- Job results (until 24-hour cleanup)

**Temporary** (reset on restart):
- `/usr/lib/` (system libraries)
- Running processes
- Terminal history

---

## Performance and Costs

### Expected Performance (NVIDIA L4)

| Operation | Time |
|-----------|------|
| First installation | 10-15 minutes |
| Pod restart | ~10 seconds |
| Feature extraction (simple mesh) | 1-2 minutes |
| Feature extraction (complex mesh) | 2-5 minutes |
| Clustering | 30-60 seconds |
| **Total per segmentation** | **2-5 minutes** |

### Storage Usage

| Component | Size |
|-----------|------|
| Docker image | ~8GB |
| Pip packages | ~3GB |
| Model checkpoint | ~300MB |
| Job results (per job) | ~10-50MB |
| **Total persistent** | **~12GB** |

**Recommended volume size**: 15GB minimum

### Cost Estimates (NVIDIA L4)

Typical RunPod pricing for L4: **$0.40 - $0.60/hour** (varies by region and availability)

| Usage Pattern | Time | Cost (@ $0.50/hr) |
|---------------|------|-------------------|
| First-time setup | 15 min | $0.13 |
| Single segmentation | 3 min | $0.025 |
| 10 segmentations | 30 min | $0.25 |
| 1 hour continuous | 1 hour | $0.50 |
| 8-hour workday | 8 hours | $4.00 |

**Tips to reduce costs**:
- Stop pod when not in use (installation persists)
- Process multiple models in one session
- Use spot instances for non-urgent work
- Consider higher-tier pods only for very complex meshes

---

## GPU Recommendations

### Primary Target: NVIDIA L4 (Recommended)

**Specs**:
- Architecture: Ada Lovelace
- VRAM: 24GB GDDR6
- TDP: 72W
- Price: $0.40-0.60/hour

**Why L4?**:
- 24GB VRAM is perfect for PartField (tested and optimized)
- Excellent mixed-precision (FP16/FP32) inference performance
- Cost-effective for deployment workloads
- Wide availability on RunPod
- Runs cool and efficient

**Expected performance**:
- Most meshes: 2-4 minutes
- Complex meshes: 4-6 minutes
- Memory usage: 8-16GB typical, up to 20GB peak

### Alternative GPUs

**Budget Option**:
- **RTX A4000** (16GB): $0.30-0.40/hour
  - Works for simple-to-medium meshes
  - May OOM on complex models (reduce `points_per_face`)

**Higher Performance**:
- **RTX A5000** (24GB): $0.60-0.80/hour
  - Similar to L4, slightly faster
- **A10** (24GB): $0.50-0.70/hour
  - Good alternative to L4
- **RTX 4090** (24GB): $0.70-0.90/hour
  - Fastest for inference, overkill for most cases

**Overkill** (not recommended unless needed):
- **A100 40GB/80GB**: $1.50-3.00/hour
  - Only needed for extremely complex meshes or batch processing
  - 3-5x more expensive than L4 for minimal benefit

### GPU Selection Guide

**Choose L4 if**:
- You're processing typical 3D models (<1M faces)
- You want the best price/performance ratio
- You're deploying for regular use

**Choose RTX A4000 if**:
- Budget is critical
- Models are simple (<500K faces)
- Willing to adjust parameters

**Choose A100 if**:
- Processing very complex meshes (>2M faces)
- Batch processing many models
- Budget is not a constraint

---

## Support

### Documentation

- **Main README**: `/workspace/partfield/README.md`
- **Paper**: [PartField on arXiv](https://arxiv.org/abs/2412.05972)
- **Project page**: [3DLG PartField](https://3dlg-hcvc.github.io/partfield/)

### GitHub

- **Repository**: https://github.com/3dlg-hcvc/PartField
- **Issues**: https://github.com/3dlg-hcvc/PartField/issues
- **Pull requests**: Welcome!

### RunPod Resources

- **RunPod Docs**: https://docs.runpod.io
- **Community Discord**: https://discord.gg/runpod
- **Support**: support@runpod.io

### Getting Help

1. **Check this guide first** - Most issues have solutions above
2. **Check pod logs** - Look for error messages (red text)
3. **Search GitHub issues** - Your issue may already be reported
4. **Create new issue** - Include:
   - GPU type and VRAM
   - Error message (full text)
   - Steps to reproduce
   - Relevant log output

---

## Credits

**PartField** is an ICCV 2025 research project by:
- Devi P. Borah
- Mikaela Angelina Uy
- Yilin Liu
- Nicolas Savva
- Mahdi Rad
- Angel X. Chang

**RunPod Template** created for easy deployment and community access.

---

## License

See main repository for license information: https://github.com/3dlg-hcvc/PartField

---

**Enjoy segmenting 3D models with PartField!**

If you use this work in research, please cite:
```bibtex
@inproceedings{borah2025partfield,
  title={PartField: Modeling 3D Object-Part Interactions via Neural Feature Fields},
  author={Borah, Devi P. and Uy, Mikaela Angelina and Liu, Yilin and Savva, Nicolas and Rad, Mahdi and Chang, Angel X.},
  booktitle={ICCV},
  year={2025}
}
```
