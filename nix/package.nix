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
  nugetDeps = ./deps.nix; # `nix build .#default.passthru.fetch-deps && ./result nix/deps.nix`
}
