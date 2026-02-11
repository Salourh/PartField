# PartField RunPod - Guide de Dépannage

Ce guide vous aide à diagnostiquer et résoudre les problèmes courants lors du déploiement de PartField sur RunPod.

## Table des matières

- [Script de Diagnostic](#script-de-diagnostic)
- [Problèmes Courants](#problèmes-courants)
- [Logs et Debugging](#logs-et-debugging)
- [Récupération d'Erreurs](#récupération-derreurs)

---

## Script de Diagnostic

### Utilisation

Si vous rencontrez un problème, commencez par exécuter le script de diagnostic :

```bash
bash /opt/partfield/diagnose.sh
```

Ce script vérifie automatiquement :
- ✓ Informations système et GPU
- ✓ État de l'installation
- ✓ Présence du repository et des fichiers critiques
- ✓ Téléchargement du modèle
- ✓ Environnement Python et packages pip
- ✓ Connectivité réseau
- ✓ Processus en cours d'exécution

**Sortie attendue** : Chaque vérification affiche `[OK]`, `[WARN]` ou `[FAIL]` avec des détails.

### Interprétation des Résultats

#### ✓ Tout est OK
Si toutes les vérifications affichent `[OK]` :
- L'installation est complète
- Essayez de relancer : `bash /opt/partfield/start.sh`

#### ⚠ Warnings
Les warnings sont généralement non-critiques mais indiquent des problèmes potentiels.

#### ✗ Failures
Les erreurs nécessitent une action. Voir [Problèmes Courants](#problèmes-courants) ci-dessous.

---

## Problèmes Courants

### 1. Installation Marker Manquant

**Symptôme** :
```
[FAIL] Installation marker NOT found at /workspace/.partfield_v4_installed
```

**Cause** : L'installation n'a jamais été exécutée ou a échoué.

**Solution** :
```bash
bash /opt/partfield/install.sh
```

**Temps attendu** : 5-8 minutes lors de la première installation.

---

### 2. Model Checkpoint Manquant

**Symptôme** :
```
[FAIL] Model checkpoint NOT found: /workspace/partfield/model/model_objaverse.ckpt
```

**Cause** : Le téléchargement du modèle a échoué (problème réseau ou HuggingFace indisponible).

**Solution 1 - Réexécuter l'installation** :
```bash
rm /workspace/.partfield_v4_installed
bash /opt/partfield/install.sh
```

**Solution 2 - Téléchargement manuel** :
```bash
cd /workspace/partfield
mkdir -p model
wget -O model/model_objaverse.ckpt \
  https://huggingface.co/mikaelaangel/partfield-ckpt/resolve/main/model_objaverse.ckpt
```

**Vérification** :
```bash
ls -lh /workspace/partfield/model/model_objaverse.ckpt
# Doit afficher ~300MB
```

---

### 3. Packages Python Manquants

**Symptôme** :
```
✗ PyTorch: FAILED - No module named 'torch'
```

**Cause** : Les dépendances n'ont pas été installées correctement.

**Diagnostic** :
```bash
# Vérifier les packages installés
pip list | grep torch
pip list | grep gradio
```

**Solution si packages manquants** :
```bash
# Réinstaller les dépendances critiques
pip install torch==2.4.0 torchvision==0.19.0 torchaudio==2.4.0 \
  --index-url https://download.pytorch.org/whl/cu124

pip install lightning==2.2.0 gradio huggingface_hub
```

**Solution complète** :
```bash
rm /workspace/.partfield_v4_installed
bash /opt/partfield/install.sh
```

---

### 4. GPU Non Détecté

**Symptôme** :
```
[WARN] No GPU detected
```
ou
```
✗ No GPU detected in PyTorch
```

**Diagnostic** :
```bash
# Vérifier que le GPU est assigné
nvidia-smi

# Vérifier CUDA dans PyTorch
python3 -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}')"
```

**Solutions** :

1. **GPU non assigné au pod** :
   - Vérifier dans RunPod Console que le GPU est bien assigné
   - Redémarrer le pod
   - Recréer le pod avec un GPU

2. **Driver NVIDIA manquant** :
   - Vérifier que l'image Docker est correcte : `nvcr.io/nvidia/pytorch:24.05-py3`
   - Contacter le support RunPod si le problème persiste

3. **PyTorch sans support CUDA** :
   ```bash
   # Réinstaller PyTorch avec CUDA
   pip uninstall torch torchvision torchaudio -y
   pip install torch==2.4.0 torchvision==0.19.0 torchaudio==2.4.0 \
     --index-url https://download.pytorch.org/whl/cu124
   ```

---

### 5. Gradio Ne Démarre Pas

**Symptôme** :
```
[ERROR] gradio_app.py not found in /workspace/partfield
```
ou
```
Gradio exited with code 1
```

**Diagnostic** :
```bash
# Vérifier que le repository existe
ls -la /workspace/partfield/

# Vérifier que gradio_app.py existe
ls -la /workspace/partfield/gradio_app.py

# Vérifier les imports
cd /workspace/partfield
python3 -c "import gradio; print('Gradio OK')"
```

**Solution si repository manquant** :
```bash
cd /workspace
git clone https://github.com/Salourh/PartField.git partfield
```

**Solution si imports échouent** :
Réexécuter l'installation (voir problème #3).

**Logs détaillés** :
```bash
cd /workspace/partfield
python3 gradio_app.py --port 7860 --jobs-dir /workspace/jobs
# Regarder les erreurs affichées
```

---

### 6. Erreur "Out of Memory" (OOM)

**Symptôme** :
```
RuntimeError: CUDA out of memory
```

**Cause** : Le modèle 3D est trop complexe ou les paramètres trop élevés pour le GPU.

**Solutions** :

1. **Réduire les paramètres dans Gradio** :
   - `points_per_face`: 2000 → 1000 ou 500
   - `features_per_sample`: 10000 → 5000
   - `n_clusters`: Réduire si possible

2. **Vider le cache GPU** :
   ```bash
   python3 -c "import torch; torch.cuda.empty_cache()"
   ```

3. **Redémarrer Gradio** :
   ```bash
   # Arrêter Gradio (Ctrl+C dans le terminal)
   bash /opt/partfield/start.sh
   ```

4. **Utiliser un GPU plus puissant** :
   - Passer à un GPU avec plus de VRAM (A100 40GB/80GB)
   - Voir [GPU Recommendations](README_RUNPOD.md#gpu-recommendations)

---

### 7. Port 7860 Non Accessible

**Symptôme** : Impossible d'accéder à l'interface Gradio via le navigateur.

**Diagnostic** :
```bash
# Vérifier que Gradio écoute sur le port
netstat -tuln | grep 7860

# Vérifier que le processus Gradio tourne
ps aux | grep gradio_app.py

# Tester en local
curl http://localhost:7860
```

**Solutions** :

1. **Gradio ne tourne pas** :
   ```bash
   bash /opt/partfield/start.sh
   ```

2. **Port mapping incorrect dans RunPod** :
   - Vérifier dans RunPod Console → Pod → Connect
   - Le port 7860 doit être exposé
   - URL correcte : `https://<pod-id>-7860.proxy.runpod.net`

3. **Firewall ou proxy** :
   - Vérifier les paramètres réseau RunPod
   - Essayer de recréer le pod

---

### 8. Problèmes de Connectivité Réseau

**Symptôme** :
```
[FAIL] Cannot reach HuggingFace
```
ou erreurs lors du téléchargement de packages/modèles.

**Diagnostic** :
```bash
# Tester la connectivité
ping -c 3 8.8.8.8
ping -c 3 huggingface.co

# Tester avec curl
curl -I https://huggingface.co
curl -I https://download.pytorch.org
```

**Solutions** :

1. **Problème temporaire** : Attendre quelques minutes et réessayer

2. **Proxy ou firewall** :
   - Vérifier les paramètres réseau du pod
   - Contacter le support RunPod

3. **Utiliser des téléchargements alternatifs** :
   Pour le modèle :
   ```bash
   # Utiliser wget au lieu de HuggingFace Hub
   wget -O /workspace/partfield/model/model_objaverse.ckpt \
     https://huggingface.co/mikaelaangel/partfield-ckpt/resolve/main/model_objaverse.ckpt
   ```

---

## Logs et Debugging

### Activer les Logs de Debug

Les scripts `install.sh` et `start.sh` affichent maintenant des logs `[DEBUG]` détaillés.

Pour voir tous les logs lors de l'exécution :
```bash
bash /opt/partfield/install.sh 2>&1 | tee install.log
bash /opt/partfield/start.sh 2>&1 | tee start.log
```

### Logs Gradio

Gradio affiche ses logs dans la console. Pour sauvegarder :
```bash
python3 /workspace/partfield/gradio_app.py --port 7860 --jobs-dir /workspace/jobs 2>&1 | tee gradio.log
```

### Vérification Manuelle des Composants

#### 1. Python et Packages
```bash
python3 --version
pip list | head -20
python3 -c "import torch; print(torch.__version__); print(torch.cuda.is_available())"
```

#### 2. GPU
```bash
nvidia-smi
python3 -c "import torch; print(f'GPU: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"None\"}')"
```

#### 3. Fichiers Critiques
```bash
ls -lh /workspace/.partfield_v4_installed
ls -lh /workspace/partfield/gradio_app.py
ls -lh /workspace/partfield/model/model_objaverse.ckpt
ls -lh /workspace/partfield/configs/final/demo.yaml
```

---

## Récupération d'Erreurs

### Réinstallation Complète

Si tout le reste échoue, réinstallation complète :

```bash
# 1. Supprimer toutes les installations
rm -f /workspace/.partfield_v4_installed
rm -rf /workspace/partfield

# 2. Réinstaller
bash /opt/partfield/install.sh

# 3. Vérifier avec le diagnostic
bash /opt/partfield/diagnose.sh

# 4. Démarrer
bash /opt/partfield/start.sh
```

**Temps total** : ~10 minutes

### Réinitialisation Partielle

Si seuls les packages Python sont corrompus :

```bash
# 1. Supprimer le marker
rm /workspace/.partfield_v4_installed

# 2. Réexécuter l'installation (réinstallera les packages pip)
bash /opt/partfield/install.sh
```

**Temps** : ~5-8 minutes

### Conservation des Données

Le dossier `/workspace/jobs/` contient les résultats de segmentation. Pour les conserver :

```bash
# Avant réinstallation
cp -r /workspace/jobs /workspace/jobs_backup

# Après réinstallation
cp -r /workspace/jobs_backup /workspace/jobs
```

---

## Support Supplémentaire

### Documentation
- [README Principal](README_RUNPOD.md)
- [Guide de Build](BUILD_ON_RUNPOD.md)
- [Repository GitHub](https://github.com/Salourh/PartField)

### Ressources RunPod
- [Documentation RunPod](https://docs.runpod.io)
- [Discord RunPod](https://discord.gg/runpod)
- Email: support@runpod.io

### Signaler un Bug

Si vous rencontrez un bug non documenté :

1. Exécuter le script de diagnostic : `bash /opt/partfield/diagnose.sh`
2. Capturer les logs : `bash /opt/partfield/start.sh 2>&1 | tee debug.log`
3. Créer une issue GitHub avec :
   - Type de GPU utilisé
   - Sortie du script de diagnostic
   - Logs complets
   - Étapes pour reproduire le problème

---

**Bon debugging !** 🔧

La plupart des problèmes peuvent être résolus en réexécutant l'installation ou en vérifiant les composants critiques avec le script de diagnostic.
