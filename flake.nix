{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
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
      systems = [ "x86_64-linux" ];
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
          dotnet-sdk = pkgs.dotnetCorePackages.sdk_10_0;
          dotnet-runtime = pkgs.dotnetCorePackages.runtime_10_0;
          fsharp-analyzers = pkgs.buildDotnetGlobalTool {
            pname = "fsharp-analyzers";
            version = "0.35.0";
            nugetHash = "sha256-GxQR3Fq28cb+akNbzRTav9nhMtayN/0g2d1G6Ml+ck4=";
          };
        in
        {
          pre-commit = {
            check.enable = true;
            settings = {
              src = pkgs.nix-gitignore.gitignoreSource [ ] ./.;
              package = pkgs.prek;
              # Do not run at pre-commit time
              default_stages = [
                "pre-push"
              ];
              hooks = {
                deadnix.enable = true;
                nixfmt.enable = true;
                statix.enable = true;
                fantomas = {
                  enable = true;
                  name = "fantomas";
                  entry = "${pkgs.fantomas}/bin/fantomas src example";
                  files = "(\\.fs$)|(\\.fsx$)";
                };
              };
            };
          };

          packages = import ./nix/packages {
            inherit
              pkgs
              pname
              version
              dotnet-sdk
              dotnet-runtime
              ;
          };

          apps = {
            fsharp-analyzers = {
              type = "app";
              program = "${fsharp-analyzers}/bin/fsharp-analyzers";
            };
            example = {
              type = "app";
              program = "${config.packages.example}/bin/Example";
            };
          };

          devShells.default = pkgs.mkShell {
            buildInputs = [ dotnet-sdk ];

            packages = [
              pkgs.svu
              pkgs.fantomas
              pkgs.fsautocomplete
              pkgs.nuget-to-json
              fsharp-analyzers
            ];

            DOTNET_ROOT = "${dotnet-sdk.unwrapped}/share/dotnet";

            shellHook = ''
              ${config.pre-commit.installationScript}
            '';
          };
        };
    };
}
