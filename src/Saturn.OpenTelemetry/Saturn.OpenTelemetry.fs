namespace Saturn

open System
open System.ComponentModel
open Microsoft.Extensions.DependencyInjection
open Microsoft.AspNetCore.Builder

module OpenTelemetry =
    open Saturn
    open OpenTelemetry.Metrics
    open OpenTelemetry.Trace
    open OpenTelemetry.Resources
    open OpenFga.Sdk.Telemetry

    /// <summary>
    /// Saturn OpenTelemetry Configuration
    /// Defines the configuration settings for OpenTelemetry in a Saturn application.
    /// </summary>
    /// <param name="AppId">The unique identifier for the application</param>
    /// <param name="Namespace">The namespace used for grouping related telemetry data</param>
    /// <param name="Version">The version of the application</param>
    /// <param name="Endpoint">The URL endpoint where telemetry data will be sent</param>
    type OtelConfig = {
        Endpoint: string
        AppId: string
        Namespace: string
        Version: string
    }

    [<EditorBrowsable(EditorBrowsableState.Never); RequireQualifiedAccess>]
    module State =
        type Empty = | Init

        [<Struct>]
        type Settings = {
            OtelConfig: OtelConfig
            UseRedis: bool option
            UseEfCore: bool option
            UseOpenFga: bool option
        }

    type SettingsBuilder() =
        member _.Yield (_) = {
            State.OtelConfig = {
                Endpoint = ""
                AppId = ""
                Namespace = ""
                Version = ""
            }
            State.UseRedis = None
            State.UseEfCore = None
            State.UseOpenFga = None
        }

        /// The OpenTelemetry configuration settings.
        [<CustomOperation("settings")>]
        member _.Settings (state: State.Settings, otelConfig: OtelConfig) = {
            state with
                State.OtelConfig = {
                    Endpoint = otelConfig.Endpoint
                    AppId = otelConfig.AppId
                    Namespace = otelConfig.Namespace
                    Version = otelConfig.Version
                }
        }

        /// Enable Redis instrumentation.
        [<CustomOperation("use_redis")>]
        member _.UseRedis (state: State.Settings) = { state with State.UseRedis = Some true }

        /// Enable EF Core instrumentation.
        [<CustomOperation("use_efcore")>]
        member _.UseEfCore (state: State.Settings) = { state with State.UseEfCore = Some true }

        /// Enable OpenFGA instrumentation.
        [<CustomOperation("use_openfga")>]
        member _.UseOpenFga (state: State.Settings) = { state with State.UseOpenFga = Some true }

    [<AutoOpen>]
    module Builder =
        let configure_otel = SettingsBuilder()

    type ApplicationBuilder with
        /// <summary>
        /// Configures OpenTelemetry for the application.
        /// </summary>
        /// <param name="state">The current application state.</param>
        /// <param name="config">The OpenTelemetry configuration.</param>
        /// <returns>Updated application state with OpenTelemetry configured.</returns>
        [<CustomOperation("use_otel")>]
        member this.UseOtel (state, config: State.Settings) =
            if
                String.IsNullOrEmpty config.OtelConfig.Endpoint
                || String.IsNullOrEmpty config.OtelConfig.AppId
                || String.IsNullOrEmpty config.OtelConfig.Version
                || String.IsNullOrEmpty config.OtelConfig.Namespace
            then
                failwith
                    "OpenTelemetry configuration is not provided or incomplete. Please use the 'settings' operation to configure OpenTelemetry."

            let middleware (app: IApplicationBuilder) = app
            let service (service: IServiceCollection) =
                service
                    .AddOpenTelemetry()
                    .ConfigureResource(fun res ->
                        res.AddService(
                            config.OtelConfig.AppId,
                            config.OtelConfig.Namespace,
                            config.OtelConfig.Version
                        )
                        |> ignore
                        res.AddAttributes(
                            dict [
                                "service.name", box config.OtelConfig.AppId
                                "service.version", box config.OtelConfig.Version
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
                            )
                            .AddHttpClientInstrumentation(fun opt ->
                                opt.FilterHttpRequestMessage <- Telemetry.clientRequestFilter
                                opt.RecordException <- true
                            )
                            .AddSource(config.OtelConfig.AppId)
                            .SetResourceBuilder(
                                ResourceBuilder
                                    .CreateDefault()
                                    .AddService(
                                        config.OtelConfig.AppId,
                                        config.OtelConfig.Namespace,
                                        config.OtelConfig.Version
                                    )
                            )
                            .AddOtlpExporter(fun opt ->
                                opt.Endpoint <- new Uri(config.OtelConfig.Endpoint)
                            )
                        |> (fun tra ->
                            config.UseRedis
                            |> Option.iter (fun _ -> tra.AddRedisInstrumentation() |> ignore)
                            config.UseEfCore
                            |> Option.iter (fun _ ->
                                tra.AddEntityFrameworkCoreInstrumentation(fun opt ->
                                    opt.EnrichWithIDbCommand <- Telemetry.enrichIdb
                                )
                                |> ignore
                            )
                            tra
                        )
                        |> ignore
                    )
                    .WithMetrics(fun met ->
                        met
                            .SetResourceBuilder(
                                ResourceBuilder
                                    .CreateDefault()
                                    .AddService(
                                        config.OtelConfig.AppId,
                                        config.OtelConfig.Namespace,
                                        config.OtelConfig.Version
                                    )
                            )
                            .AddMeter("System.Runtime")
                            .AddAspNetCoreInstrumentation()
                            .AddHttpClientInstrumentation()
                            .AddProcessInstrumentation()
                            .AddOtlpExporter(fun opt ->
                                opt.Endpoint <- new Uri(config.OtelConfig.Endpoint)
                            )
                        |> (fun met ->
                            config.UseOpenFga
                            |> Option.iter (fun _ -> met.AddMeter Metrics.Name |> ignore)
                            met
                        )
                        |> ignore
                    )
                |> ignore
                service

            {
                state with
                    ServicesConfig = service :: state.ServicesConfig
                    AppConfigs = middleware :: state.AppConfigs
            }
