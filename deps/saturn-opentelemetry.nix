{
  pname,
  version,
  dotnet-sdk,
  dotnet-runtime,
  pkgs,
}:
pkgs.buildDotnetModule rec {
  inherit
    pname
    version
    dotnet-sdk
    dotnet-runtime
    ;
  name = "Saturn.OpenTelemetry";
  src = ../.;
  projectFile = "src/Saturn.OpenTelemetry/Saturn.Opentelemetry.fsproj";
  nugetDeps = ./deps.nix;
}
