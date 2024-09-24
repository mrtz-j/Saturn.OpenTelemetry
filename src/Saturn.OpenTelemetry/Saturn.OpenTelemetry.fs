namespace Saturn

open Microsoft.Extensions.DependencyInjection
open Microsoft.AspNetCore.Builder

/// <summary> Initial module </summary>
[<AutoOpen>]
module OpenTelemetry =
    open Saturn
    open System
    open OpenTelemetry.Metrics
    open OpenTelemetry.Logs
    open OpenTelemetry.Trace
    open OpenTelemetry.Resources

    type OtelConfig = {
        AppId: string
        Namespace: string
        Version: string
        Endpoint: string
    }

    type ApplicationBuilder with
        [<CustomOperation("use_otel")>]
        member this.UseOtel (state, config: OtelConfig) =
            let middleware (app: IApplicationBuilder) = app
            let service (service: IServiceCollection) =
                service
                    .AddOpenTelemetry() // Tracing and Metrics
                    .ConfigureResource(fun res ->
                        res.AddService(config.AppId, config.Namespace, config.Version) |> ignore
                        res.AddAttributes(
                            dict [
                                "service.name", box config.AppId
                                "service.version", box config.Version
                                "host.name", box Environment.MachineName
                            ]
                        )
                        |> ignore
                    )
                    .WithTracing(fun tra ->
                        tra
                            .SetSampler(Telemetry.Sampler())
                            .AddAspNetCoreInstrumentation(fun opt ->
                                opt.Filter <- Telemetry.requestFilter
                                opt.EnrichWithHttpRequest <- Telemetry.enrichHttpRequest
                                opt.EnrichWithHttpResponse <- Telemetry.enrichHttpResponse
                                opt.RecordException <- true
                                ()
                            )
                            .AddHttpClientInstrumentation(fun opt ->
                                opt.FilterHttpRequestMessage <- Telemetry.clientRequestFilter
                                opt.RecordException <- true
                                ()
                            )
                            .AddSource(config.AppId)
                            .SetResourceBuilder(
                                ResourceBuilder
                                    .CreateDefault()
                                    .AddService(config.AppId, config.Namespace, config.Version)
                            )
                            .AddOtlpExporter(fun opt -> opt.Endpoint <- new Uri(config.Endpoint))
                        |> ignore
                    )
                    .WithLogging(fun log ->
                        log
                            .SetResourceBuilder(
                                ResourceBuilder
                                    .CreateDefault()
                                    .AddService(config.AppId, config.Namespace, config.Version)
                            )
                            .AddOtlpExporter(fun opt -> opt.Endpoint <- new Uri(config.Endpoint))
                        |> ignore
                    )
                    .WithMetrics(fun met ->
                        met
                            .SetResourceBuilder(
                                ResourceBuilder
                                    .CreateDefault()
                                    .AddService(config.AppId, config.Namespace, config.Version)
                            )
                            .AddAspNetCoreInstrumentation()
                            .AddHttpClientInstrumentation()
                            .AddRuntimeInstrumentation()
                            .AddProcessInstrumentation()
                            .AddOtlpExporter(fun opt -> opt.Endpoint <- new Uri(config.Endpoint))
                        |> ignore
                    )
                |> ignore
                service

            this.ServiceConfig(state, service)
            |> fun state -> this.AppConfig(state, middleware)
