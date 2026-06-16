"""Soil-moisture-constrained connection of fragmented river surfaces.
Author: Xuanwei Xing
"""
from dataclasses import dataclass
from itertools import combinations
import numpy as np
from scipy import ndimage as ndi
from skimage.graph import route_through_array
from skimage.morphology import remove_small_objects

@dataclass(frozen=True)
class ConnectivityConfig:
    soil_moisture_threshold: float = 0.24
    maximum_gap_pixels: int = 30
    minimum_component_pixels: int = 8
    outside_corridor_cost: float = 1e4
    moisture_weight: float = 4.0

def _boundaries(mask):
    lab,n=ndi.label(mask,np.ones((3,3),int))
    out={}
    for i in range(1,n+1):
        comp=lab==i
        edge=comp & ~ndi.binary_erosion(comp,np.ones((3,3)))
        out[i]=np.argwhere(edge)
    return out

def _closest(a,b):
    best=(None,None,np.inf)
    for aa in np.array_split(a,max(1,len(a)//1500+1)):
        d2=((aa[:,None,:]-b[None,:,:])**2).sum(2)
        ij=np.unravel_index(np.argmin(d2),d2.shape)
        d=float(np.sqrt(d2[ij]))
        if d<best[2]:
            best=(aa[ij[0]],b[ij[1]],d)
    return best

def connect_fragmented_water(water_mask, soil_moisture, channel_corridor,
                             config=None):
    """Connect only wet gaps located inside a predefined channel corridor."""
    cfg=config or ConnectivityConfig()
    water=remove_small_objects(np.asarray(water_mask,bool),
        min_size=cfg.minimum_component_pixels,connectivity=2)
    moisture=np.asarray(soil_moisture,float)
    corridor=np.asarray(channel_corridor,bool)
    if not (water.shape==moisture.shape==corridor.shape):
        raise ValueError("All rasters must share the same shape.")

    wet=moisture>=cfg.soil_moisture_threshold
    deficit=np.maximum(cfg.soil_moisture_threshold-moisture,0)
    cost=1+cfg.moisture_weight*deficit
    cost=np.where(water,0.01,cost)
    cost=np.where(corridor & (wet|water),cost,cfg.outside_corridor_cost)

    bounds=_boundaries(water)
    candidates=[]
    for i,j in combinations(bounds,2):
        a,b,d=_closest(bounds[i],bounds[j])
        if d<=cfg.maximum_gap_pixels:
            candidates.append((d,i,j,a,b))
    candidates.sort(key=lambda x:x[0])

    connected=water.copy()
    diagnostics=[]
    for d,i,j,a,b in candidates:
        labels,_=ndi.label(connected,np.ones((3,3),int))
        if labels[tuple(a)]==labels[tuple(b)]:
            continue
        path,total=route_through_array(cost,tuple(a),tuple(b),
                                       fully_connected=True,geometric=True)
        p=np.asarray(path,int)
        valid=corridor[p[:,0],p[:,1]]
        wet_path=wet[p[:,0],p[:,1]] | connected[p[:,0],p[:,1]]
        if np.all(valid) and np.all(wet_path):
            connected[p[:,0],p[:,1]]=True
            diagnostics.append({
                "component_a":i,"component_b":j,
                "gap_pixels":d,"path_pixels":len(path),
                "path_cost":float(total)
            })
    return connected, diagnostics
