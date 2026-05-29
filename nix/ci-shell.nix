{
  sources ? import ../npins,
  pkgs ? import sources.nixpkgs { },
}:
pkgs.mkShell {
  packages = [
    pkgs.lixPackageSets.latest.nix-eval-jobs
    pkgs.jq
  ];

  shellHook = ''
    eval() {
      nix-eval-jobs default.nix --check-cache-status | jq -s 'map({attr, isCached})'
    }
  '';
}
