/// <summary>
/// To start using OpenTelemetry initialize it with the name of the current service:
///
///   `Telemetry.init ServiceName`
///
/// Creating a span sets that span as the thread- and async- local span until
/// it is cleaned up. That means to use create a child span you need to do:
///
///   `use span = Telemetry.child "name" ["some attrs", 0]`
///
/// That span will be cleaned up when it goes out of scope. It's also important that
/// if you're using Tasks that the `use` goes inside a `task` CE or else it won't be
/// appropriately taken care of.
///
/// Root spans can be added with:
///
///   `Telemetry.createRoot "Root span name"`
///
/// The appropriate span is then tracked, and so you can add tags and events to the
/// current span implicitly by using:
///
///   `Telemetry.addTag "some tag" "some value"`
///   `Telemetry.addtags ["tag1", "value" :> obj; "tag2", 2 :> obj]`
///   `Telemetry.addEvent "some event name" []`
///
/// The type of the value is `obj`, so anything is allowed.
///
/// </summary>
/// <remarks>
/// OpenTelemetry names are confusing in .NET. Here is a good summary.
/// https://github.com/open-telemetry/opentelemetry-dotnet/issues/947
/// </remarks>
module Telemetry

open System
open System.Net.Http
open System.Text
open System.Collections.Generic
open System.Diagnostics
open Microsoft.AspNetCore.Http
open OpenTelemetry.Trace

type Metadata = (string * obj) list

[<Literal>]
let TraceRate = 0.1

[<Literal>]
let TraceAll = true

/// <summary>
/// Deterministic sampler, will produce the same result for every span in a trace.
/// Originally based on https://github.com/open-telemetry/opentelemetry-dotnet/blob/b2fb873fcd9ceca2552b152a60bf192e2ea12b99/src/OpenTelemetry/Trace/TraceIdRatioBasedSampler.cs#LL76.
/// </summary>
type Sampler() =
    inherit OpenTelemetry.Trace.Sampler()
    let keep = SamplingResult(SamplingDecision.RecordAndSample)
    let drop = SamplingResult(SamplingDecision.Drop)

    /// <summary>
    /// Determines whether a span should be sampled based on the sampling parameters and trace settings.
    /// </summary>
    /// <param name="ps">The sampling parameters for the current span.</param>
    /// <returns>A SamplingResult indicating whether the span should be sampled or dropped.</returns>
    override this.ShouldSample (ps: SamplingParameters inref) : SamplingResult =
        if TraceAll then
            keep
        else
            // Calculate the scaled threshold based on the TraceRate setting
            let scaled = int (TraceRate * float Int32.MaxValue)
            // Get a hash code from the TraceId and ensure it's positive
            let traceIDAsInt = ps.TraceId.GetHashCode() |> Math.Abs
            // Compare the hash with the scaled threshold to determine sampling
            if traceIDAsInt < scaled then keep else drop

module Internal =
    // Initialized via `init`, below.
    let mutable _source: ActivitySource = null

/// <summary>
/// Get the Span/Activity for this execution. It is thread and also async-local.
/// </summary>
module Span =
    /// .NET calls them Activity, OpenTelemetry and everyone else calls them Spans :).
    type T = Activity

    // `Spans` need to stop or they'll have the wrong end-time. You can
    // either use `use` when allocating them, which will mean they are stopped as soon
    // as they go out of scope, or you can explicitly call stop.
    let root (name: string) : T =
        // Deliberately created with no parent to make this a root.
        // FIXME: This breaks trace span propagation.
        // https://github.com/open-telemetry/opentelemetry-dotnet/issues/984
        // Activity.Current <- null
        let span = Internal._source.CreateActivity(name, ActivityKind.Internal)
        span.Start()

    // It is technically possible for Span/Activities to be null if things are not
    // configured right. The solution there is to fix the configuration, not to allow
    // null checks.
    let current () : T = Activity.Current

    // Helper
    let toKeyValuePair ((k, v): 'a * 'b) : KeyValuePair<'a, 'b> = KeyValuePair<'a, 'b>(k, v)

    // Spans (Activities) need to stop or they'll have the wrong end-time. You can
    // either use `use` when allocating them, which will mean they are stopped as soon
    // as they go out of scope, or you can explicitly call stop.
    let child (name: string) (parent: T) (tags: Metadata) : T =
        let tags = tags |> List.map toKeyValuePair
        let parentId = if isNull parent then null else parent.Id
        let kind = ActivityKind.Internal
        // the Sampler is called within this, and only the tags available here will be
        // passed to the sampler
        let result = Internal._source.CreateActivity(name, kind, parentId, tags)
        result.Start()

    let addTag (name: string) (value: obj) (span: T) : unit = span.SetTag(name, value) |> ignore<T>

    let addTags (tags: Metadata) (span: T) : unit =
        List.iter (fun (name, value: obj) -> span.SetTag(name, value) |> ignore<T>) tags

    let addEvent (name: string) (tags: Metadata) (span: T) : unit =
        let e = span.AddEvent(ActivityEvent name)
        List.iter (fun (name, value: obj) -> e.SetTag(name, value) |> ignore<T>) tags

/// <summary>
/// Creates a new child span from the current span.
/// </summary>
/// <param name="name">The name of the child span.</param>
/// <param name="tags">Metadata to be added to the child span.</param>
/// <returns>A new child span.</returns>
/// <remarks>
/// The correct way to use this is to call `use span = Telemetry.child` so that it falls out of scope properly
/// and the parent takes over again.
/// </remarks>
let child (name: string) (tags: Metadata) : Span.T = Span.child name (Span.current ()) tags

/// <summary>
/// Creates a new root span.
/// </summary>
/// <param name="name">The name of the root span.</param>
/// <returns>A new root span.</returns>
/// <remarks>
/// This overwrites spans from AspNetCore.Http and ClientHttps requests.
/// </remarks>
let createRoot (name: string) : Span.T = Span.root name

let rootID () : string =
    let root = Activity.Current.RootId
    if isNull root then "null" else string root

/// <summary>
/// Adds a tag to the current span.
/// </summary>
/// <param name="name">The name of the tag.</param>
/// <param name="value">The value of the tag.</param>
let addTag (name: string) (value: obj) : unit = Span.addTag name value (Span.current ())

/// <summary>
/// Adds multiple tags to the current span.
/// </summary>
/// <param name="tags">A list of key-value pairs representing the tags to be added.</param>
let addTags (tags: Metadata) : unit = Span.addTags tags (Span.current ())

/// <summary>
/// Adds an event to the current span.
/// </summary>
/// <param name="name">The name of the event.</param>
/// <param name="tags">A list of key-value pairs representing the tags associated with the event.</param>
let addEvent (name: string) (tags: Metadata) : unit =
    let span = Span.current ()
    let tagCollection = ActivityTagsCollection()
    List.iter (fun (k, v) -> tagCollection[k] <- v) tags
    let event = ActivityEvent(name, DateTimeOffset.Now, tagCollection)
    span.AddEvent(event) |> ignore<Span.T>

/// <summary>
/// Adds exception information to the current activity.
/// </summary>
/// <param name="msg">The error message to set as the activity status.</param>
/// <param name="e">The exception to add as tags to the activity.</param>
let addException (msg: string) (e: exn) : unit =
    Activity.Current
        .SetStatus(ActivityStatusCode.Error, msg)
        .AddTag("ex.Message", $"%s{e.Message}")
        .AddTag("ex.StackTrace", $"%s{e.StackTrace}")
    |> ignore

/// <summary>
/// OpenTelemetry trace attribute specifications: https://github.com/open-telemetry/opentelemetry-specification/tree/main/specification/trace/semantic_conventions
/// Ensure that these are all stringified on startup, not when they're added to the span.
/// </summary>
let serviceTags: Metadata =
    let (tags: (string * string) list) = [
        // "meta.environment", string Settings.Environment
        "meta.server.machinename", string Environment.MachineName
        "meta.server.os", string Environment.OSVersion
        "meta.process.path", string Environment.ProcessPath
        "meta.process.pwd", string Environment.CurrentDirectory
        "meta.process.pid", string Environment.ProcessId
        "meta.process.starttime",
        Process
            .GetCurrentProcess()
            .StartTime.ToUniversalTime()
            .ToString("u")
        "meta.process.command_line", string Environment.CommandLine
        "meta.dotnet.framework.version",
        string System.Runtime.InteropServices.RuntimeInformation.FrameworkDescription
    ]
    // NOTE: Is this typecast necessary?
    List.map (fun (k, v) -> (k, v :> obj)) tags

let addServiceTags (span: Span.T) : unit = Span.addTags serviceTags span

let init (serviceName: string) : unit =
    // Not enabled by default https://jimmybogard.com/building-end-to-end-diagnostics-and-tracing-a-primer-trace-context/
    Activity.DefaultIdFormat <- ActivityIdFormat.W3C

    Internal._source <- new ActivitySource(serviceName)

    // We need all this or .NET will create null Activities
    // https://github.com/dotnet/runtime/issues/45070
    let activityListener =
        let al = new ActivityListener()
        al.ShouldListenTo <- fun s -> true
        al.SampleUsingParentId <-
            // If we use AllData instead of AllDataAndActivities, the http span won't be recorded
            fun _ -> ActivitySamplingResult.AllDataAndRecorded
        al.Sample <- fun _ -> ActivitySamplingResult.AllDataAndRecorded
        // Do it now so that the parent has
        al.ActivityStarted <-
            // Use ParentId instead of Parent as Parent is null in more cases
            (fun span ->
                if isNull span.ParentId then
                    addServiceTags span
            )
        al
    ActivitySource.AddActivityListener(activityListener)

    // NOTE: Ensure there is always a root span
    Span.root $"Starting %s{serviceName}" |> ignore<Span.T>

let mutable tracerProvider: TracerProvider = null

/// Flush all Telemetry. Used on shutdown/Exit.
let flush () : unit =
    if not (isNull tracerProvider) then
        tracerProvider.ForceFlush() |> ignore<bool>

/// Exclude /health, /metrics and /swagger requests from Server
let requestFilter (ctx: HttpContext) : bool =
    match ctx.Request.Path.ToString() with
    | "/swagger"
    | "/health"
    | "/healthz"
    | "/metrics" -> false
    | _ -> true

/// Exclude /health, /metrics and /swagger requests from Client
let clientRequestFilter (req: HttpRequestMessage) : bool =
    match req.RequestUri.AbsolutePath.ToString() with
    | "/swagger"
    | "/health"
    | "/healthz"
    | "/metrics" -> false
    | _ -> true

/// Enrich Http Response.
let enrichHttpResponse (activity: Activity) (response: HttpResponse) =
    activity
    |> Span.addTags [
        "http.response.content_length", response.ContentLength
        "http.response.content_type", response.ContentType
    ]

/// Enrich Http Request.
let enrichHttpRequest (activity: Activity) (request: HttpRequest) =
    let context = request.HttpContext

    let user = context.User
    if user.Identity.IsAuthenticated then
        let claimsList = new StringBuilder()

        if not <| isNull user.Claims then
            for claim in user.Claims do
                claimsList.Append($"%s{claim.Type}:%s{claim.Value};") |> ignore

        if claimsList.Length > 1 then
            claimsList.Remove(claimsList.Length - 1, 1) |> ignore

        activity
        |> Span.addTags [
            "enduser.id", user.Identity.Name
            "enduser.claims", claimsList.ToString()
        ]

    activity
    |> Span.addTags [
        "meta.type", "http_request"
        "http.request.cookies.count", request.Cookies.Count
        "http.request.content_type", request.ContentType
        "http.request.content_length", request.ContentLength
        "http.client_ip", context.Connection.RemoteIpAddress
        "enduser.is_authenticated", user.Identity.IsAuthenticated
    ]

/// Enriches with database-related tags based on the provided IDbCommand.
let enrichIdb (activity: Activity) (command: Data.IDbCommand) =
    activity
    |> Span.addTags [
        // "db.name", $"%A{command.CommandType} main"
        "db.statement", command.CommandText
        "db.operation", string command.CommandType
        "db.connection_string", command.Connection.ConnectionString
        "db.parameters_count", command.Parameters.Count.ToString()
        "db.transaction_active", (command.Transaction <> null).ToString()
        "db.command_timeout", command.CommandTimeout.ToString()
    ]
