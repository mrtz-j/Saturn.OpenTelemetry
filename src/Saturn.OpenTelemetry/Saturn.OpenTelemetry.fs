namespace Saturn

open Microsoft.Extensions.DependencyInjection
open Microsoft.Extensions.Hosting
open Microsoft.AspNetCore.Builder

/// <summary> Initial module </summary>
[<AutoOpen>]
module OpenTelemetry =
    open Saturn
    open System
    open OpenTelemetry.Metrics
    open OpenTelemetry.Resources
    open OpenTelemetry.Trace

    type ApplicationBuilder with
        [<CustomOperation("use_otel")>]
        member this.UseOtel (state) =
            let middleware (app: IApplicationBuilder) = app
            let service (service: IServiceCollection) =
                service
                    .AddOpenTelemetry() // Tracing and Metrics
                    .ConfigureResource(fun res ->
                        res.AddService("appId", "namespace", "version") |> ignore
                        res.AddAttributes(Telemetry.tags) |> ignore
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
                            .AddSource("appId")
                            .SetResourceBuilder(
                                ResourceBuilder
                                    .CreateDefault()
                                    .AddService("appId", "namespace", "version")
                            )
                            .AddOtlpExporter(fun opt -> opt.Endpoint <- new Uri("endpoint"))
                        |> ignore
                    )
                    .WithMetrics(fun met ->
                        met
                            .AddAspNetCoreInstrumentation()
                            .AddHttpClientInstrumentation()
                            .AddRuntimeInstrumentation()
                            .AddProcessInstrumentation()
                            .SetResourceBuilder(
                                ResourceBuilder
                                    .CreateDefault()
                                    .AddService("appId", "namespace", "version")
                            )
                            .AddOtlpExporter(fun opt -> opt.Endpoint <- new Uri("endpoint"))
                        |> ignore
                    )
                |> ignore
                service

            this.ServiceConfig(state, service)
            |> fun state -> this.AppConfig(state, middleware)
