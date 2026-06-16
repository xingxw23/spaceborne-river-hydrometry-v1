"""SMCBAM discharge estimation.
Author: Xuanwei Xing
"""
from dataclasses import dataclass
import numpy as np
import pandas as pd

@dataclass(frozen=True)
class SMCBAMParameters:
    reference_width: float
    width_exponent: float
    reference_moisture: float
    moisture_exponent: float
    bankfull_width: float
    bankfull_depth: float
    shape_parameter: float
    slope: float
    mannings_n: float
    bathymetric_factor: float = 1.0
    bathymetry_exponent: float = 1.0

def corrected_geometric_factor(p):
    vals=[p.reference_width,p.width_exponent,p.bankfull_width,
          p.bankfull_depth,p.shape_parameter,p.slope,p.mannings_n,
          p.bathymetric_factor]
    if any(v<=0 for v in vals): raise ValueError("All physical parameters must be positive.")
    r=p.shape_parameter; b=p.width_exponent
    return float(
        p.bankfull_width**(5*r/(3*b))
        * p.bankfull_depth**(-5/(3*b))
        * (r/(r+1))**(-5/3)
        * p.slope**(-0.5)
        * p.mannings_n
        * p.reference_width**(-(1+5*r/3))
        * p.bathymetric_factor**p.bathymetry_exponent
    )

def estimate_discharge(width,soil_moisture,parameters,detectable_surface_water=None):
    w,m=np.broadcast_arrays(np.asarray(width,float),np.asarray(soil_moisture,float))
    if np.any(w<0) or np.any(m<0): raise ValueError("Width and moisture cannot be negative.")
    k=corrected_geometric_factor(parameters)
    p=parameters
    q=(np.maximum(w,0)/p.reference_width)**(1/p.width_exponent)
    q*=k**-1*(np.maximum(m,1e-9)/p.reference_moisture)**p.moisture_exponent
    q=np.nan_to_num(q,nan=0.0,posinf=0.0,neginf=0.0)
    if detectable_surface_water is not None:
        q=np.where(np.broadcast_to(np.asarray(detectable_surface_water,bool),q.shape),q,0.0)
    return q

def estimate_discharge_table(table,parameters,width_column="width",
                             moisture_column="soil_moisture",
                             state_column="detectable_surface_water"):
    out=table.copy()
    state=out[state_column].to_numpy() if state_column in out else None
    out["discharge"]=estimate_discharge(out[width_column],out[moisture_column],
                                        parameters,state)
    return out
