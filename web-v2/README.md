# Spaceborne River Hydrometry Web v2

Product-style frontend for the Loess Plateau river-network hydrometry platform.

## Stack

- Next.js 16 + React 19 + TypeScript
- MapLibre GL JS for interactive river-network maps
- deck.gl for large geospatial layers and future animation layers
- Apache ECharts for linked hydrometric charts
- Framer Motion for page, drawer, card, and selection transitions

## Local development

```bash
cd web-v2
npm install
npm run dev
```

Open `http://localhost:3000`.

## Data endpoint

The frontend uses the existing compact public hydrometry dataset. Override the default endpoint with:

```bash
NEXT_PUBLIC_DATA_BASE_URL=https://your-data-host.example/data
```

Copy `.env.example` to `.env.local` for local development when needed.

## Current implementation

The first v2 milestone provides:

- product-style application shell and responsive sidebar;
- research dashboard and manuscript-facing summary metrics;
- interactive MapLibre basemap;
- river-network GeoJSON layer;
- 500 m virtual hydrometric section layer;
- click-to-select section state and map highlight;
- shared temporal-controller visual scaffold;
- responsive desktop/tablet/mobile layout.

## Planned migration sequence

1. Runoff Explorer with monthly animation and shared date state.
2. Monthly River Grid with hover tooltips and right-side detail drawer.
3. Virtual Gauge Network with section-level width, stage, discharge and flow state.
4. Linked hydrograph and cross-section charts using ECharts.
5. Long-term Dynamics story view for upstream recovery and downstream depletion.
6. Data/download and methodology views.

The legacy Streamlit application remains untouched and can continue to serve the existing public deployment while v2 is developed and validated.
