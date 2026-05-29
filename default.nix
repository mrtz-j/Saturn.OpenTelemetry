{
  system ? builtins.currentSystem,
  sources ? import ./npins,
  pkgs ? import sources.nixpkgs { inherit system; },
}:
let
  inherit (pkgs) lib;

  pname = "SaturnOpenTelemetry";
  version = "0.7.0-rc";

  dotnet-sdk = pkgs.dotnetCorePackages.sdk_10_0;
  dotnet-runtime = pkgs.dotnetCorePackages.runtime_10_0;

  fsharp-analyzers = pkgs.buildDotnetGlobalTool {
    pname = "fsharp-analyzers";
    version = "0.35.0";
    nugetHash = "sha256-GxQR3Fq28cb+akNbzRTav9nhMtayN/0g2d1G6Ml+ck4=";
  };
in
rec {
  packages = lib.recurseIntoAttrs (
    import ./nix/packages {
      inherit
        pkgs
        pname
        version
        dotnet-sdk
        dotnet-runtime
        ;
    }
  );

  checks = lib.recurseIntoAttrs {
    pre-commit = import ./nix/pre-commit.nix { inherit sources pkgs; };
  };

  apps = lib.recurseIntoAttrs {
    inherit fsharp-analyzers;
    nuget-publish = import ./nix/nuget-publish.nix {
      inherit pkgs dotnet-sdk;
      inherit (packages) saturn-opentelemetry;
    };
  };
}
