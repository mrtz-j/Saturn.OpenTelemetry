open System
open Argu
open Giraffe
open Fable.Remoting.Server
open Fable.Remoting.Giraffe
open Saturn
open Saturn.OpenTelemetry
open Serilog
open Serilog.Events
open Serilog.Sinks.OpenTelemetry

type Arguments =
    | Log_Level of level: int
    | Port of port: int
    | [<MainCommand; Last>] Dir of path: string

    interface IArgParserTemplate with
        member this.Usage =
            match this with
            | Log_Level _ -> "0=Error, 1=Warning, 2=Info, 3=Debug, 4=Verbose"
            | Port _ -> "listen port (default 8085)"
            | Dir _ -> "serve from dir"

type IApi = { GetHello: unit -> Async<string> }

let helloWorld () =
    async {
        use _span = Telemetry.createRoot "helloWorld"
        return "Hello From Saturn!"
    }

let api: IApi = { GetHello = helloWorld }

let routeBuilder (typeName: string) (methodName: string) = $"/api/v1/%s{typeName}/%s{methodName}"

let apiHandler: HttpHandler =
    Remoting.createApi ()
    |> Remoting.withRouteBuilder routeBuilder
    |> Remoting.fromValue api
    |> Remoting.buildHttpHandler

/// <summary>
/// Saturn OpenTelemetry Configuration
/// Defines the configuration settings for OpenTelemetry in a Saturn application.
/// </summary>
/// <param name="AppId">The unique identifier for the application</param>
/// <param name="Namespace">The namespace used for grouping related telemetry data</param>
/// <param name="Version">The version of the application</param>
/// <param name="Endpoint">The URL endpoint where telemetry data will be sent</param>
let otelConfig = {
    AppId = "Example"
    Namespace = "Saturn.OpenTelemetry"
    Version = "1.0.0"
    Endpoint = "http://localhost:4317"
}

let configureSerilog level =
    let n =
        match level with
        | 0 -> LogEventLevel.Error
        | 1 -> LogEventLevel.Warning
        | 2 -> LogEventLevel.Information
        | 3 -> LogEventLevel.Debug
        | _ -> LogEventLevel.Verbose
    LoggerConfiguration()
        .MinimumLevel.Is(n)
        .MinimumLevel.Override("Microsoft", LogEventLevel.Information)
        .MinimumLevel.Override("System", LogEventLevel.Information)
        .WriteTo.OpenTelemetry(fun opt ->
            opt.Endpoint <- otelConfig.Endpoint
            opt.IncludedData <-
                IncludedData.TraceIdField
                ||| IncludedData.SpanIdField
                ||| IncludedData.SourceContextAttribute
            opt.ResourceAttributes <-
                dict [
                    "service.name", box otelConfig.AppId
                    "service.namespace", box otelConfig.Namespace
                    "service.version", box otelConfig.Version
                    "host.name", box Environment.MachineName
                ]
        )
        .WriteTo.Console()
        .CreateLogger()

let app port =
    application {
        use_router apiHandler
        url $"http://0.0.0.0:%i{port}/"
        use_otel otelConfig
        use_static "public"
        memory_cache
        use_gzip
        logging (fun logger -> logger.AddSerilog() |> ignore)
    }

let colorizer =
    function
    | ErrorCode.HelpText -> None
    | _ -> Some ConsoleColor.Red

let errorHandler = ProcessExiter(colorizer = colorizer)

[<EntryPoint>]
let main argv =
    let parser =
        ArgumentParser.Create<Arguments>(programName = "Example", errorHandler = errorHandler)
    let args = parser.Parse argv
    let port = args.GetResult(Port, defaultValue = 8085)
    Log.Logger <- configureSerilog (args.GetResult(Log_Level, defaultValue = 4))
    Telemetry.init otelConfig.AppId
    Log.Information $"Exporting telemetry data to %s{otelConfig.Endpoint}"
    run (app port)
    0
