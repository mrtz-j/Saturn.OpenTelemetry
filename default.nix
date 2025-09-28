{
  sources ? import ./lon.nix,
  pkgs ? import sources.nixpkgs { },
  pre-commit ? import ./nix/pre-commit.nix,
  workflows ? import ./nix/workflows.nix,
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
  inherit packages;

  default = packages.saturn-opentelemetry;

  containers = pkgs.callPackage ./nix/containers.nix {
    inherit (packages)
      example
      ;
    inherit
      version
      ;
  };

  shell = pkgs.mkShell {
    buildInputs = [ dotnet-sdk ];

    packages = [
      pkgs.dotnet-outdated
      pkgs.fantomas
      pkgs.fsautocomplete
    ];

    DOTNET_CLI_TELEMETRY_OPTOUT = "true";
    DOTNET_ROOT = "${dotnet-sdk.unwrapped}/share/dotnet";

    passthru = pkgs.lib.mapAttrs (name: value: pkgs.mkShellNoCC (value // { inherit name; })) {
      pre-commit.shellHook = pre-commit.shellHook;
      workflows.shellHook = workflows.shellHook;
      dotnet-shell.packages = [ dotnet-sdk ];
      lon-update.packages = [
        pkgs.lon
        pkgs.svu
      ];
    };
  };
}
