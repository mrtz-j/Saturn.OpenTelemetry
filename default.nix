{
  sources ? import ./npins,
  system ? builtins.currentSystem,
  pkgs ? import sources.nixpkgs {
    inherit system;
    config = { };
    overlays = [ ];
  },
  pre-commit ? import ./nix/pre-commit.nix,
  workflows ? import ./nix/workflows.nix,
}:
let
  pname = "SaturnOpenTelemetry";
  version = "0.6.0-alpha";
  dotnet-sdk = pkgs.dotnetCorePackages.sdk_10_0;
  dotnet-runtime = pkgs.dotnetCorePackages.aspnetcore_10_0;
  packages = import ./nix/packages {
    inherit
      pkgs
      pname
      version
      dotnet-sdk
      dotnet-runtime
      ;
  };
  fsharp-analyzers = pkgs.buildDotnetGlobalTool {
    pname = "fsharp-analyzers";
    version = "0.34.1 ";
    nugetHash = "sha256-Y6PzfVGob2EgX29ZhZIde5EhiZ28Y1+U2pJ6ybIsHV0=";
  };
in
{
  inherit packages;
  default = packages.saturn-opentelemetry;

  shell = pkgs.mkShell {
    buildInputs = [ dotnet-sdk ];

    packages = [
      pkgs.dotnet-outdated
      pkgs.fantomas
      pkgs.fsautocomplete
      pkgs.npins
      fsharp-analyzers
    ];

    DOTNET_ROOT = "${dotnet-sdk}/share/dotnet";

    shellHook = builtins.concatStringsSep "\n" [
      pre-commit.shellHook
      workflows.shellHook
      "unset shellHook # do not contaminate nested shells"
    ];

    passthru = pkgs.lib.mapAttrs (name: value: pkgs.mkShell (value // { inherit name; })) {
      ci-shell = {
        packages = [
          dotnet-sdk
          pkgs.lixPackageSets.latest.nix-eval-jobs
          pkgs.jq
        ];

        shellHook = ''
          eval-checks() {
            nix-eval-jobs default.nix --check-cache-status | jq -s 'map({attr, isCached})'
          }
        '';
      };
    };
  };
}
