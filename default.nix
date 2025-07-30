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
        excludes = [
          "npins/default.nix"
          "flake.nix"
        ];
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
  pname = "SaturnOpenTelemetry";
  version = "0.6.0-alpha";
  dotnet-sdk = pkgs.dotnetCorePackages.sdk_9_0;
  dotnet-runtime = pkgs.dotnetCorePackages.runtime_9_0;
in
rec {
  default = pkgs.callPackage ./nix/package.nix {
    inherit
      pname
      version
      dotnet-sdk
      dotnet-runtime
      ;
  };

  example = pkgs.callPackage ./nix/example.nix { inherit version dotnet-sdk; };

  container = pkgs.dockerTools.buildLayeredImage {
    name = "Example";
    tag = version;
    created = "now";
    contents = [
      example
      pkgs.dockerTools.binSh
      pkgs.dockerTools.caCertificates
    ];
    config = {
      cmd = [
        "${example}/bin/Example"
      ];
      workingDir = "/app";
    };
  };

  ci = pkgs.mkShellNoCC {
    name = "CI";

    packages = [
      pkgs.npins
      pkgs.svu
    ];
  };

  shell = pkgs.mkShellNoCC {
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
    '';
  };
}
