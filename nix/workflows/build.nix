{ nix-actions, ... }:
let
  inherit (nix-actions.lib) nix-shell secret expr;
in
{
  name = "Build";
  on = {
    pull_request.branches = [ "main" ];
  };
  env = {
    FORCE_COLOR = "1";
    DOTNET_NOLOGO = "true";
    DOTNET_CLI_TELEMETRY_OPTOUT = "true";
    DOTNET_SKIP_FIRST_TIME_EXPERIENCE = "true";
    NUGET_XMLDOC_MODE = "";
    DOTNET_MULTILEVEL_LOOKUP = "0";
  };
  jobs = {
    eval = {
      runs-on = "ubuntu-latest";
      outputs = {
        "stdout" = "${expr "steps.nix-eval-jobs.outputs.stdout"}";
      };
      steps = [
        {
          uses = "actions/checkout@v6";
          "with" = {
            fetch-depth = 0;
          };
        }
        {
          name = "Install Nix";
          uses = "samueldr/lix-gha-installer-action@v2025-10-27";
        }
        {
          name = "Set up cache";
          uses = "DeterminateSystems/magic-nix-cache-action@v13";
          "with" = {
            diagnostic-endpoint = "";
          };
        }
        {
          name = "Run nix-eval-jobs";
          id = "nix-eval-jobs";
          run = ''
               {
              echo 'stdout<<EOF'
              nix-shell -A ci-shell --run eval
              echo 'EOF'
            } >> "$GITHUB_OUTPUT"
          '';
        }
      ];
    };
    build = {
      strategy.matrix.config = [
        "Release"
        "Debug"
      ];
      runs-on = "ubuntu-latest";
      steps = [
        {
          uses = "actions/checkout@v4";
          "with" = {
            fetch-depth = 0;
          };
        }
        {
          name = "Install Nix";
          uses = "DeterminateSystems/nix-installer-action@v20";
          "with" = {
            github-token = secret "GITHUB_TOKEN";
            diagnostic-endpoint = "";
            source-url = "https://install.lix.systems/lix/lix-installer-x86_64-linux";
          };
        }
        {
          name = "Set up cachix";
          uses = "cachix/cachix-action@v16";
          "with" = {
            name = "saturnopentelemetry";
            authToken = secret "CACHIX_AUTH_TOKEN";
          };
        }
        {
          name = "Restore dependencies";
          run = nix-shell {
            script = "dotnet restore";
            shell = "ci-shell";
          };
        }
        {
          name = "Build";
          run = nix-shell {
            script = "dotnet build --no-restore --configuration ${expr "matrix.config"}";
            shell = "ci-shell";
          };
        }
        {
          name = "Test";
          run = nix-shell {
            script = "dotnet test --no-build --verbosity normal --configuration ${expr "matrix.config"}";
            shell = "ci-shell";
          };
        }
      ];
    };
    build-nix = {
      needs = [ "eval" ];
      runs-on = "ubuntu-latest";
      strategy.matrix.derivation = "${expr "fromJson(needs.eval.outputs.sdout)"}";
      steps = [
        {
          uses = "actions/checkout@v6";
          "with" = {
            fetch-depth = 0;
          };
        }
        {
          name = "Install Nix";
          uses = "samueldr/lix-gha-installer-action@v2025-10-27";
        }
        {
          name = "Set up cache";
          uses = "DeterminateSystems/magic-nix-cache-action@v13";
          "with" = {
            diagnostic-endpoint = "";
          };
        }
        {
          name = "Build ${expr "matrix.derivation.attr"}";
          run = "nix-build default.nix -A ${expr "matrix.derivation.attr"}";
          "if" = "${expr "! matrix.derivation.isCached"}";
        }
        {
          name = "Reproducibility check";
          run = "nix-build default.nix -A default --check";
        }
      ];
    };
    build-nix-status = {
      needs = [ "build-nix" ];
      runs-on = "ubuntu-latest";
      "if" = "always()";
      steps = [
        {
          run = "${expr "!contains(needs.build.result, 'failure')"}";
        }
      ];
    };
  };
}
