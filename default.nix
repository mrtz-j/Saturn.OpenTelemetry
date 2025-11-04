{
  sources ? import ./nix,
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
  fsharp-analyzers = pkgs.buildDotnetGlobalTool {
    pname = "fsharp-analyzers";
    version = "0.33.1 ";
    nugetHash = "sha256-vYXvqnf3en487svFv3CmNl24SolwMYzu6zKKGXNxSu8=";
  };
in
{
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

    DOTNET_CLI_TELEMETRY_OPTOUT = "true";
    DOTNET_ROOT = "${dotnet-sdk.unwrapped}/share/dotnet";
    NPINS_DIRECTORY = "nix";

    shellHook = builtins.concatStringsSep "\n" [
      pre-commit.shellHook
      workflows.shellHook
      "unset shellHook # do not contaminate nested shells"
    ];

    passthru = pkgs.lib.mapAttrs (name: value: pkgs.mkShellNoCC (value // { inherit name; })) {
      dotnet-shell.packages = [
        dotnet-sdk
        pkgs.bash
      ];
    };
  };
}
