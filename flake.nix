{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  nixConfig = {
    extra-substituters = "https://cache.garnix.io";
    extra-trusted-public-keys = "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g=";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      eachSystem = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = eachSystem (
        system:
        let
          pkgSet = import ./default.nix { pkgs = nixpkgs.legacyPackages."${system}"; };
        in
        {
          default = pkgSet.default;
          inherit (pkgSet)
            example
            container
            ;
        }
      );

      apps = eachSystem (system: {
        example = {
          type = "app";
          program = nixpkgs.lib.getExe self.packages.${system}.example;
        };
      });
    };
}
