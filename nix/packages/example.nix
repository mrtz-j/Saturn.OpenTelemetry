{
  version,
  dotnet-sdk,
  nix-gitignore,
  dotnet-runtime,
  buildDotnetModule,
  saturn-opentelemetry,
}:
buildDotnetModule {
  inherit
    version
    dotnet-sdk
    dotnet-runtime
    ;
  pname = "Example";
  name = "Example";
  buildInputs = [
    saturn-opentelemetry
  ];
  src = nix-gitignore.gitignoreSource [ ] ../../.;
  projectFile = "example/Example.fsproj";
  nugetDeps = ./deps.json; # nix-build . -A default.fetch-deps && ./result nix/deps.json
  doCheck = false;
}
