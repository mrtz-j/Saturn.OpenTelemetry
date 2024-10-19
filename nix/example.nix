{
  version,
  dotnet-sdk,
  dotnet-aspnetcore_8,
  buildDotnetModule,
}:
buildDotnetModule {
  inherit version dotnet-sdk;
  pname = "Example";
  name = "Example";
  src = ../.;
  dotnet-runtime = dotnet-aspnetcore_8;
  projectFile = "example/Example.fsproj";
  executables = [ "Example" ];
  nugetDeps = ./deps-example.nix; # nix -Lv build .#example.passthru.fetch-deps && ./result nix/deps-example.nix
}
