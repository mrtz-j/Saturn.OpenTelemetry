namespace Saturn.OpenTelemetry

open Microsoft.Extensions.DependencyInjection
open Microsoft.AspNetCore.Builder

/// <summary> Initial module </summary>
[<AutoOpen>]
module OpenTelemetry =
    open Saturn
    open System
    open OpenTelemetry.Metrics
    open OpenTelemetry.Trace
    open OpenTelemetry.Resources

    /// <summary>
    /// Configuration for OpenTelemetry.
    /// </summary>
    type OtelConfig = {
        /// <summary>
        /// The application identifier.
        /// </summary>
        /// <example>
        /// "my-app"
        /// </example>
        AppId: string
        /// <summary>
        /// The namespace for the application.
        /// </summary>
        /// <example>
        /// "com.example"
        /// </example>
        Namespace: string
        /// <summary>
        /// The version of the application.
        /// </summary>
        /// <example>
        /// "1.0.0"
        /// </example>
        Version: string
        /// <summary>
        /// The endpoint for OpenTelemetry data collection.
        /// </summary>
        /// <example>
        /// "http://localhost:4317"
        /// </example>
        Endpoint: string
    }

    type ApplicationBuilder with
        /// <summary>
        /// Configures OpenTelemetry for the application.
        /// </summary>
        /// <param name="state">The current application state.</param>
        /// <param name="config">The OpenTelemetry configuration.</param>
        /// <returns>Updated application state with OpenTelemetry configured.</returns>
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
                            // FIXME: Expose sampler to user
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
                    // NOTE: Logging is currently not supported, use Serilog.Sinks.OpenTelemetry
                    // .WithLogging(fun log ->
                    //     log
                    //         .SetResourceBuilder(
                    //             ResourceBuilder
                    //                 .CreateDefault()
                    //                 .AddService(config.AppId, config.Namespace, config.Version)
                    //         )
                    //         .AddOtlpExporter(fun opt -> opt.Endpoint <- new Uri(config.Endpoint))
                    //     |> ignore
                    // )
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
