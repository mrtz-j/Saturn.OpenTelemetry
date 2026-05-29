{
  sources ? import ./npins,
  pkgs ? import sources.nixpkgs { },
}:
let
  dotnet-sdk = pkgs.dotnetCorePackages.sdk_10_0;

  fsharp-analyzers = pkgs.buildDotnetGlobalTool {
    pname = "fsharp-analyzers";
    version = "0.35.0";
    nugetHash = "sha256-GxQR3Fq28cb+akNbzRTav9nhMtayN/0g2d1G6Ml+ck4=";
  };

  pre-commit = import ./nix/pre-commit.nix { inherit sources pkgs; };
in
pkgs.mkShell {
  buildInputs = [ dotnet-sdk ];
  packages = [
    pkgs.npins
    pkgs.svu
    pkgs.fantomas
    pkgs.fsautocomplete
    pkgs.nuget-to-json
    fsharp-analyzers
  ];

  DOTNET_ROOT = "${dotnet-sdk.unwrapped}/share/dotnet";

  inherit (pre-commit) shellHook;
}
