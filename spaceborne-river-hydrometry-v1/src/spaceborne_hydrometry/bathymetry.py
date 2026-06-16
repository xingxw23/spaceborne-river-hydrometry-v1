"""Low-flow cross-section fitting and bathymetric correction.
Author: Xuanwei Xing
"""
from dataclasses import dataclass
import numpy as np

@dataclass(frozen=True)
class CrossSectionFit:
    model_name: str
    coefficients: np.ndarray
    x_fitted: np.ndarray
    z_fitted: np.ndarray
    rmse: float
    r2: float

def fit_cross_section(x,elevation,candidate_models=("quadratic","cubic","piecewise_linear"),
                      dense_points=500):
    x=np.asarray(x,float); z=np.asarray(elevation,float)
    ok=np.isfinite(x)&np.isfinite(z); x=x[ok]; z=z[ok]
    order=np.argsort(x); x=x[order]; z=z[order]
    xd=np.linspace(x.min(),x.max(),dense_points)
    fits=[]
    for name in candidate_models:
        if name=="quadratic":
            coef=np.polyfit(x,z,2); zh=np.polyval(coef,x); zd=np.polyval(coef,xd)
        elif name=="cubic":
            coef=np.polyfit(x,z,3); zh=np.polyval(coef,x); zd=np.polyval(coef,xd)
        elif name=="piecewise_linear":
            coef=np.c_[x,z].ravel(); zh=z.copy(); zd=np.interp(xd,x,z)
        else:
            raise ValueError(f"Unsupported model: {name}")
        rmse=float(np.sqrt(np.mean((z-zh)**2)))
        den=np.sum((z-z.mean())**2)
        r2=float(1-np.sum((z-zh)**2)/den) if den>0 else np.nan
        fits.append(CrossSectionFit(name,np.asarray(coef),xd,zd,rmse,r2))
    return min(fits,key=lambda f:f.rmse)

def wetted_geometry(x,bed_elevation,water_level):
    x=np.asarray(x,float); z=np.asarray(bed_elevation,float)
    depth=np.maximum(water_level-z,0)
    wet=depth>0
    if wet.sum()<2: return {"area":0.0,"width":0.0,"maximum_depth":0.0}
    area=float(np.trapz(depth,x))
    width=float(x[wet].max()-x[wet].min())
    return {"area":area,"width":width,"maximum_depth":float(depth.max())}

def bathymetric_factor(area,width,maximum_depth):
    den=width*maximum_depth
    if den<=0: raise ValueError("Positive width and depth are required.")
    return float(area/den)
