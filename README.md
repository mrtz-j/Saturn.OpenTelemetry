[![built with nix](https://img.shields.io/badge/built%20with-nix-%235277C3?logo=nixos)](https://nixos.org/)

# Saturn.OpenTelemetry

Includes a small `Telemetry` wrapper for the dotnet `ActivitySource`, to make it more compatible with other OpenTelemetry applications in other languages.

## Table of Contents

- [About](#about)
- [Getting Started](#getting-started)
- [Telemetry API](#telemetry-api)
- [Optional Instrumentation](#optional-instrumentation)
- [LGTM-Stack](#lgtm-stack-locally)
- [License](#license)

## About

`Saturn.OpenTelemetry` is a library that extends the `Saturn` Web Application framework with functionality to integrate OpenTelemetry for distributed tracing and metrics. This means that you can easily add observability to your Saturn applications, allowing you to monitor and analyze the performance and behavior of your services.

Inspired by the OpenTelemetry .NET SDK, but adapted to work seamlessly with Saturn's functional programming model and F# syntax.

## Getting Started

Add the `Saturn.OpenTelemetry` NuGet package to your project:

```bash
dotnet add package Saturn.OpenTelemetry
```

Basic use case:

```fsharp
open Saturn
open Saturn.OpenTelemetry

// General OpenTelemetry Configuration
let otelConfig: OtelConfig = {
    Endpoint = "http://localhost:4317"
    AppId = "Example"
    Namespace = "Saturn"
    Version = "1.0.0"
}

// Add OpenTelemetry to the Saturn pipeline
let app = application {
    use_router webAppRouter
    url "http://0.0.0.0:8085/"
    use_otel (
        configure_otel {
            // These are required
            settings otelConfig
            // These are optional and can be used to enable specific features
            // use_efcore
            // use_redis
            // use_openfga
        }
    )
    use_static "static"
    memory_cache
    use_gzip
}

// Start the application and Initialize OpenTelemetry
[<EntryPoint>]
let main _ =
    // Telemetry.init sets up the ActivitySource used for manual span creation.
    // use_otel (above) registers the OTEL SDK pipeline in ASP.NET Core's DI container.
    // Both are required: init for the Telemetry module, use_otel for automatic HTTP instrumentation.
    Telemetry.init otelConfig.AppId
    run app
    0
```

## Telemetry API

The `Telemetry` module provides manual span creation and tagging on top of the automatic HTTP instrumentation:

```fsharp
// Create a child span of the current span (most common usage).
// Use `use` so the span stops when it goes out of scope.
use _span = Telemetry.child "operationName" ["tag", "value" :> obj]

// Create a root span (e.g. for background jobs not started by an HTTP request).
use _span = Telemetry.createRoot "jobName"

// Add tags and events to the current span
Telemetry.addTag "user.id" userId
Telemetry.addTags ["db.rows_affected", rowCount :> obj; "db.table", "orders" :> obj]
Telemetry.addEvent "cache.miss" ["key", cacheKey :> obj]

// Record an exception on the current span
try
    doSomething ()
with e ->
    Telemetry.addException "something failed" e
    reraise ()
```

## Optional Instrumentation

Additional instrumentation can be enabled in the `configure_otel` block. Each requires the corresponding NuGet package:

| Operation | NuGet package |
|---|---|
| `use_redis` | `OpenTelemetry.Instrumentation.StackExchangeRedis` |
| `use_efcore` | `OpenTelemetry.Instrumentation.EntityFrameworkCore` |
| `use_openfga` | `OpenFga.Sdk` |

```fsharp
use_otel (
    configure_otel {
        settings otelConfig
        use_redis
        use_efcore
        use_openfga
    }
)
```

## LGTM stack locally

You can deploy the LGTM (Loki, Grafana, Tempo and Mirmir) stack locally for development purposes.

```bash
docker run -p 3002:3000 -p 4317:4317 -p 4318:4318 --rm -ti grafana/otel-lgtm
```

This will spin up a container listening for OTEL traces on port 4317 and 4318 and can be accessed on port 3002.

A slightly pimped version of the classic otel-lgtm container preconfigured with DotNet and Dapr dashboards, is
available [here](https://github.com/juselius/otel-lgtm).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
