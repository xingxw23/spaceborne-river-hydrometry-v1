# Loess Plateau River Hydrometry Explorer - Streamlit

This directory contains a Streamlit-ready public deployment package using the compact web dataset.
When the local `data/` directory is not present, the app reads from the verified public data endpoint automatically.

## Streamlit Community Cloud

1. Push this directory to a GitHub repository.
2. In Streamlit Community Cloud, create a new app from that repository.
3. Set the main file path to `streamlit_app.py`.
4. Choose an app URL such as `loess-plateau-hydrometry.streamlit.app` if it is available.

Recommended deployment settings:

- Repository: `xingxw23/spaceborne-river-hydrometry-v1`
- Branch: `streamlit-public`
- Main file path: `streamlit_app.py`
- Optional environment variable: `STREAMLIT_DATA_BASE_URL`

If `STREAMLIT_DATA_BASE_URL` is omitted, the app uses the default public data endpoint.
