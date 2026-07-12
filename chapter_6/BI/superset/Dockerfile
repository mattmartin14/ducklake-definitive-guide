# ── Base image ────────────────────────────────────────────────────────────────
# Pin to a stable Superset release. Update the tag when upgrading.
# Tested with 4.1.1; use `apache/superset:latest` to track the latest release.
FROM apache/superset:4.1.1

USER root

# ── Python extras ────────────────────────────────────────────────────────────
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt

# ── Data directory (shared with the ducklake_data volume) ────────────────────
RUN mkdir -p /data && chown -R superset:superset /data

# ── Pre-install DuckDB extensions as the superset user ───────────────────────
# Extensions land in ~superset/.duckdb/extensions/ so they are found at runtime
# when duckdb-engine opens connections as that user.
USER superset
RUN python3 -c "\
import duckdb; \
c = duckdb.connect(); \
c.execute('INSTALL ducklake; INSTALL tpch; INSTALL aws; INSTALL postgres;'); \
c.close(); \
print('DuckDB extensions pre-installed.')"
