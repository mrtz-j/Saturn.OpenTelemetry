{
  sources ? import ./npins,
  system ? builtins.currentSystem,
  pkgs ? import sources.nixpkgs {
    inherit system;
    config = { };
    overlays = [ ];
  },
  pre-commit ? (import sources.git-hooks).run {
    src = ./.;
    # Do not run at pre-commit time
    default_stages = [
      "pre-push"
    ];
    hooks = {
      statix = {
        enable = true;
        settings.ignore = [ "npins/default.nix" ];
      };
      deadnix = {
        enable = true;
        excludes = [ "npins/default.nix" ];
      };
      nixfmt-rfc-style.enable = true;
      fantomas = {
        enable = true;
        name = "fantomas";
        entry = "${pkgs.fantomas}/bin/fantomas src example";
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
  version = "0.6.0-alpha";
  dotnet-sdk = pkgs.dotnetCorePackages.sdk_9_0;
  dotnet-runtime = pkgs.dotnetCorePackages.runtime_9_0;

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

  ci = pkgs.mkShellNoCC {
    name = "CI";

    packages = [
      pkgs.npins
      pkgs.svu
    ];
  };

  shell = pkgs.mkShell {
    name = "SaturnOpenTelemetry";

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

    shellHook = ''
      ${pre-commit.shellHook}
      ${workflows.shellHook}
    '';
  };
}
