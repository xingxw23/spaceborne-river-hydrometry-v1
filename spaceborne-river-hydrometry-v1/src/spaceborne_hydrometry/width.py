"""Centerline reconstruction and orthogonal river-width retrieval.
Author: Xuanwei Xing
"""
from dataclasses import dataclass
import numpy as np
import pandas as pd
import networkx as nx
from skimage.morphology import skeletonize
from scipy import ndimage as ndi

@dataclass(frozen=True)
class WidthConfig:
    centerline_spacing_pixels: float = 10.0
    transect_half_length_pixels: float = 45.0
    tangent_window: int = 4
    minimum_width_pixels: float = 2.0
    branch_pruning_iterations: int = 6

def _prune(skel,iters):
    s=skel.copy()
    kernel=np.ones((3,3),int)
    for _ in range(iters):
        n=ndi.convolve(s.astype(int),kernel)-s.astype(int)
        ends=s & (n<=1)
        if not ends.any(): break
        s[ends]=False
    return s

def _ordered_longest_path(skel):
    coords={tuple(x) for x in np.argwhere(skel)}
    if len(coords)<2: raise ValueError("Insufficient skeleton pixels.")
    g=nx.Graph()
    offs=[(i,j) for i in (-1,0,1) for j in (-1,0,1) if (i,j)!=(0,0)]
    for p in coords:
        for di,dj in offs:
            q=(p[0]+di,p[1]+dj)
            if q in coords: g.add_edge(p,q,weight=float(np.hypot(di,dj)))
    comp=max(nx.connected_components(g),key=len)
    h=g.subgraph(comp).copy()
    start=next(iter(h))
    d=nx.single_source_dijkstra_path_length(h,start,weight="weight")
    a=max(d,key=d.get)
    d=nx.single_source_dijkstra_path_length(h,a,weight="weight")
    b=max(d,key=d.get)
    return np.asarray(nx.shortest_path(h,a,b,weight="weight"),float)

def _resample(points,spacing):
    seg=np.linalg.norm(np.diff(points,axis=0),axis=1)
    s=np.r_[0,np.cumsum(seg)]
    target=np.arange(0,s[-1]+spacing,spacing)
    return np.c_[np.interp(target,s,points[:,0]),
                 np.interp(target,s,points[:,1])]

def extract_centerline(river_mask,config=None):
    cfg=config or WidthConfig()
    skel=_prune(skeletonize(np.asarray(river_mask,bool)),
                cfg.branch_pruning_iterations)
    return _resample(_ordered_longest_path(skel),
                     cfg.centerline_spacing_pixels), skel

def measure_widths(river_mask,centerline,pixel_size=1.0,config=None):
    cfg=config or WidthConfig()
    mask=np.asarray(river_mask,bool)
    pts=np.asarray(centerline,float)
    records=[]
    for i,c in enumerate(pts):
        l=max(0,i-cfg.tangent_window); r=min(len(pts)-1,i+cfg.tangent_window)
        t=pts[r]-pts[l]
        if np.linalg.norm(t)==0: continue
        t=t/np.linalg.norm(t); n=np.array([-t[1],t[0]])
        u=np.arange(-cfg.transect_half_length_pixels,
                    cfg.transect_half_length_pixels+0.25,0.25)
        line=c[None,:]+u[:,None]*n[None,:]
        rr=np.rint(line[:,0]).astype(int); cc=np.rint(line[:,1]).astype(int)
        valid=(rr>=0)&(rr<mask.shape[0])&(cc>=0)&(cc<mask.shape[1])
        inside=np.zeros(len(line),bool); inside[valid]=mask[rr[valid],cc[valid]]
        mid=len(line)//2
        if not inside[mid]: continue
        a=mid; b=mid
        while a>0 and inside[a-1]: a-=1
        while b<len(line)-1 and inside[b+1]: b+=1
        wp=float(np.linalg.norm(line[b]-line[a]))
        if wp<cfg.minimum_width_pixels: continue
        records.append(dict(point_id=i,row=float(c[0]),col=float(c[1]),
            width_pixels=wp,width=wp*pixel_size,
            bank1_row=float(line[a,0]),bank1_col=float(line[a,1]),
            bank2_row=float(line[b,0]),bank2_col=float(line[b,1])))
    return pd.DataFrame(records)
