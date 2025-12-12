{ nix-actions, ... }:
let
  inherit (nix-actions.lib) expr;
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
              nix-shell -A ci-shell --run eval-checks
              echo 'EOF'
            } >> "$GITHUB_OUTPUT"
          '';
        }
      ];
    };
    build-nix = {
      needs = [ "eval" ];
      runs-on = "ubuntu-latest";
      strategy.matrix.derivation = "${expr "fromJson(needs.eval.outputs.stdout)"}";
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
