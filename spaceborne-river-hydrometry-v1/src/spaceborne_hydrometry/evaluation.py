"""Hydrological accuracy metrics.
Author: Xuanwei Xing
"""
import numpy as np
import pandas as pd

def regression_metrics(observed,estimated):
    o=np.asarray(observed,float); e=np.asarray(estimated,float)
    ok=np.isfinite(o)&np.isfinite(e); o=o[ok]; e=e[ok]
    if len(o)<2: raise ValueError("At least two valid pairs are required.")
    r=e-o
    den=np.sum((o-o.mean())**2)
    corr=np.corrcoef(o,e)[0,1]
    return {
        "n":int(len(o)),
        "r2":float(corr**2) if np.isfinite(corr) else np.nan,
        "rmse":float(np.sqrt(np.mean(r**2))),
        "mae":float(np.mean(np.abs(r))),
        "nse":float(1-np.sum(r**2)/den) if den>0 else np.nan,
        "pbias":float(100*np.sum(r)/np.sum(o)) if np.sum(o)!=0 else np.nan
    }

def metrics_table(observed,predictions):
    rows=[]
    for name,pred in predictions.items():
        row={"method":name}; row.update(regression_metrics(observed,pred)); rows.append(row)
    return pd.DataFrame(rows)
