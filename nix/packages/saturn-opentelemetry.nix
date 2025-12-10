{
  pname,
  version,
  dotnet-sdk,
  nix-gitignore,
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
  name = pname;
  src = nix-gitignore.gitignoreSource [ ] ../../.;
  projectFile = "src/Saturn.OpenTelemetry/Saturn.OpenTelemetry.fsproj";
  nugetDeps = ./deps.json; # nix-build -A default.fetch-deps && ./result nix/deps.json
  doCheck = false;
  nupkg = true;
}
