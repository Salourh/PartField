import trimesh
import numpy as np

def load_mesh_util(input_fname):
    mesh = trimesh.load(input_fname, force='mesh', process=False)
    return mesh


def extract_uv_data(mesh):
    """
    Extract UV coordinates from a trimesh mesh.

    Parameters:
        mesh: trimesh.Trimesh object

    Returns:
        tuple: (uv_coords, uv_type) where:
            - uv_coords: numpy array of UV coordinates or None if not available
            - uv_type: 'per-vertex' or None if not available
    """
    if mesh.visual is None:
        return None, None

    # Check for TextureVisuals with UV coordinates
    if hasattr(mesh.visual, 'uv') and mesh.visual.uv is not None:
        uv = mesh.visual.uv
        if uv.shape[0] > 0:
            return np.array(uv), 'per-vertex'

    return None, None