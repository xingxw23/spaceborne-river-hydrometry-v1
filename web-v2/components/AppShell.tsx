"use client";

import { motion } from "framer-motion";
import {
  Activity,
  BarChart3,
  Database,
  Github,
  Info,
  LayoutDashboard,
  Map as MapIcon,
  Network,
  RadioTower,
  Waves,
} from "lucide-react";
import { useState } from "react";
import { HydrometryMap } from "@/components/HydrometryMap";

const navItems = [
  { id: "dashboard", label: "Dashboard", icon: LayoutDashboard },
  { id: "runoff", label: "Runoff Explorer", icon: Waves },
  { id: "grid", label: "River Grid", icon: MapIcon },
  { id: "network", label: "Virtual Gauge Network", icon: Network },
  { id: "dynamics", label: "Long-term Dynamics", icon: BarChart3 },
  { id: "data", label: "Data", icon: Database },
  { id: "about", label: "About", icon: Info },
];

const metrics = [
  ["40 years", "Satellite observation era", "1984–2023 long-term reconstruction"],
  ["99,380 km", "River network mapped", "Including narrow intermittent tributaries"],
  ["69.0%", "Intermittent reaches", "12,870 of 18,640 mapped reaches"],
  ["R² 0.97", "Discharge validation", "Gauge-based network-scale evaluation"],
];

export function AppShell() {
  const [active, setActive] = useState("dashboard");
  const [selectedSection, setSelectedSection] = useState<string | null>(null);
  const activeLabel = navItems.find((item) => item.id === active)?.label ?? "Dashboard";

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="brand">
          <div className="brand-mark"><RadioTower size={18} /></div>
          <div className="brand-copy">
            <strong>RIVER HYDROMETRY</strong>
            <span>Loess Plateau · v2</span>
          </div>
        </div>

        <nav className="nav">
          {navItems.map((item) => {
            const Icon = item.icon;
            return (
              <button
                key={item.id}
                className={`nav-button ${active === item.id ? "active" : ""}`}
                onClick={() => setActive(item.id)}
              >
                <Icon />
                <span>{item.label}</span>
              </button>
            );
          })}
        </nav>

        <div className="sidebar-footer">
          <div className="online"><span className="online-dot" /> Public data online</div>
          Review-stage research explorer
        </div>
      </aside>

      <main className="main">
        <header className="topbar">
          <div>
            <div className="eyebrow">Spaceborne river-network observation</div>
            <div className="top-title">{activeLabel}</div>
          </div>
          <div className="top-actions">
            <span className="pill">1984–2023</span>
            <a
              className="icon-button"
              href="https://github.com/xingxw23/spaceborne-river-hydrometry-v1"
              target="_blank"
              rel="noreferrer"
              aria-label="GitHub repository"
            >
              <Github size={16} />
            </a>
          </div>
        </header>

        <div className="content">
          <motion.section
            className="hero-grid"
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.35 }}
          >
            <div className="hero-card">
              <div className="hero-kicker">Capturing hidden rivers from space</div>
              <h1 className="hero-title">
                Observe the <em>river network</em>, not only the gauge.
              </h1>
              <p className="hero-copy">
                Explore four decades of river-surface activation, channel geometry and discharge
                across the intermittent river network of the high-sediment Loess Plateau.
                The v2 interface is designed around connected river-network observation, with
                interactive virtual hydrometric sections and linked temporal exploration.
              </p>
              <div className="hero-actions">
                <button className="primary-btn" onClick={() => setActive("network")}>
                  Explore river network
                </button>
                <button className="secondary-btn" onClick={() => setActive("runoff")}>
                  View runoff dynamics
                </button>
              </div>
              <div className="hero-mini-grid">
                <div className="hero-mini"><strong>10 m</strong><span>river-surface products</span></div>
                <div className="hero-mini"><strong>500 m</strong><span>virtual section spacing</span></div>
                <div className="hero-mini"><strong>1–10</strong><span>Horton–Strahler orders</span></div>
                <div className="hero-mini"><strong>74</strong><span>gauge validation stations</span></div>
              </div>
            </div>

            <div className="map-card">
              <HydrometryMap
                selectedSection={selectedSection}
                onSelectSection={setSelectedSection}
              />
            </div>
          </motion.section>

          <section className="metrics">
            {metrics.map(([value, label, note], index) => (
              <motion.div
                className="metric-card"
                key={label}
                initial={{ opacity: 0, y: 8 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.08 + index * 0.04 }}
              >
                <div className="metric-label">{label}</div>
                <div className="metric-value">{value}</div>
                <div className="metric-note">{note}</div>
              </motion.div>
            ))}
          </section>

          <section className="section-grid">
            <div className="panel">
              <div className="panel-head">
                <div>
                  <div className="panel-title">Four-decade hydrometric timeline</div>
                  <div className="panel-sub">Shared temporal controller for maps, hydrographs and river state</div>
                </div>
                <span className="pill">Prototype · 2009-08</span>
              </div>
              <div className="timeline-line">
                <div className="timeline-progress" />
                <div className="timeline-thumb" />
              </div>
              <div className="timeline-years">
                <span>1984</span><span>1990</span><span>2000</span><span>2010</span><span>2020</span><span>2023</span>
              </div>
            </div>

            <div className="panel">
              <div className="panel-head">
                <div>
                  <div className="panel-title">Current selection</div>
                  <div className="panel-sub">Map clicks will drive linked section-level analytics</div>
                </div>
                <Activity size={17} color="#22d3ee" />
              </div>
              <div className="state-row"><span className="state-name">Section</span><span className="state-value">{selectedSection ?? "Select on map"}</span></div>
              <div className="state-row"><span className="state-name">Flow state</span><span className="state-value">Connected</span></div>
              <div className="state-row"><span className="state-name">Layer</span><span className="state-value">River network</span></div>
              <div className="state-row"><span className="state-name">Interaction</span><span className="state-value">Map ↔ charts</span></div>
            </div>
          </section>
        </div>
      </main>
    </div>
  );
}
