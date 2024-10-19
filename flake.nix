{
  description = "Saturn.OpenTelemetry flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
    parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    inputs.parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;
      imports = [
        inputs.pre-commit-hooks.flakeModule
      ];
      perSystem =
        {
          config,
          pkgs,
          ...
        }:
        let
          pname = "SaturnOpenTelemetry";
          version = "0.5.0-alpha";
          dotnet-sdk = pkgs.dotnet-sdk_8;
          dotnet-runtime = pkgs.dotnetCorePackages.runtime_8_0;
        in
        {
          pre-commit = {
            check.enable = true;
            settings = {
              hooks = {
                deadnix.enable = true;
                nixfmt-rfc-style.enable = true;
                statix.enable = true;
                fantomas = {
                  enable = true;
                  name = "Fantomas formatting";
                  entry = "${pkgs.fantomas}/bin/fantomas --check src example";
                  files = "(\\.fs$)|(\\.fsx$)";
                };
              };
            };
          };
          packages = {
            default = pkgs.callPackage ./nix/saturn-opentelemetry.nix {
              inherit
                pname
                version
                dotnet-sdk
                dotnet-runtime
                ;
            };
            example = pkgs.callPackage ./nix/example.nix {
              inherit
                version
                dotnet-sdk
                ;
            };
          };
          apps.example = {
            type = "app";
            program = "${config.packages.example}/bin/Example";
          };
          devShells.default = pkgs.mkShell {
            name = "SaturnOpenTelemetry";
            buildInputs = [
              dotnet-sdk
            ];
            packages = with pkgs; [
              fantomas
              fsautocomplete
              nixfmt-rfc-style
            ];
            shellHook = ''
              ${config.pre-commit.installationScript}
            '';
          };
        };
    };
}
