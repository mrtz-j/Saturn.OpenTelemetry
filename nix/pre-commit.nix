let
  sources = import ../lon.nix;
  pkgs = import sources.nixpkgs { };
  pre-commit = import sources.git-hooks;
in
pre-commit.run {
  src = ./.;
  # Do not run at pre-commit time
  default_stages = [
    "pre-push"
  ];
  hooks = {
    statix = {
      enable = true;
      settings.ignore = [ "lon.nix" ];
    };
    deadnix = {
      enable = true;
      excludes = [
        "lon.nix"
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
}
