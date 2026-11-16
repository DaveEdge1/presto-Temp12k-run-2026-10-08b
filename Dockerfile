# Temperature 12k multi-method composite container (R + Python).
#
# Base = davidedge/lipd_webapps:lipdbase2, which already ships the R stack the
# composite methods need (lipdR, geoChronR, compositeR) inside an renv project
# rooted at /. We add a small Python venv for the LiPD-pickle adapter, the GAM
# method (pygam), and the consensus / NetCDF / figure steps.
#
# Layers ordered least->most frequently changed so script edits rebuild fast.

# ── Layer 1: base (R + lipdR/geoChronR/compositeR via renv at /) ──────────
# Pinned by digest: the image the 2026-10-14 run used (lipdbase2 is a mutable tag).
FROM davidedge/lipd_webapps:lipdbase2@sha256:cc1a152177aec9b2c6b233c73c1b1163e9fd62fc14b9c484b6a946443df88aa5

ENV DEBIAN_FRONTEND=noninteractive TZ=UTC

# ── Layer 2: Python venv (heavy, cached until deps change) ────────────────
# The base image's python3 ships without pip/ensurepip, so install
# python3-venv + python3-pip via apt first, then build an isolated venv.
# numpy/pandas/scipy/xarray/netcdf4/matplotlib + pygam (GAM) + pyyaml.
# netcdf4 manylinux wheels bundle libnetcdf, so no apt system lib needed.
#
# Pinned: Ubuntu's archive keeps only the newest build of each package (and
# this step upgrades the python3.10 interpreter itself), so read the archive as
# it was when the 2026-10-14 run built (snapshot.ubuntu.com) and pin every
# package that run installed.
RUN sed -i -E 's#http://(archive|security)\.ubuntu\.com/ubuntu/?#http://snapshot.ubuntu.com/ubuntu/20261014T220000Z/#' \
        /etc/apt/sources.list \
    && apt-get -o Acquire::Check-Valid-Until=false update \
    && apt-get install -y --no-install-recommends \
        python3-venv=3.10.6-1~22.04.1 \
        python3-pip=22.0.2+dfsg-1ubuntu0.7 \
        python3=3.10.6-1~22.04.1 \
        python3-minimal=3.10.6-1~22.04.1 \
        libpython3-stdlib=3.10.6-1~22.04.1 \
        python3.10=3.10.12-1~22.04.18 \
        python3.10-minimal=3.10.12-1~22.04.18 \
        python3.10-venv=3.10.12-1~22.04.18 \
        libpython3.10-stdlib=3.10.12-1~22.04.18 \
        libpython3.10-minimal=3.10.12-1~22.04.18 \
        python3-pkg-resources=59.6.0-1.2ubuntu0.22.04.3 \
        python3-setuptools=59.6.0-1.2ubuntu0.22.04.3 \
        python3-setuptools-whl=59.6.0-1.2ubuntu0.22.04.3 \
        python3-wheel=0.37.1-2ubuntu0.22.04.1 \
        python3-pip-whl=22.0.2+dfsg-1ubuntu0.7 \
    && rm -rf /var/lib/apt/lists/*

# Exact versions from the 2026-10-14 run (requirements.lock).
COPY requirements.lock /tmp/requirements.lock
RUN python3 -m venv /opt/venv && \
    /opt/venv/bin/pip install --no-cache-dir --upgrade pip==26.2.1 setuptools==84.0.0 wheel==0.48.0 && \
    /opt/venv/bin/pip install --no-cache-dir --no-deps -r /tmp/requirements.lock && \
    /opt/venv/bin/pip check && \
    /opt/venv/bin/python -c "import numpy, pandas, scipy, yaml, xarray, netCDF4, matplotlib, pygam; print('venv deps OK')"

ENV PYTHON_BIN=/opt/venv/bin/python

# ── Layer 3: real-ensemble bundle (large-ish; changes only with data version) ──
# v1.0.0 real per-record age+value ensembles (column-subsampled) that the
# published methods used, so the container reproduces Kaufman 2020 rather than
# the pickle's synthetic single-vector ensembles. Built by
# reproduction/localrepro/build_realens_bundle.sh (a build input, not committed
# large; see that script). Only used when PRESTO_REALENS=1.
COPY data/realens/   /app/data/realens/

# ── Layer 4: app source (cheap; iterates often) ───────────────────────────
WORKDIR /app
COPY scripts/        /app/scripts/
COPY config/         /app/config/
COPY reference_data/ /app/reference_data/
COPY entrypoint.sh   /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# CI mounts at runtime:
#   /proxies/lipd_legacy.pkl     (RO)  proxy data from lipdverse
#   /app/config/user_config.yml  (RO)  overwritten per run by PReSto
#   /results                     (RW)  outputs land here
ENV LIPD_PICKLE=/proxies/lipd_legacy.pkl \
    PRESTO_CONFIG=/app/config/user_config.yml \
    PRESTO_REFDATA=/app/reference_data \
    PRESTO_OUTPUT=/results

ENTRYPOINT ["/app/entrypoint.sh"]
