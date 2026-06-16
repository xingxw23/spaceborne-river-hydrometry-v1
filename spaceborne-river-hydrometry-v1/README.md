# Spaceborne River Hydrometry

Review-stage reference implementation for:

**Capturing Hidden Rivers with Spaceborne River Network Hydrometry: Discharge Retrieval in Intermittent Rivers**

**Author:** Xuanwei Xing

This repository provides the main computational modules outside the separately released GRF-CNN code:

- multisource raster harmonization;
- soil-moisture-constrained connection of fragmented river surfaces;
- skeleton centerline reconstruction and orthogonal width retrieval;
- low-flow cross-section fitting and bathymetric correction;
- SMCBAM discharge estimation;
- river-network topology summaries;
- validation metrics and a runnable synthetic example.

The release is intended for methodological inspection and reproducible demonstration. Region-specific production scripts, licensed datasets, and large intermediate products are not included.

## Installation

```bash
git clone https://github.com/xingxw23/spaceborne-river-hydrometry-v1.git
cd spaceborne-river-hydrometry-v1
pip install -e .
python examples/synthetic_workflow.py
```

Outputs are written to `outputs/synthetic_demo/`.

## Input expectations

All raster inputs should share the same projection, extent, resolution and pixel alignment. Typical inputs include a binary river mask, SAR-derived soil moisture, a channel-corridor mask, river-network topology, cross-section observations, and reach-level hydraulic parameters.

## Contact

Xuanwei Xing  
State Key Laboratory of Hydroscience and Engineering, Tsinghua University  
Email: xxw23@mails.tsinghua.edu.cn
