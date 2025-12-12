let
  sources = import ../npins;
  pkgs = import sources.nixpkgs { };
  pre-commit = import sources.git-hooks;

  globalExcludes = [
    "npins/default.nix"
  ];
in
pre-commit.run {
  src = pkgs.nix-gitignore.gitignoreSource [ ] ./.;
  # Do not run at pre-commit time
  default_stages = [
    "pre-push"
  ];
  package = pkgs.prek;
  hooks = {
    statix = {
      enable = true;
      settings.ignore = globalExcludes;
      excludes = globalExcludes;
    };
    deadnix = {
      enable = true;
      excludes = globalExcludes;
    };
    nixfmt-rfc-style = {
      enable = true;
      excludes = globalExcludes;
    };
    fantomas = {
      enable = true;
      name = "fantomas";
      entry = "${pkgs.fantomas}/bin/fantomas src example";
      files = "(\\.fs$)|(\\.fsx$)";
    };
  };
}
