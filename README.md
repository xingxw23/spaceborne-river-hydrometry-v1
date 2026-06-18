# Spaceborne River Network Hydrometry

Core code, representative workflows, and demonstration data for reconstructing river-surface occurrence, river width, and discharge across intermittent river networks from multi-source satellite observations.

> **Manuscript:** *Capturing Hidden Rivers with Spaceborne River Network Hydrometry: Discharge Retrieval in Intermittent Rivers*

> **Release status:** Review-stage research release. This repository contains the principal modules required to understand the methodological framework. Selected operational scripts, restricted datasets, large intermediate products, and region-specific processing utilities are not included in the current version.

---

## 1. Overview

Small and intermittent rivers remain poorly represented by conventional gauge networks and many global surface-water products. Their narrow channels, fragmented wetted surfaces, episodic flow activation, vegetation interference, high sediment concentrations, complex channel morphology, and limited field observations make continuous discharge reconstruction particularly challenging.

This project develops a **spaceborne river-network hydrometry framework** that integrates optical, synthetic-aperture-radar, thermal, topographic, river-network, and soil-moisture information to retrieve hydrologically interpretable river variables.

The framework is designed to move beyond isolated reach-scale measurements and toward spatially connected observations of:

* river-surface occurrence;
* intermittent flow activation;
* river-surface connectivity;
* multi-temporal river width;
* soil-moisture-constrained discharge;
* runoff generation, transmission, attenuation, and depletion across river networks.

The workflow is particularly intended for dryland and data-scarce river systems, including small intermittent channels that are commonly missed by conventional gauges and coarse global water products.

---

## 2. Scientific objectives

The project addresses four related questions:

1. How can narrow and fragmented intermittent river surfaces be identified from multi-source satellite observations?
2. How can disconnected water patches be refined without indiscriminately filling dry channel gaps?
3. How can multi-temporal river width be converted into discharge when conventional width–discharge relationships are weakened by intermittency and transmission losses?
4. How can long-term discharge changes be interpreted across different river-network positions rather than only at basin outlets?

---

## 3. Methodological framework

The complete framework contains six connected components.

### 3.1 Multi-source remote-sensing preprocessing

Satellite and ancillary datasets are harmonized before hydrological retrieval. Depending on the application, the inputs may include:

* Landsat TM, ETM+, OLI, and OLI-2 imagery;
* Sentinel-2 multispectral imagery;
* Sentinel-1 SAR observations;
* GF-series optical and SAR imagery;
* thermal-infrared observations;
* digital elevation models and derived terrain variables;
* soil-moisture products or downscaled soil-moisture estimates;
* river-network topology and channel-corridor information;
* gauge observations used for calibration or independent evaluation.

Typical preprocessing steps include:

* atmospheric correction;
* geometric registration;
* orthorectification;
* cloud and shadow masking;
* SAR radiometric and terrain correction;
* spatial resampling;
* projection harmonization;
* temporal matching;
* invalid-pixel and NoData handling.

### 3.2 Intermittent river-surface extraction

The `GRF-CNN` module is used to identify narrow, fragmented, and intermittently wetted river surfaces from multi-source remote-sensing predictors.

The workflow combines feature-based classification with convolutional image analysis so that spectral, textural, geometric, thermal, and spatial-context information can be used jointly.

The module is intended to improve the delineation of:

* narrow tributaries;
* discontinuous wetted channel segments;
* low-flow river surfaces;
* high-turbidity channels;
* channels affected by vegetation or shadows;
* water–sediment mixed pixels;
* partially exposed channel beds.

### 3.3 Soil-moisture-constrained connectivity refinement

Initial binary river-surface masks may contain fragmented water patches under low-flow conditions. A soil-moisture-constrained refinement procedure is therefore used to reconnect candidate river segments only when the intervening pixels:

1. occur within a predefined channel corridor;
2. are spatially consistent with the local river direction;
3. exhibit sufficiently wet or saturated surface conditions;
4. satisfy local morphological and neighborhood constraints.

This step treats elevated channel-bed soil moisture as evidence of recent or intermittent water passage rather than filling all spatial gaps indiscriminately.

### 3.4 Multi-temporal river-width retrieval

River width is retrieved from refined river-surface masks using an automated centerline and cross-section workflow.

The general procedure includes:

* centerline initialization from the binary river mask;
* skeleton- or Voronoi-based centerline generation;
* iterative centerline correction;
* placement of approximately orthogonal cross sections;
* bank-to-bank width measurement;
* temporal aggregation;
* geometric and quality-control filtering.

Subpixel boundary refinement may be applied before width measurement to reduce boundary fragmentation and raster-resolution effects.

### 3.5 Soil-moisture-constrained discharge estimation

Discharge is estimated using a soil-moisture-constrained formulation built on the river-width–discharge relationship.

The formulation accounts for the fact that river width alone may not fully represent discharge variability in intermittent rivers. Depending on data availability, discharge estimation can incorporate:

* multi-temporal river width;
* reference hydraulic geometry;
* soil-moisture modulation;
* channel morphology or bathymetric correction;
* local calibration observations;
* river-network position;
* stream order.

This formulation is particularly useful where narrow channels, discontinuous wetted surfaces, vegetation cover, transmission losses, and complex channel forms weaken conventional width–discharge relationships.

### 3.6 Model evaluation and visualization

The repository includes or supports evaluation using common hydrological and statistical indicators, including:

* coefficient of determination, (R^2);
* Nash–Sutcliffe efficiency, NSE;
* root mean square error, RMSE;
* mean absolute error, MAE;
* Kling–Gupta efficiency, KGE;
* percentage bias, PBIAS;
* overall classification accuracy;
* Cohen's kappa coefficient.

---

## 4. Repository structure

The current review-stage repository contains the following top-level structure:

```text
spaceborne-river-hydrometry-v1/
├── GRF-CNN/
│   └── Core code for intermittent river-surface extraction
├── spaceborne-river-hydrometry-v1/
│   └── Complementary hydrometry workflows and example materials
├── LICENSE
└── README.md
```

### `GRF-CNN/`

This directory contains the principal code associated with the GRF-CNN river-surface extraction workflow. It supports the construction and evaluation of river-surface masks from multi-source remote-sensing predictors.

### `spaceborne-river-hydrometry-v1/`

This directory contains complementary materials associated with the integrated river-hydrometry workflow. Depending on the repository version, it may include selected scripts, demonstration data, evaluation utilities, and plotting examples.

The directory structure will be further standardized in later releases. A future stable release is expected to separate source code, configuration files, example data, documentation, tests, and outputs into dedicated folders.

---

## 5. Demonstration discharge dataset

A synthetic demonstration dataset is provided or may be added as:

```text
river_observed_estimated_sampled_1985_2024.csv
```

The dataset contains date-indexed reference and estimated normalized discharge values for eight representative stations corresponding to river orders 1–8.

### 5.1 Data fields

| Field             | Description                                                                  |
| ----------------- | ---------------------------------------------------------------------------- |
| `Date`            | Randomly selected sampling date in `YYYY-MM-DD` format                       |
| `Station`         | Station identifier                                                           |
| `Qobs_normalized` | Synthetic observation-like/reference discharge normalized to 0–1             |
| `Qest_normalized` | Synthetic estimated discharge normalized to 0–1                              |
| `NSE`             | Station-level Nash–Sutcliffe efficiency calculated from all retained records |

### 5.2 Representative stations

| Station | River order | NSE  |
| ------- | ----------- | ---- |
| YJG     | 1           | 0.92 |
| XDG     | 2           | 0.92 |
| LJP     | 3           | 0.93 |
| ZFG     | 4           | 0.93 |
| BCH     | 5           | 0.92 |
| DLH     | 6           | 0.91 |
| HFC     | 7           | 0.90 |
| WDH     | 8           | 0.90 |

### 5.3 Temporal sampling design

The demonstration records span 1985–2024. Several dates are randomly retained within each month rather than providing a complete record for every calendar day.

The sampling density was designed to resemble the gradual improvement of satellite or monitoring availability over time:

* earlier years contain fewer sampled dates per month;
* later years contain more sampled dates per month;
* wet-season months generally contain more retained observations;
* sampling dates differ among stations;
* a fixed random seed is used to ensure reproducibility.

### 5.4 Important provenance statement

> **The demonstration discharge dataset is synthetic.** It was generated to reproduce the temporal appearance, seasonal variability, sampling density, river-order differences, and statistical performance of the reference figure. It is not the original gauge record, field observation, satellite retrieval, or model output used in the manuscript.

The variable name `Qobs_normalized` is retained for consistency with the reference figure, but it should be interpreted as a **synthetic observation-like or reference series**, not as an original measured discharge record.

The demonstration dataset is intended for:

* visualization;
* webpage development;
* plotting tests;
* code-format demonstrations;
* workflow verification;
* teaching and methodological illustration.

It should not be used to:

* infer real hydrological changes;
* calibrate operational models;
* validate external satellite products;
* assess actual flood or drought conditions;
* support engineering or management decisions.

---

## 6. Installation

### 6.1 Clone the repository

```bash
git clone https://github.com/xingxw23/spaceborne-river-hydrometry-v1.git
cd spaceborne-river-hydrometry-v1
```

### 6.2 Python environment

The exact Python dependencies depend on the selected module. A typical virtual environment can be created using:

```bash
python -m venv .venv
```

Activate the environment:

```bash
# Linux or macOS
source .venv/bin/activate
```

```powershell
# Windows PowerShell
.venv\Scripts\Activate.ps1
```

Commonly used packages may include:

```bash
pip install numpy pandas scipy scikit-learn matplotlib
pip install rasterio geopandas shapely pyproj
pip install torch torchvision
```

Not every package is required by every script. Geospatial packages may be easier to install through Conda when GDAL-related dependency conflicts occur.

### 6.3 MATLAB environment

Several workflow components are implemented in MATLAB. Depending on the selected scripts, the following toolboxes may be required:

* Image Processing Toolbox;
* Mapping Toolbox;
* Statistics and Machine Learning Toolbox;
* Signal Processing Toolbox.

Users should inspect the header and imported functions of each script before execution because toolbox requirements may vary among modules.

---

## 7. Preparing input data

Large remote-sensing datasets and licensed products are not distributed in this repository. Users should obtain the required products from official providers and follow the corresponding data-use and citation requirements.

A project-specific input structure may be organized as:

```text
data/
├── optical/
├── sar/
├── thermal/
├── soil_moisture/
├── dem/
├── river_network/
├── gauge/
└── masks/
```

Before running a workflow, verify that:

* all rasters use a consistent coordinate reference system;
* spatial resolutions and pixel grids are aligned;
* NoData values are handled consistently;
* acquisition dates are parsed correctly;
* cloud, shadow, layover, and invalid-pixel masks are applied;
* river-network vectors overlap the raster datasets;
* units are consistent across calibration and validation datasets;
* training and validation samples are spatially independent where required.

Absolute file paths embedded in example scripts should be replaced with local paths or project-level configuration variables.

---

## 8. General processing sequence

A typical execution sequence is:

```text
1. Download and preprocess multi-source satellite data
2. Construct spectral, textural, terrain, and thermal predictors
3. Run GRF-CNN river-surface extraction
4. Refine fragmented river masks using channel and soil-moisture constraints
5. Derive centerlines and multi-temporal river widths
6. Estimate discharge using the soil-moisture-constrained formulation
7. Aggregate results by river segment, station, stream order, or time period
8. Evaluate retrieval performance
9. Generate figures and export geospatial products
```

The exact processing order may vary according to the available datasets and the research objective.

---

## 9. Reading the demonstration CSV

```python
import pandas as pd

data = pd.read_csv(
    "river_observed_estimated_sampled_1985_2024.csv",
    parse_dates=["Date"],
)

print(data.head())
print(data.dtypes)
print(data["Station"].unique())
```

### 9.1 Recalculate NSE by station

```python
import numpy as np
import pandas as pd


def nash_sutcliffe_efficiency(observed, estimated):
    observed = np.asarray(observed, dtype=float)
    estimated = np.asarray(estimated, dtype=float)

    valid = np.isfinite(observed) & np.isfinite(estimated)
    observed = observed[valid]
    estimated = estimated[valid]

    denominator = np.sum(
        (observed - np.mean(observed)) ** 2
    )

    if denominator == 0:
        return np.nan

    numerator = np.sum(
        (estimated - observed) ** 2
    )

    return 1.0 - numerator / denominator


data = pd.read_csv(
    "river_observed_estimated_sampled_1985_2024.csv",
    parse_dates=["Date"],
)

nse_summary = (
    data.groupby("Station")
    .apply(
        lambda group: nash_sutcliffe_efficiency(
            group["Qobs_normalized"],
            group["Qest_normalized"],
        )
    )
    .rename("Calculated_NSE")
)

print(nse_summary)
```

### 9.2 Plot one station

```python
import matplotlib.pyplot as plt
import pandas as pd

data = pd.read_csv(
    "river_observed_estimated_sampled_1985_2024.csv",
    parse_dates=["Date"],
)

station = "YJG"

subset = (
    data.loc[data["Station"] == station]
    .sort_values("Date")
)

plt.figure(figsize=(12, 4))

plt.plot(
    subset["Date"],
    subset["Qobs_normalized"],
    linestyle=":",
    linewidth=1.0,
    label="Reference",
)

plt.scatter(
    subset["Date"],
    subset["Qest_normalized"],
    s=8,
    label="Estimated",
)

plt.xlabel("Date")
plt.ylabel("Normalized discharge")
plt.title(f"{station}: reference and estimated discharge")
plt.legend()
plt.tight_layout()
plt.show()
```

---

## 10. Nash–Sutcliffe efficiency

---

## 11. Expected outputs

Depending on the selected module, typical outputs may include:

* binary river-surface masks;
* probabilistic river-surface maps;
* refined connected river-surface products;
* river centerlines;
* cross-section vectors;
* multi-temporal river-width tables;
* soil-moisture estimates;
* segment-scale discharge time series;
* station-scale discharge time series;
* river-network trend maps;
* classification and regression accuracy reports;
* publication-quality figures.

Large raster outputs, temporary files, and complete regional products are intentionally excluded from the current review-stage repository.

---

## 12. Reproducibility recommendations

To improve reproducibility:

1. record software and package versions;
2. preserve raster metadata and coordinate reference systems;
3. save calibration parameters and model weights;
4. use fixed random seeds for stochastic procedures;
5. separate calibration, validation, and independent test datasets;
6. avoid spatial or temporal leakage between training and evaluation samples;
7. document all manual quality-control procedures;
8. retain intermediate river masks and river-width products where storage permits;
9. record the acquisition date and source of every remote-sensing scene;
10. maintain consistent station and river-segment identifiers.

For the synthetic demonstration dataset, a fixed random seed is used during generation. Nevertheless, the demonstration values should be treated only as synthetic examples.

---

## 13. Data availability and restrictions

The complete study uses multi-source datasets obtained from different providers. Some datasets cannot be redistributed because of:

* third-party license restrictions;
* large file sizes;
* institutional data-sharing agreements;
* sensitive gauge or field information;
* region-specific preprocessing requirements.

Users should obtain the original satellite, reanalysis, terrain, soil-moisture, and gauge datasets from their official providers.

The repository does not transfer ownership or licensing rights for any third-party product. Users are responsible for complying with the corresponding provider terms and citation requirements.

---

## 14. Limitations of the current release

This repository is a research release rather than a turn-key operational system.

Current limitations include:

* selected scripts remain project- or region-specific;
* some file paths and configuration parameters require manual editing;
* large intermediate products are not included;
* licensed or restricted datasets are not redistributed;
* thresholds may require recalibration in a new basin;
* performance may vary with spatial resolution, river width, vegetation, turbidity, ice, cloud cover, and SAR acquisition geometry;
* discharge uncertainty may increase where the width–discharge relationship is weak;
* soil-moisture constraints depend on the availability and quality of soil-moisture estimates;
* the synthetic demonstration dataset cannot substitute for original observations.

Users applying the framework to a new river system should conduct independent calibration, uncertainty analysis, and validation.

---

## 15. Study contributions

The manuscript demonstrates how satellite hydrometry can be extended from isolated river reaches to connected river networks.

The principal contributions include:

* improved identification of narrow and fragmented intermittent river surfaces;
* integration of optical, SAR, thermal, terrain, and soil-moisture information;
* soil-moisture-constrained reconstruction of river-surface connectivity;
* multi-temporal river-width retrieval across multiple river orders;
* discharge reconstruction in intermittent and data-scarce river systems;
* network-scale interpretation of runoff generation, transmission, and depletion;
* identification of spatially opposing hydrological responses that may be obscured by basin-average or outlet-only assessments.

The final numerical results should be cited from the published article because values may change during peer review and revision.

---

## 16. Citation

The manuscript associated with this repository is currently under review.

Suggested interim citation:

```text
Xing, X., et al. Capturing Hidden Rivers with Spaceborne River Network
Hydrometry: Discharge Retrieval in Intermittent Rivers.
Manuscript under review.
```

BibTeX template:

```bibtex
@article{XingSpaceborneRiverHydrometry,
  author  = {Xing, Xuanwei and others},
  title   = {Capturing Hidden Rivers with Spaceborne River Network Hydrometry:
             Discharge Retrieval in Intermittent Rivers},
  journal = {Manuscript under review},
  year    = {2026}
}
```

After publication, this section will be updated with the final author list, journal, volume, article number, and DOI.

When using the synthetic demonstration dataset, please additionally state:

```text
```
