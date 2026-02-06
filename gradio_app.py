#!/usr/bin/env python3
"""
PartField Gradio Web Interface
A web-based frontend for running PartField 3D part segmentation on RunPod.
"""

import argparse
import os
import shutil
import subprocess
import sys
import time
import uuid
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional, Tuple, List

import gradio as gr

# ==================== Configuration ====================

DEFAULT_JOBS_DIR = "/workspace/jobs"
DEFAULT_PORT = 7860
MODEL_CHECKPOINT = "model/model_objaverse.ckpt"
CONFIG_FILE = "configs/final/demo.yaml"
SUPPORTED_EXTENSIONS = {".obj", ".glb", ".off", ".ply"}
JOB_EXPIRY_HOURS = 24


# ==================== Utility Functions ====================

def get_partfield_dir() -> Path:
    """Get the PartField installation directory."""
    # Try to find the directory relative to this script
    script_dir = Path(__file__).parent.absolute()
    if (script_dir / "partfield_inference.py").exists():
        return script_dir
    # Fallback to /workspace/partfield
    return Path("/workspace/partfield")


def cleanup_old_jobs(jobs_dir: Path, expiry_hours: int = JOB_EXPIRY_HOURS) -> int:
    """Remove job directories older than expiry_hours. Returns count of removed jobs."""
    if not jobs_dir.exists():
        return 0

    cutoff = datetime.now() - timedelta(hours=expiry_hours)
    removed = 0

    for job_dir in jobs_dir.iterdir():
        if job_dir.is_dir():
            try:
                mtime = datetime.fromtimestamp(job_dir.stat().st_mtime)
                if mtime < cutoff:
                    shutil.rmtree(job_dir)
                    removed += 1
            except Exception:
                pass

    return removed


def clear_gpu_memory():
    """Clear GPU memory cache."""
    try:
        import torch
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
            torch.cuda.synchronize()
    except Exception:
        pass


def validate_file(file_path: str) -> Tuple[bool, str]:
    """Validate uploaded file. Returns (is_valid, message)."""
    if not file_path:
        return False, "No file uploaded"

    path = Path(file_path)
    if not path.exists():
        return False, "File does not exist"

    ext = path.suffix.lower()
    if ext not in SUPPORTED_EXTENSIONS:
        return False, f"Unsupported format: {ext}. Supported: {', '.join(SUPPORTED_EXTENSIONS)}"

    # Check file size (max 100MB)
    size_mb = path.stat().st_size / (1024 * 1024)
    if size_mb > 100:
        return False, f"File too large: {size_mb:.1f}MB (max 100MB)"

    # Check for filenames silently skipped by the inference engine
    stem = path.stem.lower()
    if stem in ("car", "complex_car"):
        return False, f"The filename '{path.name}' is reserved and will be skipped by the model. Please rename your file."

    return True, "File valid"


def run_command(cmd: List[str], cwd: Path, log_callback=None) -> Tuple[bool, str]:
    """Run a command and capture output. Returns (success, output)."""
    try:
        process = subprocess.Popen(
            cmd,
            cwd=str(cwd),
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1
        )

        output_lines = []
        for line in iter(process.stdout.readline, ''):
            output_lines.append(line)
            if log_callback:
                log_callback(''.join(output_lines))

        process.wait()
        output = ''.join(output_lines)

        return process.returncode == 0, output

    except Exception as e:
        return False, f"Command failed: {str(e)}"


# ==================== Processing Pipeline ====================

def process_3d_file(
    file_path: str,
    is_point_cloud: bool,
    max_clusters: int,
    use_agglomerative: bool,
    preprocess_mesh: bool,
    adjacency_option: int,
    add_knn_edges: bool,
    points_per_face: int,
    jobs_dir: str,
    progress=gr.Progress()
) -> Tuple[str, List[str], Optional[str], str]:
    """
    Main processing function.

    Args:
        file_path: Path to uploaded file
        is_point_cloud: True for point cloud, False for mesh
        max_clusters: Maximum number of clusters (2-30)
        use_agglomerative: True for agglomerative, False for KMeans
        preprocess_mesh: Whether to preprocess mesh
        adjacency_option: 0=naive, 1=faceMST, 2=ccMST
        add_knn_edges: Whether to add KNN edges
        points_per_face: Points sampled per face (memory control)
        jobs_dir: Directory for job storage
        progress: Gradio progress tracker

    Returns:
        (status_message, list_of_ply_paths, pca_visualization_path, log_output)
    """
    log_output = []

    def log(msg: str):
        timestamp = datetime.now().strftime("%H:%M:%S")
        log_output.append(f"[{timestamp}] {msg}")
        return '\n'.join(log_output)

    # Validate file
    is_valid, msg = validate_file(file_path)
    if not is_valid:
        return f"Error: {msg}", [], None, log(f"Validation failed: {msg}")

    log("File validated successfully")

    # Setup job directory
    job_id = str(uuid.uuid4())[:8]
    jobs_path = Path(jobs_dir)
    job_dir = jobs_path / job_id
    input_dir = job_dir / "input"
    output_dir = job_dir / "output"

    input_dir.mkdir(parents=True, exist_ok=True)
    output_dir.mkdir(parents=True, exist_ok=True)

    log(f"Created job directory: {job_id}")

    # Copy input file
    input_path = Path(file_path)
    dest_path = input_dir / input_path.name
    shutil.copy2(file_path, dest_path)
    log(f"Copied input file: {input_path.name}")

    # Cleanup old jobs
    progress(0.05, desc="Cleaning up old jobs...")
    removed = cleanup_old_jobs(jobs_path)
    if removed > 0:
        log(f"Cleaned up {removed} old job(s)")

    # Clear GPU memory
    progress(0.1, desc="Preparing GPU...")
    clear_gpu_memory()
    log("GPU memory cleared")

    partfield_dir = get_partfield_dir()

    # ==================== Step 1: Feature Extraction ====================
    progress(0.15, desc="Extracting features...")
    log("Starting feature extraction...")

    result_name = f"job_{job_id}"
    actual_features_dir = partfield_dir / "exp_results" / result_name

    inference_cmd = [
        sys.executable, "partfield_inference.py",
        "-c", CONFIG_FILE,
        "--opts",
        "continue_ckpt", MODEL_CHECKPOINT,
        "result_name", result_name,
        "dataset.data_path", str(input_dir),
        "is_pc", str(is_point_cloud),
        "n_point_per_face", str(points_per_face),
        "dataset.val_num_workers", "2",
        "dataset.val_batch_size", "1",
    ]

    if preprocess_mesh and not is_point_cloud:
        inference_cmd.extend(["preprocess_mesh", "True"])

    log(f"Running: {' '.join(inference_cmd[:5])}...")

    def update_log(output):
        # Only keep last 50 lines to prevent overflow
        lines = output.split('\n')[-50:]
        return '\n'.join(log_output) + '\n--- Inference Output ---\n' + '\n'.join(lines)

    success, inference_output = run_command(inference_cmd, partfield_dir, update_log)

    if not success:
        # Check for OOM error
        if "CUDA out of memory" in inference_output or "OutOfMemoryError" in inference_output:
            return (
                "Error: GPU out of memory. Try reducing 'Points per face' in advanced options.",
                [], None,
                log(f"Feature extraction failed: GPU out of memory\n{inference_output[-500:]}")
            )
        return (
            "Error: Feature extraction failed",
            [], None,
            log(f"Feature extraction failed:\n{inference_output[-1000:]}")
        )

    log("Feature extraction completed")
    progress(0.5, desc="Features extracted")

    # Find PCA visualization file
    pca_file = None
    for f in actual_features_dir.glob("feat_pca_*.ply"):
        pca_file = str(f)
        break

    # ==================== Step 2: Clustering ====================
    progress(0.55, desc="Running clustering...")
    log("Starting clustering...")

    # Build clustering command
    clustering_cmd = [
        sys.executable, "run_part_clustering.py",
        "--root", str(actual_features_dir),
        "--dump_dir", str(output_dir),
        "--source_dir", str(input_dir),
        "--max_num_clusters", str(max_clusters),
        "--is_pc", str(is_point_cloud),
        "--export_mesh", "True",
    ]

    if not is_point_cloud:
        clustering_cmd.extend([
            "--use_agglo", str(use_agglomerative),
            "--option", str(adjacency_option),
            "--with_knn", str(add_knn_edges),
        ])

    log(f"Running clustering with max {max_clusters} clusters...")

    success, clustering_output = run_command(clustering_cmd, partfield_dir, update_log)

    if not success:
        return (
            "Error: Clustering failed",
            [], pca_file,
            log(f"Clustering failed:\n{clustering_output[-1000:]}")
        )

    log("Clustering completed")
    progress(0.9, desc="Clustering complete")

    # ==================== Step 3: Collect Results ====================
    progress(0.95, desc="Collecting results...")

    # Find all output mesh files (PLY and OBJ)
    ply_dir = output_dir / "ply"
    mesh_files = []

    if ply_dir.exists():
        # Sort by number of clusters (extracted from filename)
        # Look for both .ply and .obj files (OBJ is used when UV maps are preserved)
        mesh_list = list(ply_dir.glob("*.ply")) + list(ply_dir.glob("*.obj"))

        def get_cluster_count(path):
            # Filename format: {uid}_{view_id}_{num_clusters}.ply or .obj
            try:
                return int(path.stem.split('_')[-1])
            except:
                return 0

        mesh_list.sort(key=get_cluster_count)
        mesh_files = [str(f) for f in mesh_list]

    if not mesh_files:
        return (
            "Warning: No output files generated",
            [], pca_file,
            log("Processing completed but no mesh files were generated")
        )

    # Clear GPU memory after processing
    clear_gpu_memory()

    # Cleanup feature files to save disk space
    if actual_features_dir.exists():
        shutil.rmtree(actual_features_dir, ignore_errors=True)

    # Check if OBJ files were generated (UV maps preserved)
    has_obj = any(f.endswith('.obj') for f in mesh_files)
    format_note = " (with UV maps)" if has_obj else ""

    log(f"Generated {len(mesh_files)} segmentation result(s){format_note}")
    progress(1.0, desc="Done!")

    return (
        f"Success! Generated {len(mesh_files)} segmentation(s) with 2 to {max_clusters} parts{format_note}",
        mesh_files,
        pca_file,
        '\n'.join(log_output)
    )


# ==================== Gradio Interface ====================

def create_interface(jobs_dir: str) -> gr.Blocks:
    """Create the Gradio interface."""

    with gr.Blocks(
        title="PartField - 3D Part Segmentation",
        theme=gr.themes.Soft(),
        css="""
        .log-output { font-family: monospace; font-size: 12px; }
        """
    ) as app:

        gr.Markdown("""
        # PartField - 3D Part Segmentation

        Upload a 3D model (mesh or point cloud) to automatically segment it into semantic parts.

        **Supported formats:** OBJ, GLB, OFF, PLY
        """)

        with gr.Row():
            # Left column: Input and parameters
            with gr.Column(scale=1):
                # File upload
                input_file = gr.File(
                    label="Upload 3D File",
                    file_types=[".obj", ".glb", ".off", ".ply"],
                    type="filepath"
                )

                # Basic parameters
                is_point_cloud = gr.Checkbox(
                    label="Point Cloud Input",
                    value=False,
                    info="Check if uploading a point cloud (PLY with points only)"
                )

                max_clusters = gr.Slider(
                    label="Maximum Number of Parts",
                    minimum=2,
                    maximum=30,
                    value=20,
                    step=1,
                    info="Generate segmentations from 2 parts up to this number"
                )

                use_agglomerative = gr.Checkbox(
                    label="Use Agglomerative Clustering",
                    value=True,
                    info="Recommended for meshes. Uncheck for KMeans."
                )

                # Advanced options
                with gr.Accordion("Advanced Options", open=False):
                    preprocess_mesh = gr.Checkbox(
                        label="Preprocess Mesh",
                        value=False,
                        info="Clean and repair mesh before processing"
                    )

                    adjacency_option = gr.Radio(
                        label="Face Adjacency Method",
                        choices=[
                            ("Naive (fast)", 0),
                            ("Face MST (balanced)", 1),
                            ("Component MST (robust)", 2)
                        ],
                        value=1,
                        info="How to build the face adjacency graph"
                    )

                    add_knn_edges = gr.Checkbox(
                        label="Add KNN Edges",
                        value=False,
                        info="Add k-nearest neighbor edges to adjacency"
                    )

                    points_per_face = gr.Slider(
                        label="Points per Face",
                        minimum=100,
                        maximum=2000,
                        value=1000,
                        step=100,
                        info="Lower = less memory, potentially less accurate"
                    )

                # Process button
                process_btn = gr.Button("Process", variant="primary", size="lg")

            # Right column: Results
            with gr.Column(scale=2):
                # Status
                status_text = gr.Textbox(
                    label="Status",
                    interactive=False,
                    lines=1
                )

                # 3D visualization
                with gr.Tabs():
                    with gr.TabItem("Segmentation Results"):
                        result_selector = gr.Dropdown(
                            label="Select Number of Parts",
                            choices=[],
                            interactive=True
                        )

                        result_model = gr.Model3D(
                            label="Segmented Model",
                            height=400
                        )

                        with gr.Row():
                            download_btn = gr.Button("Download Selected Mesh", size="sm")
                            download_file = gr.File(label="Download", visible=False)

                    with gr.TabItem("Feature Visualization"):
                        pca_model = gr.Model3D(
                            label="PCA Feature Visualization",
                            height=400
                        )

                # Processing log
                with gr.Accordion("Processing Log", open=False):
                    log_output = gr.Textbox(
                        label="Log",
                        lines=15,
                        max_lines=30,
                        interactive=False,
                        elem_classes=["log-output"]
                    )

        # State for storing results mapping (label -> path)
        result_files_state = gr.State({})

        def on_process(file_path, is_pc, max_clust, use_agglo, preprocess, adj_opt, knn, ppf, progress=gr.Progress()):
            """Handle process button click."""
            status, mesh_files, pca_file, log = process_3d_file(
                file_path=file_path,
                is_point_cloud=is_pc,
                max_clusters=max_clust,
                use_agglomerative=use_agglo,
                preprocess_mesh=preprocess,
                adjacency_option=adj_opt,
                add_knn_edges=knn,
                points_per_face=ppf,
                jobs_dir=jobs_dir,
                progress=progress
            )

            # Create dropdown choices and file mapping
            dropdown_choices = []
            files_mapping = {}

            for mesh_path in mesh_files:
                path = Path(mesh_path)
                # Extract cluster count from filename
                try:
                    cluster_count = path.stem.split('_')[-1]
                    # Indicate format in label if OBJ (has UV maps)
                    format_suffix = " (UV)" if path.suffix.lower() == '.obj' else ""
                    label = f"{cluster_count} parts{format_suffix}"
                except:
                    label = path.stem

                dropdown_choices.append(label)
                files_mapping[label] = mesh_path

            # Select first result by default
            first_choice = dropdown_choices[0] if dropdown_choices else None
            first_model = files_mapping.get(first_choice) if first_choice else None

            return (
                status,
                gr.Dropdown(choices=dropdown_choices, value=first_choice),
                first_model,
                pca_file,
                log,
                files_mapping
            )

        def on_select_result(selected_label, files_mapping):
            """Handle dropdown selection change."""
            if selected_label and files_mapping and selected_label in files_mapping:
                return files_mapping[selected_label]
            return None

        def on_download(selected_label, files_mapping):
            """Handle download button click."""
            if selected_label and files_mapping and selected_label in files_mapping:
                path = files_mapping[selected_label]
                if Path(path).exists():
                    return gr.File(value=path, visible=True)
            return gr.File(visible=False)

        # Connect events
        process_btn.click(
            fn=on_process,
            inputs=[
                input_file,
                is_point_cloud,
                max_clusters,
                use_agglomerative,
                preprocess_mesh,
                adjacency_option,
                add_knn_edges,
                points_per_face
            ],
            outputs=[
                status_text,
                result_selector,
                result_model,
                pca_model,
                log_output,
                result_files_state
            ]
        )

        result_selector.change(
            fn=on_select_result,
            inputs=[result_selector, result_files_state],
            outputs=[result_model]
        )

        download_btn.click(
            fn=on_download,
            inputs=[result_selector, result_files_state],
            outputs=[download_file]
        )

        # Footer
        gr.Markdown("""
        ---
        **PartField** by [TencentARC](https://github.com/TencentARC/PartField) |
        Fork: [Salourh/PartField](https://github.com/Salourh/PartField) |
        Running on RunPod NVIDIA L4
        """)

    return app


# ==================== Main ====================

def main():
    parser = argparse.ArgumentParser(description="PartField Gradio Web Interface")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help="Server port")
    parser.add_argument("--share", action="store_true", help="Create public Gradio link")
    parser.add_argument("--jobs-dir", type=str, default=DEFAULT_JOBS_DIR, help="Directory for job storage")
    args = parser.parse_args()

    # Ensure jobs directory exists
    jobs_path = Path(args.jobs_dir)
    jobs_path.mkdir(parents=True, exist_ok=True)

    # Create and launch interface
    app = create_interface(args.jobs_dir)

    app.launch(
        server_name="0.0.0.0",
        server_port=args.port,
        share=args.share,
        show_error=True
    )


if __name__ == "__main__":
    main()
