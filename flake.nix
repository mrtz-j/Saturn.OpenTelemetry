{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      pre-commit-hooks,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forEachSystem = nixpkgs.lib.genAttrs systems;

      pname = "SaturnOpenTelemetry";
      version = "0.6.0-alpha";

      mkPackages =
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          dotnet-sdk = pkgs.dotnetCorePackages.sdk_10_0;
          dotnet-runtime = pkgs.dotnetCorePackages.runtime_10_0;
        in
        import ./nix/packages {
          inherit
            pkgs
            pname
            version
            dotnet-sdk
            dotnet-runtime
            ;
        };

      mkFsharpAnalyzers =
        pkgs:
        pkgs.buildDotnetGlobalTool {
          pname = "fsharp-analyzers";
          version = "0.35.0";
          nugetHash = "sha256-GxQR3Fq28cb+akNbzRTav9nhMtayN/0g2d1G6Ml+ck4=";
        };
    in
    {
      packages = forEachSystem mkPackages;

      checks = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          pre-commit-check = pre-commit-hooks.lib.${system}.run {
            src = pkgs.nix-gitignore.gitignoreSource [ ] ./.;
            package = pkgs.prek;
            hooks = {
              deadnix.enable = true;
              nixfmt.enable = true;
              statix.enable = true;
              fantomas = {
                enable = true;
                name = "fantomas";
                entry = "${pkgs.fantomas}/bin/fantomas src example";
                files = "(\\.fs$)|(\\.fsx$)";
              };
            };
            default_stages = [ "pre-push" ];
          };
        }
      );

      apps =
        let
          mkApps =
            system:
            let
              pkgs = nixpkgs.legacyPackages.${system};
              fsharp-analyzers = mkFsharpAnalyzers pkgs;
              packages = mkPackages system;
            in
            {
              fsharp-analyzers = {
                type = "app";
                program = "${fsharp-analyzers}/bin/fsharp-analyzers";
              };
              example = {
                type = "app";
                program = "${packages.example}/bin/Example";
              };
            };

          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          dotnet-sdk = pkgs.dotnetCorePackages.sdk_10_0;
          packages = mkPackages "x86_64-linux";

          nugetPublish = pkgs.writeShellApplication {
            name = "nuget-publish";
            runtimeInputs = [
              pkgs.age
              dotnet-sdk
            ];
            text = ''
              if [ "''${GARNIX_BRANCH:-}" != "main" ]; then
                echo "Skipping publish on branch ''${GARNIX_BRANCH:-unknown}"
                exit 0
              fi

              export DOTNET_ROOT="${dotnet-sdk.unwrapped}/share/dotnet"
              export SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"

              NUGET_AUTH_TOKEN=$(age --decrypt -i "$GARNIX_ACTION_PRIVATE_KEY_FILE" ${./secrets/nuget-auth-token.age})
              NUGET_API_KEY=$(age --decrypt -i "$GARNIX_ACTION_PRIVATE_KEY_FILE" ${./secrets/nuget-api-key.age})

              NUPKG=$(find ${packages.saturn-opentelemetry} -name "*.nupkg" | head -1)
              if [ -z "$NUPKG" ]; then
                echo "No .nupkg found in ${packages.saturn-opentelemetry}"
                exit 1
              fi
              echo "Publishing $NUPKG"

              dotnet nuget remove source github 2>/dev/null || true
              dotnet nuget add source \
                --username mrtz-j \
                --password "$NUGET_AUTH_TOKEN" \
                --store-password-in-clear-text \
                --name github \
                "https://nuget.pkg.github.com/mrtz-j/index.json"

              dotnet nuget push "$NUPKG" \
                --api-key "$NUGET_AUTH_TOKEN" \
                --source github \
                --skip-duplicate

              dotnet nuget push "$NUPKG" \
                --api-key "$NUGET_API_KEY" \
                --source "https://api.nuget.org/v3/index.json" \
                --skip-duplicate
            '';
          };

          baseApps = forEachSystem mkApps;
        in
        baseApps
        // {
          x86_64-linux = baseApps.x86_64-linux // {
            nuget-publish = {
              type = "app";
              program = "${nugetPublish}/bin/nuget-publish";
            };
          };
        };

      devShells = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          dotnet-sdk = pkgs.dotnetCorePackages.sdk_10_0;
          fsharp-analyzers = mkFsharpAnalyzers pkgs;
        in
        {
          default = pkgs.mkShell {
            buildInputs = [ dotnet-sdk ];
            packages = [
              pkgs.svu
              pkgs.fantomas
              pkgs.fsautocomplete
              pkgs.nuget-to-json
              fsharp-analyzers
            ];
            DOTNET_ROOT = "${dotnet-sdk.unwrapped}/share/dotnet";
            shellHook = self.checks.${system}.pre-commit-check.shellHook;
          };
        }
      );
    };
}
