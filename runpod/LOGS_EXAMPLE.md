# Exemple de Logs - Avant/Après Nettoyage

## ❌ Avant (Verbose, Bruyant)

```
========================================
PHASE 3: Installing PyTorch 2.4.0 with CUDA 12.4
========================================

[INFO] Installing PyTorch from cu124 wheel index...
[DEBUG] This may take 2-3 minutes...
[DEBUG] Running: pip install torch==2.4.0 torchvision==0.19.0 torchaudio==2.4.0 --index-url https://download.pytorch.org/whl/cu124
Looking in indexes: https://download.pytorch.org/whl/cu124
Collecting torch==2.4.0
  Downloading https://download.pytorch.org/whl/cu124/torch-2.4.0%2Bcu124-cp310-cp310-linux_x86_64.whl (2532.5 MB)
     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 2.5/2.5 GB 50.0 MB/s eta 0:00:00
Collecting torchvision==0.19.0
  Downloading https://download.pytorch.org/whl/cu124/torchvision-0.19.0%2Bcu124-cp310-cp310-linux_x86_64.whl (7.3 MB)
     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 7.3/7.3 MB 100.0 MB/s eta 0:00:00
Collecting torchaudio==2.4.0
  Downloading https://download.pytorch.org/whl/cu124/torchaudio-2.4.0%2Bcu124-cp310-cp310-linux_x86_64.whl (4.5 MB)
     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 4.5/4.5 MB 120.0 MB/s eta 0:00:00
Collecting filelock (from torch==2.4.0)
  Using cached filelock-3.13.1-py3-none-any.whl.metadata (2.8 kB)
Collecting typing-extensions>=4.8.0 (from torch==2.4.0)
  Using cached typing_extensions-4.9.0-py3-none-any.whl.metadata (3.0 kB)
Collecting sympy (from torch==2.4.0)
  Downloading sympy-1.12-py3-none-any.whl.metadata (12 kB)
Collecting networkx (from torch==2.4.0)
  Using cached networkx-3.2.1-py3-none-any.whl.metadata (5.2 kB)
[... 50+ more lines of package collection ...]
Installing collected packages: mpmath, typing-extensions, sympy, pillow, numpy, networkx, jinja2, fsspec, filelock, torch, torchvision, torchaudio
Successfully installed filelock-3.13.1 fsspec-2024.2.0 jinja2-3.1.3 mpmath-1.3.0 networkx-3.2.1 numpy-1.26.4 pillow-10.2.0 sympy-1.12 torch-2.4.0+cu124 torchaudio-2.4.0+cu124 torchvision-0.19.0+cu124 typing-extensions-4.9.0
[SUCCESS] PyTorch 2.4.0+cu124 installed
```

**Problèmes** :
- 😵 60+ lignes de bruit pip
- 📊 Barres de progression qui polluent
- 🔍 Difficile de trouver nos logs personnalisés
- ❌ Messages d'erreur noyés dans le bruit

---

## ✅ Après (Clean, Clair)

```
========================================
PHASE 3: Installing PyTorch 2.4.0 with CUDA 12.4
========================================

[INFO] Installing PyTorch 2.4.0+cu124 (this may take 2-3 minutes)...
[DEBUG] Running: pip install torch==2.4.0 torchvision==0.19.0 torchaudio==2.4.0
[SUCCESS] PyTorch 2.4.0+cu124 installed

[DEBUG] Verifying PyTorch installation...
PyTorch version: 2.4.0+cu124
CUDA available: True
CUDA version: 12.4
[SUCCESS] PyTorch verification complete
```

**Avantages** :
- ✅ 7 lignes au lieu de 60+
- 🎯 Seuls nos logs personnalisés sont visibles
- 📝 Messages clairs et concis
- ⚡ Facile à scanner visuellement

---

## Exemple Complet : Phase 4

### ❌ Avant
```
========================================
PHASE 4: Installing PartField Dependencies
========================================

[INFO] Installing core ML packages...
[DEBUG] This may take 3-5 minutes...
Looking in indexes: https://pypi.org/simple
Collecting lightning==2.2.0
  Downloading lightning-2.2.0-py3-none-any.whl.metadata (36 kB)
Collecting h5py
  Downloading h5py-3.10.0-cp310-cp310-manylinux_2_17_x86_64.manylinux2014_x86_64.whl.metadata (2.5 kB)
[... 100+ lines ...]
Successfully installed boto3-1.34.34 botocore-1.34.34 h5py-3.10.0 jmespath-1.0.1 lightning-2.2.0 loguru-0.7.2 matplotlib-3.8.2 networkx-3.2.1 psutil-5.9.8 s3transfer-0.10.0 scikit-image-0.22.0 scikit-learn-1.4.0 scipy-1.12.0 threadpoolctl-3.2.0 trimesh-4.0.10 yacs-0.1.8

[INFO] Installing 3D processing packages...
[DEBUG] This may take 3-5 minutes...
Collecting mesh2sdf
  Downloading mesh2sdf-0.1.0-py3-none-any.whl.metadata (1.2 kB)
[... 150+ lines ...]
Successfully installed arrgh-0.1.0 einops-0.7.0 libigl-2.4.1 mesh2sdf-0.1.0 open3d-0.18.0 plyfile-1.0.3 polyscope-2.2.1 potpourri3d-0.0.9 pymeshlab-2023.12 simple-parsing-0.1.4 tetgen-0.6.3

[INFO] Installing torch-scatter from PyG wheels...
[DEBUG] Running: pip install torch-scatter -f https://data.pyg.org/whl/torch-2.4.0+cu124.html
Looking in links: https://data.pyg.org/whl/torch-2.4.0+cu124.html
Collecting torch-scatter
  Downloading https://data.pyg.org/whl/torch-2.4.0%2Bcu124/torch_scatter-2.1.2%2Bpt24cu124-cp310-cp310-linux_x86_64.whl (8.0 MB)
     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 8.0/8.0 MB 80.0 MB/s eta 0:00:00
Installing collected packages: torch-scatter
Successfully installed torch-scatter-2.1.2+pt24cu124

[INFO] Installing visualization and web packages...
Collecting vtk
  Downloading vtk-9.3.0-cp310-cp310-manylinux_2_17_x86_64.manylinux2014_x86_64.whl.metadata (5.2 kB)
[... 80+ lines ...]
Successfully installed aiofiles-23.2.1 altair-5.2.0 annotated-types-0.6.0 anyio-4.2.0 ... vtk-9.3.0

[SUCCESS] All dependencies installed
```

**Total** : ~350+ lignes de bruit pip

---

### ✅ Après
```
========================================
PHASE 4: Installing PartField Dependencies
========================================

[INFO] Installing core ML packages (lightning, scipy, sklearn, etc.)...
[SUCCESS] Core ML packages installed (12 packages)

[INFO] Installing 3D processing packages (open3d, pymeshlab, trimesh, etc.)...
[SUCCESS] 3D processing packages installed (11 packages)

[INFO] Installing torch-scatter from PyG wheels...
[DEBUG] Running: pip install torch-scatter -f https://data.pyg.org/whl/torch-2.4.0+cu124.html
[SUCCESS] torch-scatter installed

[INFO] Installing visualization and web packages (gradio, vtk, huggingface_hub)...
[SUCCESS] Visualization packages installed (3 packages)

[SUCCESS] All dependencies installed successfully
```

**Total** : 11 lignes claires et informatives

---

## Exemple : Téléchargement du Modèle

### ❌ Avant
```
========================================
PHASE 5: Downloading Model Checkpoint from HuggingFace
========================================

[INFO] Model repository: mikaelaangel/partfield-ckpt
[INFO] Destination: /workspace/partfield/model/model_objaverse.ckpt
[DEBUG] Creating model directory...
[INFO] Downloading model checkpoint (~300MB, this may take 2-5 minutes)...
[DEBUG] Using HuggingFace Hub API with wget fallback
[DEBUG] Starting model download...
[DEBUG] Repository: mikaelaangel/partfield-ckpt
[DEBUG] File: model_objaverse.ckpt
[DEBUG] Destination: /workspace/partfield/model
[INFO] Using huggingface_hub for download...
Fetching 1 files: 100%|██████████| 1/1 [00:00<00:00, 1234.56 files/s]
model_objaverse.ckpt: 100%|██████████| 297M/297M [01:23<00:00, 3.56MB/s]
[SUCCESS] Model downloaded to: /workspace/partfield/model/model_objaverse.ckpt
[DEBUG] Downloaded file size: 297.3 MB
[SUCCESS] Model checkpoint ready (298M)
[DEBUG] Model file: /workspace/partfield/model/model_objaverse.ckpt
[DEBUG] Size: 297 MB
```

---

### ✅ Après (avec --quiet)
```
========================================
PHASE 5: Downloading Model Checkpoint from HuggingFace
========================================

[INFO] Model repository: mikaelaangel/partfield-ckpt
[INFO] Destination: /workspace/partfield/model/model_objaverse.ckpt
[DEBUG] Creating model directory...
[INFO] Downloading model checkpoint (~300MB, this may take 2-5 minutes)...
[DEBUG] Using HuggingFace Hub API with wget fallback
[SUCCESS] Model downloaded to: /workspace/partfield/model/model_objaverse.ckpt
[SUCCESS] Model checkpoint ready (298M)
[DEBUG] Model file: /workspace/partfield/model/model_objaverse.ckpt
[DEBUG] Size: 297 MB
```

---

## Exemple : En Cas d'Erreur

### ✅ Les erreurs restent visibles !

```
========================================
PHASE 3: Installing PyTorch 2.4.0 with CUDA 12.4
========================================

[INFO] Installing PyTorch 2.4.0+cu124 (this may take 2-3 minutes)...
[DEBUG] Running: pip install torch==2.4.0 torchvision==0.19.0 torchaudio==2.4.0
ERROR: Could not find a version that satisfies the requirement torch==2.4.0
ERROR: No matching distribution found for torch==2.4.0
[ERROR] Failed to install PyTorch. Check network connection and disk space.
[ERROR] Installation failed. Container will stay alive for debugging.
[INFO] Check the error message above and retry with: bash /opt/partfield/install.sh
```

**Important** : Les erreurs pip/conda sont **toujours affichées** en cas d'échec !

---

## Résumé des Changements

| Commande | Avant | Après |
|----------|-------|-------|
| **pip install** | Verbose (100+ lignes) | `--quiet` (0 lignes, erreurs si échec) |
| **conda create** | Verbose (30+ lignes) | `--quiet` (0 lignes, erreurs si échec) |
| **git clone** | Verbose (10+ lignes) | `--quiet` (0 lignes, erreurs si échec) |
| **apt-get install** | Verbose (20+ lignes) | Silencieux (0 lignes, warnings si échec) |
| **wget** | Barres de progression | `--quiet --show-progress` (barre simple) |
| **Nos logs** | Noyés dans le bruit | ✨ **Parfaitement visibles** ✨ |

---

## Avantages

### ✅ Pour l'Utilisateur
- 📖 Logs faciles à lire (90% de réduction)
- 🎯 Focus sur les informations importantes
- 🔍 Erreurs immédiatement visibles
- ⚡ Scan visuel rapide de la progression

### ✅ Pour le Debugging
- 🐛 Messages d'erreur clairs et non dilués
- 📝 Stack traces complètes en cas d'échec
- 🔧 Logs DEBUG toujours disponibles
- 💾 Sortie complète si erreur (via variables)

### ✅ Pour le Support
- 📊 Logs standardisés et prévisibles
- 🎨 Codes couleur clairs (INFO/SUCCESS/ERROR)
- 📄 Plus facile de copier/coller pour tickets
- 🚀 Diagnostic plus rapide

---

## Exemple Complet de Session d'Installation

```
========================================
PartField RunPod Template v3.0
Installation Script
========================================

[INFO] Starting installation at 2025-02-11 10:30:00

========================================
PHASE 1: Cloning PartField Repository
========================================

[DEBUG] Checking repository directory: /workspace/partfield
[INFO] Cloning repository to /workspace/partfield...
[DEBUG] Running: git clone https://github.com/Salourh/PartField.git partfield
[SUCCESS] Repository cloned successfully
[DEBUG] Working directory: /workspace/partfield
[DEBUG] Verifying repository files...
[SUCCESS] Repository verification complete

========================================
PHASE 2: Creating Conda Environment (Python 3.10)
========================================

[DEBUG] Checking conda installation...
[DEBUG] Sourcing conda...
[DEBUG] Configuring conda...
[DEBUG] Target conda environment path: /workspace/miniconda3/envs/partfield
[INFO] Creating clean Python 3.10 environment...
[DEBUG] Running: conda create --yes -p /workspace/miniconda3/envs/partfield python=3.10
[SUCCESS] Conda environment created
[DEBUG] Activating conda environment...
[INFO] Python: 3.10.13 at /workspace/miniconda3/envs/partfield/bin/python3
[DEBUG] Python path: /workspace/miniconda3/envs/partfield/bin/python3
[DEBUG] Pip version: pip 24.0 from /workspace/miniconda3/envs/partfield/lib/python3.10/site-packages/pip (python 3.10)

========================================
PHASE 3: Installing PyTorch 2.4.0 with CUDA 12.4
========================================

[INFO] Installing PyTorch 2.4.0+cu124 (this may take 2-3 minutes)...
[DEBUG] Running: pip install torch==2.4.0 torchvision==0.19.0 torchaudio==2.4.0
[SUCCESS] PyTorch 2.4.0+cu124 installed

[DEBUG] Verifying PyTorch installation...
PyTorch version: 2.4.0+cu124
CUDA available: True
CUDA version: 12.4
[SUCCESS] PyTorch verification complete

========================================
PHASE 4: Installing PartField Dependencies
========================================

[INFO] Installing core ML packages (lightning, scipy, sklearn, etc.)...
[SUCCESS] Core ML packages installed (12 packages)

[INFO] Installing 3D processing packages (open3d, pymeshlab, trimesh, etc.)...
[SUCCESS] 3D processing packages installed (11 packages)

[INFO] Installing torch-scatter from PyG wheels...
[DEBUG] Running: pip install torch-scatter -f https://data.pyg.org/whl/torch-2.4.0+cu124.html
[SUCCESS] torch-scatter installed

[INFO] Installing visualization and web packages (gradio, vtk, huggingface_hub)...
[SUCCESS] Visualization packages installed (3 packages)

[SUCCESS] All dependencies installed successfully

========================================
PHASE 5: Downloading Model Checkpoint from HuggingFace
========================================

[INFO] Model repository: mikaelaangel/partfield-ckpt
[INFO] Destination: /workspace/partfield/model/model_objaverse.ckpt
[DEBUG] Creating model directory...
[INFO] Downloading model checkpoint (~300MB, this may take 2-5 minutes)...
[DEBUG] Using HuggingFace Hub API with wget fallback
[SUCCESS] Model downloaded to: /workspace/partfield/model/model_objaverse.ckpt
[SUCCESS] Model checkpoint ready (298M)
[DEBUG] Model file: /workspace/partfield/model/model_objaverse.ckpt
[DEBUG] Size: 297 MB

========================================
PHASE 6: Verifying Installation
========================================

[INFO] Testing critical imports...
[DEBUG] Starting import verification...

[INFO] Checking core dependencies...
[SUCCESS] PyTorch: 2.4.0+cu124
[SUCCESS] torch-scatter: 2.1.2
[SUCCESS] Lightning: 2.2.0
[SUCCESS] Gradio: 4.44.0

[INFO] Checking 3D processing libraries...
[SUCCESS] trimesh: 4.0.10
[SUCCESS] Open3D: 0.18.0
[SUCCESS] mesh2sdf: 0.1.0
[SUCCESS] pymeshlab: 2023.12

[INFO] Checking additional dependencies...
[SUCCESS] h5py: 3.10.0
[SUCCESS] yacs: 0.1.8
[SUCCESS] scipy: 1.12.0
[SUCCESS] scikit-learn: 1.4.0

[INFO] Checking GPU availability...
[SUCCESS] GPU detected: NVIDIA L4
[INFO] CUDA version: 12.4
[INFO] VRAM: 22.5 GB

[SUCCESS] All 12 critical packages imported successfully
[SUCCESS] Installation verification PASSED

[SUCCESS] Verification complete - all packages working correctly

========================================
Installation Complete!
========================================

[SUCCESS] PartField is ready to use!

  Conda env: /workspace/miniconda3/envs/partfield
  Repository: /workspace/partfield
  Model: /workspace/partfield/model/model_objaverse.ckpt

  Next: bash /opt/partfield/start.sh

```

**Total : ~80 lignes** au lieu de **400+ lignes** ! 🎉

---

*Cette approche rend les logs 80% plus courts tout en gardant toutes les informations importantes et les erreurs complètes.*
