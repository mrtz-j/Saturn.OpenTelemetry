{
  sources ? import ./npins,
  system ? builtins.currentSystem,
  pkgs ? import sources.nixpkgs {
    inherit system;
    config = { };
    overlays = [ ];
  },
}:
let
  pname = "SaturnOpenTelemetry";
  version = "0.6.0-alpha";
  dotnet-sdk = pkgs.dotnetCorePackages.sdk_9_0;
  dotnet-runtime = pkgs.dotnetCorePackages.aspnetcore_9_0;
  packages = import ./nix/packages {
    inherit
      pkgs
      pname
      version
      dotnet-sdk
      dotnet-runtime
      ;
  };
in
rec {
  inherit (packages) example;
  inherit (containers) container;

  default = packages.saturn-opentelemetry;

  containers = pkgs.callPackage ./nix/containers.nix {
    inherit
      version
      example
      ;
  };

  checks = {
    pre-commit = import ./nix/pre-commit.nix;
  };

  ci = pkgs.mkShellNoCC {
    name = "CI";

    packages = [
      pkgs.npins
      pkgs.svu
    ];
  };

  shell = pkgs.mkShell {
    buildInputs = [ dotnet-sdk ];

    packages = [
      pkgs.svu
      pkgs.npins

      pkgs.dotnet-outdated
      pkgs.fantomas
      pkgs.fsautocomplete
    ];

    DOTNET_CLI_TELEMETRY_OPTOUT = "true";
    DOTNET_ROOT = "${dotnet-sdk.unwrapped}/share/dotnet";
  };
}
