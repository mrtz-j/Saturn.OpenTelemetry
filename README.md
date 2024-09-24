# Saturn.OpenTelemetry

Includes a small `Telemetry` wrapper for the dotnet `ActivitySource`, to make it more compatible
with other OpenTelemetry applications in other languages.

## LGTM stack locally

You can deploy the LGTM stack locally for development purposes.

```console
docker run -p 3002:3000 -p 4317:4317 -p 4318:4318 --rm -ti grafana/otel-lgtm
```
This will spin up a container listening for OTEL traces on port 4317 and 4318 and can be accessed on port 3002.
