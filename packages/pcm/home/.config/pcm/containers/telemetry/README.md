# Telemetry

A throwaway, local-only tracing stack. Traces flow:

    host app --OTLP--> otel-collector --OTLP--> tempo <--query-- grafana

Any process that speaks OTLP can export to it. The stack is app-independent: it
ships no dashboards and no project paths.

## Run

```sh
pcm up telemetry
pcm down telemetry
podman compose --pcm logs -f telemetry
```

- Grafana: <http://localhost:8080> (anonymous admin, Tempo datasource pre-wired)
- OTLP: `localhost:4317` (gRPC), `localhost:4318` (HTTP)

Tempo data lives in `$PCM_VOLUMES_HOME/telemetry/tempo` (1h retention).

## Architecture (Tempo 3.0)

Tempo runs in **monolithic mode** (`target: all`). The whole write path runs
in-process — distributor → block-builder → live-store — with **no Kafka**.

- **Recent-data TraceQL metrics come from the live-store automatically.** RED /
  rate / quantile queries (`{ } | rate()`, etc.) work with **no Prometheus** and
  **no `local-blocks` processor** (removed in 3.0). There is no
  `metrics_generator`; add span-metrics/service-graph processors only if a
  dashboard panel can't be expressed against live-store metrics.
- The 2.x `ingester:` / `compactor:` blocks are gone; compaction is driven by the
  backend scheduler. Retention (1h) is a per-tenant override default.

## Configuration

Image tags, host ports and the dashboards dir, with defaults, live in
[`.env.schema`](./.env.schema). To override, add a `.env` next to it (e.g.
stowed from your own ppm layer); none is shipped.

## Connecting an app

Point the app's OpenTelemetry SDK OTLP exporter at `http://localhost:4318`
(OTLP/HTTP) or `http://localhost:4317` (gRPC). For a Ruby app:

```ruby
gem "opentelemetry-sdk"
gem "opentelemetry-exporter-otlp"
# gem "opentelemetry-instrumentation-all"   # optional auto-instrumentation
```

An app running in a container can't use `localhost`. Add `telemetry` to
`network_attached_services` in `~/.config/pcm/registry.yml` so it joins
`dev-net`, then export to `telemetry_otel-collector_1:4318`.

## Dashboards (the coupling boundary)

A generic Grafana provider loads any dashboard JSON (folders from the directory
structure) in `GRAFANA_DASHBOARDS_DIR`, the single seam. It defaults to
`$PCM_VOLUMES_HOME/telemetry/dashboards`, which pcm creates empty. To load a
project's dashboards, set it to that project's store as an absolute path in
`.env`, e.g. for Chorus:

```sh
GRAFANA_DASHBOARDS_DIR=/Users/you/spikes/chorus/storage/telemetry/dashboards
```

That directory must exist before `pcm up` (pcm only creates dirs under its own
volumes). It is listed in `x-pcm.allow_mounts`, so `pcm validate` accepts it.

## Verifying ingest without an app

POST a synthetic span straight to the collector:

```bash
curl -X POST http://localhost:4318/v1/traces -H 'Content-Type: application/json' \
  -d '{"resourceSpans":[{"scopeSpans":[{"scope":{"name":"demo"},"spans":[
       {"traceId":"0000000000000000043d11c6ffc67d15","spanId":"0123456789abcdef",
        "name":"demo.smoke.test","kind":1,
        "startTimeUnixNano":"1","endTimeUnixNano":"2"}]}]}]}'
```

The collector returns HTTP 200 on accept. Tempo publishes no host ports and its
3.0 image is distroless (no shell or curl), so read the trace back from the
Grafana container, which is on the same network:

```bash
podman exec telemetry_grafana_1 curl -s \
  http://tempo:3200/api/traces/0000000000000000043d11c6ffc67d15
```

For the metrics path, post a span with a current timestamp (the example above is
at the epoch), then:

```bash
podman exec telemetry_grafana_1 curl -s \
  "http://tempo:3200/api/metrics/query_range?query=%7B%7D%20%7C%20rate()&start=$(($(date +%s)-900))&end=$(date +%s)&step=60s"
```

A `series` in the response proves the live-store metrics path with no Prometheus.

## Files

| File | Role |
|------|------|
| `compose.yml` | The three services: collector, Tempo, Grafana. |
| `otel-collector-config.yaml` | OTLP receiver → batch → export to Tempo. |
| `tempo.yaml` | Monolithic Tempo 3.0: filesystem storage, 1h retention, live-store metrics. |
| `grafana-datasource.yaml` | Wires the Tempo datasource on boot. |
| `grafana-dashboards.yaml` | Generic provider loading `GRAFANA_DASHBOARDS_DIR`. |

Config is mounted file by file: ppm stows files as relative symlinks, and a
directory mount would pass those into the container unresolved.

Everything here is local-dev only: anonymous Grafana admin, no TLS on in-network
traffic, 1-hour trace retention.
