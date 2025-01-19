{
  lib,
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
  src = lib.cleanSource ../.;
  projectFile = "src/Saturn.OpenTelemetry/Saturn.OpenTelemetry.fsproj";
  doCheck = true;
  nugetDeps = ./deps.json; # `nix-build . -A default.fetch-deps && ./result nix/deps.json`
}
