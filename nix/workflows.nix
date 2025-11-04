let
  sources = import ../nix;
  pkgs = import sources.nixpkgs { };
  nix-actions = import sources.nix-actions { inherit pkgs; };
  inherit (pkgs) lib;
in
nix-actions.install {
  src = ../.;
  platform = "github";
  workflows = lib.mapAttrs' (
    name: _:
    lib.nameValuePair (lib.removeSuffix ".nix" name) (
      let
        w = import ./workflows/${name};
        args = {
          inherit nix-actions;
          inherit (pkgs) lib;
        };
      in
      if (lib.isFunction w) then (w args) else w
    )
  ) (builtins.readDir ./workflows);
}
