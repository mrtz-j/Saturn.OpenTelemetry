{
  pname,
  version,
  dotnet-sdk,
  dotnet-runtime,
  buildDotnetModule,
}:
buildDotnetModule {
  inherit
    pname
    version
    dotnet-sdk
    dotnet-runtime
    ;
  name = "Saturn.OpenTelemetry";
  src = ../.;
  projectFile = "src/Saturn.OpenTelemetry/Saturn.OpenTelemetry.fsproj";
  doCheck = true;
  nugetDeps = ./deps.json; # `nix build .#default.fetch-deps && ./result nix/deps.json`
}
