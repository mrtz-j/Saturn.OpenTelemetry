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
    nix-actions = {
      url = "git+https://forgejo@git.dgnum.eu/DGNum/nix-actions";
      flake = false;
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
          lib,
          ...
        }:
        let
          pname = "SaturnOpenTelemetry";
          version = "0.5.1-alpha";
          dotnet-sdk = pkgs.dotnetCorePackages.dotnet_9.sdk;
          dotnet-runtime = pkgs.dotnetCorePackages.dotnet_9.runtime;
          workflows = (import inputs.nix-actions { inherit pkgs; }).install {
            src = ./.;
            platform = "github";
            workflows = lib.mapAttrs' (
              name: _:
              lib.nameValuePair (lib.removeSuffix ".nix" name) (
                let
                  w = import ./workflows/${name};
                in
                if lib.isFunction w then w { inherit (pkgs) lib; } else w
              )
            ) (builtins.readDir ./workflows);
          };
        in
        {
          pre-commit = {
            check.enable = true;
            settings = {
              src = ./.;
              hooks = {
                statix.enable = true;
                deadnix.enable = true;
                nixfmt-rfc-style.enable = true;
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
            example = pkgs.callPackage ./nix/example.nix { inherit version dotnet-sdk; };
          };
          apps.example = {
            type = "app";
            program = "${config.packages.example}/bin/Example";
          };
          devShells.default = pkgs.mkShell {
            name = "SaturnOpenTelemetry";
            packages = with pkgs; [
              dotnet-sdk
            ];
            DOTNET_CLI_TELEMETRY_OPTOUT = "true";
            DOTNET_ROOT = "${dotnet-sdk.unwrapped}/share/dotnet";
            shellHook = ''
              ${workflows.shellHook}
              ${config.pre-commit.installationScript}
            '';
          };
        };
    };
}
