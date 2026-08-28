"use client";

import { useEffect, useRef, useState } from "react";
import maplibregl, { Map as MapLibreMap } from "maplibre-gl";

const DATA_BASE =
  process.env.NEXT_PUBLIC_DATA_BASE_URL?.replace(/\/$/, "") ||
  "https://loess-plateau-hydrometry.xingxuanwei.chatgpt.site/data";

interface HydrometryMapProps {
  selectedSection?: string | null;
  onSelectSection?: (sectionId: string) => void;
}

export function HydrometryMap({ selectedSection, onSelectSection }: HydrometryMapProps) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<MapLibreMap | null>(null);
  const [status, setStatus] = useState("Loading river network…");

  useEffect(() => {
    if (!containerRef.current || mapRef.current) return;

    const map = new maplibregl.Map({
      container: containerRef.current,
      style: "https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json",
      center: [108.4, 37.7],
      zoom: 5.15,
      attributionControl: false,
    });

    mapRef.current = map;
    map.addControl(new maplibregl.NavigationControl({ visualizePitch: true }), "bottom-left");
    map.addControl(new maplibregl.AttributionControl({ compact: true }), "bottom-right");

    map.on("load", async () => {
      try {
        const [riversResponse, sectionsResponse] = await Promise.all([
          fetch(`${DATA_BASE}/network/river_network.geojson`),
          fetch(`${DATA_BASE}/network/sections.geojson`),
        ]);

        if (!riversResponse.ok) throw new Error(`River network: ${riversResponse.status}`);
        if (!sectionsResponse.ok) throw new Error(`Sections: ${sectionsResponse.status}`);

        const rivers = await riversResponse.json();
        const sections = await sectionsResponse.json();

        map.addSource("rivers", { type: "geojson", data: rivers });
        map.addLayer({
          id: "river-glow",
          type: "line",
          source: "rivers",
          paint: {
            "line-color": "#22d3ee",
            "line-width": ["interpolate", ["linear"], ["zoom"], 4, 0.65, 8, 2.3],
            "line-opacity": 0.18,
            "line-blur": 2.4,
          },
        });
        map.addLayer({
          id: "river-network",
          type: "line",
          source: "rivers",
          paint: {
            "line-color": [
              "interpolate",
              ["linear"],
              ["coalesce", ["to-number", ["get", "stream_order"]], 2],
              1,
              "#547182",
              4,
              "#14b8a6",
              7,
              "#22d3ee",
              10,
              "#7dd3fc",
            ],
            "line-width": [
              "interpolate",
              ["linear"],
              ["coalesce", ["to-number", ["get", "stream_order"]], 2],
              1,
              0.6,
              10,
              2.7,
            ],
            "line-opacity": 0.82,
          },
        });

        map.addSource("sections", {
          type: "geojson",
          data: sections,
        });
        map.addLayer({
          id: "sections-points",
          type: "circle",
          source: "sections",
          minzoom: 6,
          paint: {
            "circle-radius": ["interpolate", ["linear"], ["zoom"], 6, 1.2, 10, 3.1],
            "circle-color": "#fb7185",
            "circle-opacity": 0.72,
            "circle-stroke-width": 0.5,
            "circle-stroke-color": "#07111c",
          },
        });
        map.addLayer({
          id: "selected-section",
          type: "circle",
          source: "sections",
          filter: ["==", ["get", "section_id"], selectedSection || "__none__"],
          paint: {
            "circle-radius": 8,
            "circle-color": "#f5e89a",
            "circle-stroke-width": 5,
            "circle-stroke-color": "rgba(34,211,238,0.24)",
          },
        });

        map.on("mouseenter", "sections-points", () => {
          map.getCanvas().style.cursor = "pointer";
        });
        map.on("mouseleave", "sections-points", () => {
          map.getCanvas().style.cursor = "";
        });
        map.on("click", "sections-points", (event) => {
          const feature = event.features?.[0];
          const id = feature?.properties?.section_id;
          if (id && onSelectSection) onSelectSection(String(id));
        });

        setStatus("");
      } catch (error) {
        console.error(error);
        setStatus("Basemap loaded. Hydrometry layers could not be fetched from the public data endpoint.");
      }
    });

    return () => {
      map.remove();
      mapRef.current = null;
    };
  }, [onSelectSection]);

  useEffect(() => {
    const map = mapRef.current;
    if (!map || !map.getLayer("selected-section")) return;
    map.setFilter("selected-section", [
      "==",
      ["get", "section_id"],
      selectedSection || "__none__",
    ]);
  }, [selectedSection]);

  return (
    <div className="map-wrap">
      <div ref={containerRef} style={{ position: "absolute", inset: 0 }} />
      {status ? <div className="map-loading">{status}</div> : null}
      <div className="map-overlay">
        <div className="map-chip">HSRLP · connected river-network observation</div>
        <div className="map-chip">500 m virtual hydrometric sections</div>
      </div>
      <div className="map-legend">
        <strong>River network</strong>
        <div className="legend-ramp" />
        <div className="legend-labels"><span>Low order</span><span>High order</span></div>
      </div>
    </div>
  );
}
