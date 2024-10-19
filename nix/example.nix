{
  dotnet-sdk_8,
  dotnet-aspnetcore_8,
  buildDotnetModule,
}:
buildDotnetModule {
  pname = "Example";
  name = "Example";
  version = "0.1.0";
  src = ../.;
  dotnet-sdk = dotnet-sdk_8;
  dotnet-runtime = dotnet-aspnetcore_8;
  projectFile = "example/Example.fsproj";
  executables = [ "Example" ];
  nugetDeps = ./deps-example.nix; # nix -Lv build .#example.passthru.fetch-deps && ./result nix/deps-example.nix
}
