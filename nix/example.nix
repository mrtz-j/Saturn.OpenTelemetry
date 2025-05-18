{
  lib,
  version,
  dotnet-sdk,
  dotnetCorePackages,
  buildDotnetModule,
}:
buildDotnetModule {
  inherit version dotnet-sdk;
  pname = "Example";
  name = "Example";
  src = lib.cleanSource ../.;
  dotnet-runtime = dotnetCorePackages.dotnet_9.aspnetcore;
  projectFile = "example/Example.fsproj";
  executables = [ "Example" ];
  nugetDeps = ./deps-example.json; # nix-build . -A example.fetch-deps && ./result nix/deps-example.json
  doCheck = true;
}
