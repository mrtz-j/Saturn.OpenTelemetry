{
  description = "Saturn.OpenTelemetry flake";

  nixConfig = {
    extra-substituters = "https://cache.garnix.io";
    extra-trusted-public-keys = "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g=";
  };

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
          version = "0.6.0-alpha";
          dotnet-sdk = pkgs.dotnetCorePackages.sdk_9_0;
          dotnet-runtime = pkgs.dotnetCorePackages.runtime_9_0;
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
                  entry = "${pkgs.fantomas}/bin/fantomas src example";
                  files = "(\\.fs$)|(\\.fsx$)";
                };
              };
            };
          };

          packages = {
            default = pkgs.callPackage ./nix/package.nix {
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

            buildInputs = [ dotnet-sdk ];

            packages = [
              pkgs.svu
              pkgs.fantomas
              pkgs.fsautocomplete
            ];

            DOTNET_CLI_TELEMETRY_OPTOUT = "true";
            DOTNET_ROOT = "${dotnet-sdk.unwrapped}/share/dotnet";

            shellHook = ''
              ${config.pre-commit.installationScript}
            '';
          };
        };
    };
}
