"""Multisource raster harmonization.
Author: Xuanwei Xing
"""
from dataclasses import dataclass
import numpy as np
from scipy.ndimage import zoom

@dataclass(frozen=True)
class FusionResult:
    stack: np.ndarray
    names: tuple[str,...]

def robust_normalize(array,lower=2,upper=98):
    a=np.asarray(array,float); ok=np.isfinite(a)
    lo,hi=np.nanpercentile(a[ok],[lower,upper])
    if hi<=lo: return np.zeros_like(a)
    out=np.clip((a-lo)/(hi-lo),0,1); out[~ok]=np.nan
    return out

def resample_to_shape(array,target_shape,order=1):
    a=np.asarray(array,float)
    return zoom(a,(target_shape[0]/a.shape[0],target_shape[1]/a.shape[1]),order=order)

def build_predictor_stack(layers,normalize=True):
    shapes={np.asarray(v).shape for v in layers.values()}
    if len(shapes)!=1: raise ValueError("Predictor rasters must share one shape.")
    names=tuple(layers)
    arrays=[robust_normalize(layers[n]) if normalize else np.asarray(layers[n])
            for n in names]
    return FusionResult(np.stack(arrays,axis=-1),names)
