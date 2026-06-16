"""River-network topology utilities.
Author: Xuanwei Xing
"""
import networkx as nx
import numpy as np
import pandas as pd

def build_river_graph(segments,segment_id="segment_id",downstream_id="downstream_id"):
    g=nx.DiGraph()
    for record in segments.to_dict("records"):
        sid=record[segment_id]; did=record.get(downstream_id)
        g.add_node(sid,**record)
        if pd.notna(did): g.add_edge(sid,did)
    if not nx.is_directed_acyclic_graph(g):
        raise ValueError("River network contains a directed cycle.")
    return g

def upstream_segments(graph,segment):
    return nx.ancestors(graph,segment)

def downstream_path(graph,segment):
    path=[segment]
    while True:
        s=list(graph.successors(path[-1]))
        if not s: return path
        if len(s)>1: raise ValueError("Multiple downstream successors found.")
        path.append(s[0])

def assign_network_zone(stream_order,upstream_max=3,transition_max=6):
    o=np.asarray(stream_order)
    return np.select([o<=upstream_max,(o>upstream_max)&(o<=transition_max)],
                     ["upstream","transition"],default="downstream")

def summarize_by_zone(table,value_column,order_column="stream_order"):
    d=table.copy()
    d["network_zone"]=assign_network_zone(d[order_column])
    return d.groupby("network_zone")[value_column].agg(
        ["count","mean","median","std","min","max"]).reset_index()
