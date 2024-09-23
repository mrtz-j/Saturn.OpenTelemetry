{
  sources ? import ./deps,
  system ? builtins.currentSystem,
}:
let
  pname = "Saturn.OpenTelemetry";
  dotnet-sdk = pkgs.dotnet-sdk_8;
  dotnet-runtime = pkgs.dotnetCorePackages.runtime_8_0;
  version = "0.0.1";
  shell = pkgs.mkShell {
    nativeBuildInputs = [
      dotnet-sdk
      pkgs.fantomas
      pkgs.netcoredbg
      pkgs.fsautocomplete
    ];

    DOTNET_ROOT = "${dotnet-sdk}";
  };
  pkgs = import sources.nixpkgs {
    inherit system;
    config = { };
    overlays = [ ];
  };
in
{
  inherit shell;
  default = pkgs.callPackage ./deps/saturn-opentelemetry.nix {
    inherit
      pname
      version
      dotnet-sdk
      dotnet-runtime
      pkgs
      ;
  };
}
