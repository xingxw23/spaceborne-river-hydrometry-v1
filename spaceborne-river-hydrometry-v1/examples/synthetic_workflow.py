"""Runnable synthetic demonstration.
Author: Xuanwei Xing
"""
from pathlib import Path
import yaml
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from spaceborne_hydrometry.connectivity import ConnectivityConfig, connect_fragmented_water
from spaceborne_hydrometry.width import WidthConfig, extract_centerline, measure_widths
from spaceborne_hydrometry.bathymetry import fit_cross_section, wetted_geometry, bathymetric_factor
from spaceborne_hydrometry.smcbam import SMCBAMParameters, estimate_discharge
from spaceborne_hydrometry.evaluation import regression_metrics

def synthetic_scene(shape=(260,180),seed=42):
    rng=np.random.default_rng(seed)
    rows,cols=np.indices(shape)
    center=shape[1]*0.5+28*np.sin(rows/35)+8*np.sin(rows/11)
    width=4+7*(rows/shape[0])
    distance=np.abs(cols-center)
    full=distance<=width
    fragmented=full.copy()
    for a,b in [(38,52),(92,108),(154,168),(210,224)]:
        fragmented[a:b]=False
    corridor=distance<=width+13
    moisture=np.clip(0.14+0.22*np.exp(-(distance/(width+8))**2)
                     +0.02*rng.standard_normal(shape),0.05,0.45)
    return fragmented,corridor,moisture

def main():
    repo=Path(__file__).resolve().parents[1]
    out=repo/"outputs"/"synthetic_demo"; out.mkdir(parents=True,exist_ok=True)
    cfg=yaml.safe_load((repo/"configs"/"example_config.yaml").read_text())

    water,corridor,moisture=synthetic_scene()
    connected,links=connect_fragmented_water(
        water,moisture,corridor,ConnectivityConfig(**cfg["connectivity"]))
    centerline,skeleton=extract_centerline(
        connected,WidthConfig(**cfg["width"]))
    widths=measure_widths(connected,centerline,pixel_size=10.0,
                          config=WidthConfig(**cfg["width"]))

    x=np.linspace(-24,24,31)
    z=100+0.0065*x**2+0.00003*x**3+0.025*np.sin(x/3.5)
    fit=fit_cross_section(x,z)
    water_level=101.15
    geom=wetted_geometry(fit.x_fitted,fit.z_fitted,water_level)
    fb=bathymetric_factor(geom["area"],geom["width"],geom["maximum_depth"])

    p=SMCBAMParameters(**cfg["smcbam"],bathymetric_factor=fb)
    mean_m=float(np.nanmean(moisture[connected]))
    q=estimate_discharge(widths["width"].to_numpy(),
                         np.full(len(widths),mean_m),p)
    rng=np.random.default_rng(7)
    observed=q*(1+0.06*rng.standard_normal(len(q)))
    metrics=regression_metrics(observed,q)

    widths.assign(discharge=q).to_csv(out/"width_and_discharge.csv",index=False)
    pd.DataFrame(links).to_csv(out/"accepted_links.csv",index=False)
    pd.DataFrame([metrics]).to_csv(out/"metrics.csv",index=False)

    fig,ax=plt.subplots(1,3,figsize=(12,5),constrained_layout=True)
    ax[0].imshow(water,cmap="Blues"); ax[0].set_title("Fragmented surface")
    ax[1].imshow(moisture,cmap="viridis"); ax[1].set_title("Soil moisture")
    ax[2].imshow(connected,cmap="Blues")
    ax[2].plot(centerline[:,1],centerline[:,0],linewidth=1)
    ax[2].set_title("Connected river")
    for a in ax: a.set_axis_off()
    fig.savefig(out/"connectivity.png",dpi=300); plt.close(fig)

    fig,ax=plt.subplots(figsize=(5,7),constrained_layout=True)
    ax.imshow(connected,cmap="Blues")
    ax.plot(centerline[:,1],centerline[:,0],linewidth=1)
    step=max(len(widths)//15,1)
    for row in widths.iloc[::step].itertuples():
        ax.plot([row.bank1_col,row.bank2_col],[row.bank1_row,row.bank2_row],linewidth=.8)
    ax.set_axis_off(); ax.set_title("Width transects")
    fig.savefig(out/"widths.png",dpi=300); plt.close(fig)

    fig,ax=plt.subplots(figsize=(6,4),constrained_layout=True)
    ax.scatter(x,z,label="Observed profile")
    ax.plot(fit.x_fitted,fit.z_fitted,label=fit.model_name)
    ax.axhline(water_level,linestyle="--",label="Water level")
    ax.set_xlabel("Cross-channel distance"); ax.set_ylabel("Elevation"); ax.legend()
    fig.savefig(out/"bathymetry.png",dpi=300); plt.close(fig)

    print("Completed synthetic workflow")
    print("Accepted links:",len(links))
    print("Measured widths:",len(widths))
    print("Bathymetric factor:",round(fb,4))
    print(metrics)

if __name__=="__main__":
    main()
