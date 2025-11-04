let
  sources = import ../nix;
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
      settings.ignore = [ "nix/default.nix" ];
    };
    deadnix = {
      enable = true;
      excludes = [
        "nix/default.nix"
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
