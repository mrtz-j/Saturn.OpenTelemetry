{
  sources ? import ../npins,
  pkgs ? import sources.nixpkgs { },
}:
let
  pre-commit = import sources.pre-commit-hooks;
in
pre-commit.run {
  src = pkgs.nix-gitignore.gitignoreSource [ ] ../.;
  package = pkgs.prek;
  hooks = {
    deadnix = {
      enable = true;
      excludes = [ "^npins/" ];
    };
    nixfmt.enable = true;
    statix = {
      enable = true;
      excludes = [ "^npins/" ];
    };
    fantomas = {
      enable = true;
      name = "fantomas";
      entry = "${pkgs.fantomas}/bin/fantomas src example";
      files = "(\\.fs$)|(\\.fsx$)";
    };
  };
  default_stages = [ "pre-push" ];
}
