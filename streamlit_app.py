from __future__ import annotations

import gzip
import json
import os
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import streamlit as st

APP_TITLE = "Loess Plateau River Hydrometry Explorer"
DATA_DIR = Path(__file__).parent / "data"
DEFAULT_DATA_BASE_URL = "https://loess-plateau-hydrometry.xingxuanwei.chatgpt.site/data"
DATA_BASE_URL = os.environ.get("STREAMLIT_DATA_BASE_URL", "").strip().rstrip("/")
if not DATA_BASE_URL and not DATA_DIR.exists():
    DATA_BASE_URL = DEFAULT_DATA_BASE_URL
REMOTE_HEADERS = {"User-Agent": "Mozilla/5.0 Streamlit Hydrometry Explorer"}
FLOW_STATES = ["dry", "intermittent", "connected", "high_flow"]
CHUNK_SIZE = 100

st.set_page_config(page_title=APP_TITLE, layout="wide", page_icon="LP")

st.markdown(
    """
    <style>
    .stApp { background: #090d13; color: #e6edf7; }
    [data-testid="stSidebar"] { background: #0f151e; }
    h1, h2, h3 { color: #f3f7ff; letter-spacing: 0; }
    div[data-testid="stMetric"] { background: #111923; border: 1px solid #263449; padding: 14px; border-radius: 6px; }
    div[data-testid="stMetricValue"] { color: #f5f9ff; }
    .small-note { color: #9aa8bb; font-size: 0.9rem; }
    </style>
    """,
    unsafe_allow_html=True,
)


def _resolve_data_path(relative_path: str) -> Path:
    relative = relative_path.strip("/")
    direct = DATA_DIR / relative
    if direct.exists():
        return direct
    gz = DATA_DIR / f"{relative}.gz"
    if gz.exists():
        return gz
    raise FileNotFoundError(relative_path)


def _remote_data_urls(relative_path: str) -> list[str]:
    if not DATA_BASE_URL:
        return []
    relative = relative_path.strip("/")
    urls = [f"{DATA_BASE_URL}/{relative}"]
    if not relative.endswith(".gz"):
        urls.append(f"{DATA_BASE_URL}/{relative}.gz")
    return urls


def _decode_json_payload(payload: bytes, url: str, headers: Any) -> Any:
    content_encoding = headers.get("Content-Encoding", "")
    if url.endswith(".gz") or "gzip" in content_encoding.lower():
        try:
            payload = gzip.decompress(payload)
        except OSError:
            pass
    return json.loads(payload.decode("utf-8"))


def _read_remote_json(relative_path: str) -> Any:
    last_error: Exception | None = None
    for url in _remote_data_urls(relative_path):
        try:
            with urlopen(Request(url, headers=REMOTE_HEADERS), timeout=60) as response:
                return _decode_json_payload(response.read(), url, response.headers)
        except (HTTPError, URLError, TimeoutError, json.JSONDecodeError, OSError) as exc:
            last_error = exc
    if last_error:
        raise last_error
    raise FileNotFoundError(relative_path)


def _remote_data_url(relative_path: str) -> str | None:
    urls = _remote_data_urls(relative_path)
    return urls[0] if urls else None


@st.cache_data(show_spinner=False)
def read_json(relative_path: str) -> Any:
    try:
        path = _resolve_data_path(relative_path)
    except FileNotFoundError:
        return _read_remote_json(relative_path)
    else:
        if path.suffix == ".gz":
            with gzip.open(path, "rt", encoding="utf-8") as handle:
                return json.load(handle)
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)


@st.cache_data(show_spinner=False)
def load_manifests() -> tuple[dict[str, Any], dict[str, Any], dict[str, Any], dict[str, Any], dict[str, Any]]:
    return (
        read_json("runoff/runoff_manifest.json"),
        read_json("fishnet/fishnet_manifest.json"),
        read_json("network/metadata.json"),
        read_json("timeseries/hydrometry_index.json"),
        read_json("cross_sections/cross_section_templates.json"),
    )


@st.cache_data(show_spinner=False)
def load_geojson(relative_path: str) -> dict[str, Any]:
    return read_json(relative_path)


def month_label(record: dict[str, Any]) -> str:
    return record.get("label") or f"{record.get('year')}-{int(record.get('month', 1)):02d}"


def record_options(records: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    return {month_label(record): record for record in records}


def map_center(bounds: list[float] | tuple[float, float, float, float] | None) -> dict[str, float]:
    if not bounds:
        return {"lat": 38.0, "lon": 110.0}
    return {"lon": (bounds[0] + bounds[2]) / 2, "lat": (bounds[1] + bounds[3]) / 2}


def figure_layout(fig: go.Figure, height: int = 560) -> go.Figure:
    fig.update_layout(
        height=height,
        margin={"l": 10, "r": 10, "t": 32, "b": 10},
        paper_bgcolor="#090d13",
        plot_bgcolor="#090d13",
        font={"color": "#dfe8f5"},
    )
    return fig


@st.cache_data(show_spinner=False)
def fishnet_figure(year_month: str, bounds: list[float]) -> go.Figure:
    geojson = load_geojson(f"fishnet/{year_month}.geojson")
    rows = []
    for feature in geojson.get("features", []):
        props = feature.get("properties", {})
        grid_id = props.get("grid_id")
        feature["id"] = str(grid_id)
        rows.append({"grid_id": str(grid_id), "runoff": props.get("runoff")})
    frame = pd.DataFrame(rows)
    fig = px.choropleth_mapbox(
        frame,
        geojson=geojson,
        locations="grid_id",
        color="runoff",
        color_continuous_scale="Viridis",
        mapbox_style="open-street-map",
        center=map_center(bounds),
        zoom=5.4,
        opacity=0.62,
        labels={"runoff": "Runoff"},
    )
    return figure_layout(fig, 620)


@st.cache_data(show_spinner=False)
def network_figure(selected_section_id: str | None, bounds: list[float] | None) -> go.Figure:
    rivers = load_geojson("network/river_network.geojson")
    sections = load_geojson("network/sections.geojson")
    line_lon: list[float | None] = []
    line_lat: list[float | None] = []
    for feature in rivers.get("features", []):
        coords = feature.get("geometry", {}).get("coordinates", [])
        for lon, lat in coords:
            line_lon.append(lon)
            line_lat.append(lat)
        line_lon.append(None)
        line_lat.append(None)

    point_rows = []
    selected_point = None
    for feature in sections.get("features", []):
        props = feature.get("properties", {})
        coords = feature.get("geometry", {}).get("coordinates", [None, None])
        row = {
            "section_id": props.get("section_id"),
            "stream_order": props.get("stream_order"),
            "base_width_m": props.get("base_width_m"),
            "lon": coords[0],
            "lat": coords[1],
        }
        if row["section_id"] == selected_section_id:
            selected_point = row
        point_rows.append(row)

    points = pd.DataFrame(point_rows)
    fig = go.Figure()
    fig.add_trace(
        go.Scattermapbox(
            lon=line_lon,
            lat=line_lat,
            mode="lines",
            line={"width": 1.4, "color": "#5ee6df"},
            name="River centerline",
            hoverinfo="skip",
        )
    )
    fig.add_trace(
        go.Scattermapbox(
            lon=points["lon"],
            lat=points["lat"],
            mode="markers",
            marker={"size": 4, "color": "#ff3d57"},
            text=points["section_id"],
            customdata=points[["stream_order", "base_width_m"]],
            hovertemplate="%{text}<br>Stream order: %{customdata[0]}<br>Width: %{customdata[1]:.2f} m<extra></extra>",
            name="500 m section",
        )
    )
    if selected_point:
        fig.add_trace(
            go.Scattermapbox(
                lon=[selected_point["lon"]],
                lat=[selected_point["lat"]],
                mode="markers",
                marker={"size": 13, "color": "#f2d35f"},
                name="Selected section",
            )
        )
    fig.update_layout(mapbox={"style": "open-street-map", "center": map_center(bounds), "zoom": 5.3})
    return figure_layout(fig, 620)


def timeseries_chunk_name(section_id: str) -> str | None:
    try:
        numeric_id = int(section_id.split("-")[-1])
    except ValueError:
        return None
    return f"chunk_{numeric_id // CHUNK_SIZE:05d}.json"


@st.cache_data(show_spinner=False)
def load_section_timeseries(section_id: str) -> tuple[dict[str, Any] | None, pd.DataFrame]:
    chunk_name = timeseries_chunk_name(section_id)
    if not chunk_name:
        return None, pd.DataFrame()
    chunk = read_json(f"timeseries/chunks/{chunk_name}")
    compact = chunk.get("sections", {}).get(section_id)
    if not compact:
        return None, pd.DataFrame()
    start = chunk.get("start", "1984_01")
    start_year, start_month = [int(part) for part in start.split("_")]
    dates = pd.date_range(f"{start_year}-{start_month:02d}-01", periods=len(compact["c"][0]), freq="MS")
    frame = pd.DataFrame(
        {
            "date": dates,
            "stage_m": compact["c"][0],
            "wet_width_m": compact["c"][1],
            "discharge_m3s": compact["c"][2],
            "flow_state": [FLOW_STATES[int(code)] if int(code) < len(FLOW_STATES) else str(code) for code in compact["c"][3]],
        }
    )
    return compact, frame


def hydrograph(frame: pd.DataFrame) -> go.Figure:
    fig = go.Figure()
    fig.add_trace(
        go.Scatter(
            x=frame["date"],
            y=frame["discharge_m3s"],
            mode="lines",
            fill="tozeroy",
            line={"color": "#80d7ff", "width": 1.7},
            name="monthly discharge",
        )
    )
    fig.update_xaxes(title="Month", gridcolor="#26313f")
    fig.update_yaxes(title="Q (m3/s)", gridcolor="#26313f")
    return figure_layout(fig, 360)


def cross_section_figure(template: dict[str, Any] | None, stage_m: float | None) -> go.Figure:
    fig = go.Figure()
    if not template:
        fig.add_annotation(text="Cross-section unavailable", showarrow=False, font={"color": "#9ab0c8"})
        return figure_layout(fig, 360)
    x_values = template.get("x_m", [])
    bed = template.get("bed_elevation_m", [])
    fig.add_trace(go.Scatter(x=x_values, y=bed, mode="lines", name="river bed", line={"color": "#d6c38b", "width": 2}))
    fit_coefficients = template.get("fit_coefficients", [])
    fit_degree = template.get("fit_degree", 0)
    if fit_coefficients:
        fit_y = [sum(c * (x ** (fit_degree - idx)) for idx, c in enumerate(fit_coefficients)) for x in x_values]
        fig.add_trace(go.Scatter(x=x_values, y=fit_y, mode="lines", name="fit profile", line={"color": "#7fb7ff", "dash": "dot"}))
    if stage_m is not None and x_values:
        water = template.get("bed_min_m", min(bed or [0])) + stage_m
        fig.add_trace(go.Scatter(x=[min(x_values), max(x_values)], y=[water, water], mode="lines", name="water surface", line={"color": "#4fd4ff", "width": 2}))
    fig.update_xaxes(title="Distance (m)", gridcolor="#26313f")
    fig.update_yaxes(title="Elevation (m)", gridcolor="#26313f")
    return figure_layout(fig, 360)


def section_ids() -> list[str]:
    sections = load_geojson("network/sections.geojson")
    return [feature.get("properties", {}).get("section_id") for feature in sections.get("features", []) if feature.get("properties", {}).get("section_id")]


def find_template(library: dict[str, Any], template_id: str | None) -> dict[str, Any] | None:
    templates = library.get("templates", [])
    if template_id:
        for template in templates:
            if template.get("template_id") == template_id:
                return template
    return templates[0] if templates else None


runoff_manifest, fishnet_manifest, network_metadata, hydrometry_index, cross_sections = load_manifests()

st.sidebar.title("LP Hydrometry")
page = st.sidebar.radio("View", ["Overview", "Monthly Runoff", "Monthly River Grid", "Hydrometric Network", "About Data"])

if page == "Overview":
    st.title(APP_TITLE)
    st.caption("Four-decade spaceborne hydrometry of intermittent river networks across the Loess Plateau.")
    cols = st.columns(4)
    cols[0].metric("Temporal Coverage", f"{runoff_manifest['coverage'].get('min_year')}-{runoff_manifest['coverage'].get('max_year')}")
    cols[1].metric("Hydrometric Sections", f"{network_metadata.get('section_count', 0):,}")
    cols[2].metric("River Network Length", f"{network_metadata.get('total_river_length_km', 0):,.3f} km")
    cols[3].metric("Monthly Records", f"{hydrometry_index.get('record_count', 0):,}")
    st.markdown("### Data Surfaces")
    st.write("Monthly runoff overlays, monthly river-grid attributes, and a 500 m virtual hydrometric section network are available from the sidebar.")

elif page == "Monthly Runoff":
    st.title("Monthly Runoff")
    options = record_options(runoff_manifest.get("records", []))
    label = st.select_slider("Month", options=list(options.keys()), value=next(iter(options)))
    record = options[label]
    cols = st.columns(4)
    cols[0].metric("Minimum", f"{record.get('min', 0):.3f}")
    cols[1].metric("P2", f"{record.get('p2', 0):.3f}")
    cols[2].metric("P98", f"{record.get('p98', 0):.3f}")
    cols[3].metric("Maximum", f"{record.get('max', 0):.3f}")
    overlay = record.get("overlay", "")
    image_path = DATA_DIR / "runoff" / overlay
    if image_path.exists():
        st.image(str(image_path), caption=f"Runoff overlay: {label}", use_container_width=True)
    elif overlay and _remote_data_url(f"runoff/{overlay}"):
        st.image(_remote_data_url(f"runoff/{overlay}"), caption=f"Runoff overlay: {label}", use_container_width=True)
    else:
        st.warning("Runoff overlay unavailable for the selected month.")

elif page == "Monthly River Grid":
    st.title("Monthly River Grid")
    options = record_options(fishnet_manifest.get("records", []))
    label = st.select_slider("Month", options=list(options.keys()), value=next(iter(options)))
    record = options[label]
    st.plotly_chart(fishnet_figure(record["year_month"], record.get("bounds", [])), use_container_width=True)
    st.metric("Grid Cells", f"{record.get('feature_count', 0):,}")

elif page == "Hydrometric Network":
    st.title("Hydrometric Network")
    ids = section_ids()
    default_id = ids[0] if ids else ""
    selected_id = st.text_input("Section ID", value=default_id)
    if selected_id not in ids:
        st.warning("Section ID not found. Showing the first available section.")
        selected_id = default_id
    compact, series = load_section_timeseries(selected_id)
    latest = series.iloc[-1] if not series.empty else None
    cols = st.columns(5)
    cols[0].metric("Section ID", selected_id)
    cols[1].metric("River Width", f"{compact.get('bw', 0):.2f} m" if compact else "unavailable")
    cols[2].metric("Stage", f"{latest['stage_m']:.3f} m" if latest is not None else "unavailable")
    cols[3].metric("Discharge", f"{latest['discharge_m3s']:.4f} m3/s" if latest is not None else "unavailable")
    cols[4].metric("Flow State", str(latest["flow_state"]) if latest is not None else "unavailable")
    st.plotly_chart(network_figure(selected_id, network_metadata.get("bounds")), use_container_width=True)
    left, right = st.columns(2)
    template = find_template(cross_sections, compact.get("tid") if compact else None)
    with left:
        st.subheader("Cross-section Profile")
        st.plotly_chart(cross_section_figure(template, float(latest["stage_m"]) if latest is not None else None), use_container_width=True)
    with right:
        st.subheader("Discharge Dynamics")
        if series.empty:
            st.warning("Discharge series unavailable.")
        else:
            st.plotly_chart(hydrograph(series), use_container_width=True)

else:
    st.title("About Data")
    st.write("The app uses the compact public web dataset generated from the Loess Plateau river hydrometry project.")
    st.caption("Data source: bundled `data/` directory when present, otherwise the verified public data endpoint.")
    cols = st.columns(4)
    cols[0].metric("Runoff Months", f"{len(runoff_manifest.get('records', [])):,}")
    cols[1].metric("Fishnet Months", f"{len(fishnet_manifest.get('records', [])):,}")
    cols[2].metric("Sections", f"{hydrometry_index.get('section_count', 0):,}")
    cols[3].metric("Section-Month Records", f"{hydrometry_index.get('record_count', 0):,}")
    st.markdown('<p class="small-note">ICESat-2 matching remains pending until local optional product files are supplied.</p>', unsafe_allow_html=True)
