{
  sources ? import ./deps,
  system ? builtins.currentSystem,
  pre-commit-hook ? (import sources.git-hooks).run {
    src = ./.;
    hooks = {
      nixfmt-rfc-style.enable = true;
      deadnix.enable = true;
      statix.enable = true;
      fantomas = {
        enable = true;
        name = "Fantomas formatting";
        entry = "fantomas";
        files = "(\\.fs$)|(\\.fsx$)";
      };
    };
  },
}:
let
  pname = "Saturn.OpenTelemetry";
  dotnet-sdk = pkgs.dotnetCorePackages.sdk_8_0_4xx;
  dotnet-runtime = pkgs.dotnetCorePackages.runtime_8_0;
  version = "0.3.0-alpha";
  shell = pkgs.mkShell {
    buildInputs = [
      dotnet-sdk
      pkgs.fantomas
      pkgs.fsautocomplete
      pkgs.nixfmt-rfc-style
    ];
    shellHook = ''
      ${pre-commit-hook.shellHook}
    '';
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
