{
  sources ? import ./nix,
  system ? builtins.currentSystem,
  pkgs ? import sources.nixpkgs {
    inherit system;
    config = { };
    overlays = [ ];
  },
  pre-commit ? (import sources.git-hooks).run {
    src = ./.;
    hooks = {
      statix.enable = true;
      deadnix.enable = true;
      nixfmt-rfc-style.enable = true;
      fantomas = {
        enable = true;
        name = "Fantomas formatting";
        entry = "${pkgs.fantomas}/bin/fantomas --check src example";
        files = "(\\.fs$)|(\\.fsx$)";
      };
    };
  },
}:
let
  inherit (pkgs.lib)
    isFunction
    mapAttrs'
    nameValuePair
    removeSuffix
    ;

  pname = "SaturnOpenTelemetry";
  version = "0.5.1-alpha";
  dotnet-sdk = pkgs.dotnetCorePackages.sdk_8_0;
  dotnet-runtime = pkgs.dotnetCorePackages.runtime_8_0;
  workflows = (import sources.nix-actions { inherit pkgs; }).install {
    src = ./.;
    platform = "github";
    workflows = mapAttrs' (
      name: _:
      nameValuePair (removeSuffix ".nix" name) (
        let
          w = import ./workflows/${name};
        in
        if isFunction w then w { inherit (pkgs) lib; } else w
      )
    ) (builtins.readDir ./workflows);
  };
in
{
  default = pkgs.callPackage ./nix/package.nix {
    inherit
      pname
      version
      dotnet-sdk
      dotnet-runtime
      ;
  };
  example = pkgs.callPackage ./nix/example.nix { inherit version dotnet-sdk; };
  shell = pkgs.mkShell {
    name = "SaturnOpenTelemetry";
    nativeBuildInputs = with pkgs; [
      dotnet-sdk
      fantomas
      npins
      nixfmt-rfc-style
    ];
    DOTNET_CLI_TELEMETRY_OPTOUT = "true";
    DOTNET_ROOT = "${pkgs.dotnet-sdk_8}";
    shellHook = ''
      ${pre-commit.shellHook}
      ${workflows.shellHook}
    '';
  };
}
