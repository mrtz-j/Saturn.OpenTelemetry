{
  description = "Saturn.OpenTelemetry";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forEachSystem = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forEachSystem (
        system:
        let
          top = import ./default.nix { inherit system; };
        in
        {
          inherit (top.packages) default saturn-opentelemetry example;
        }
      );

      apps = forEachSystem (
        system:
        let
          top = import ./default.nix { inherit system; };
        in
        {
          nuget-publish = {
            type = "app";
            program = "${top.apps.nuget-publish}/bin/nuget-publish";
          };
          fsharp-analyzers = {
            type = "app";
            program = "${top.apps.fsharp-analyzers}/bin/fsharp-analyzers";
          };
        }
      );

    };
}
