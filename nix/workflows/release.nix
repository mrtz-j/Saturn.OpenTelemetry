{ nix-actions, ... }:
let
  inherit (nix-actions.lib) nix-shell secret expr;
in
{
  name = "Release";
  on = {
    push.branches = [ "main" ];
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
          uses = "DeterminateSystems/nix-installer-action@main";
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
            shell = "dotnet-shell";
          };
        }
        {
          name = "Build";
          run = nix-shell {
            script = "dotnet build --no-restore --configuration ${expr "matrix.config"}";
            shell = "dotnet-shell";
          };
        }
        {
          name = "Test";
          run = nix-shell {
            script = "dotnet test --no-build --verbosity normal --configuration ${expr "matrix.config"}";
            shell = "dotnet-shell";
          };
        }
      ];
    };

    build-nix = {
      runs-on = "ubuntu-latest";
      steps = [
        {
          name = "Checkout";
          uses = "actions/checkout@v4";
        }
        {
          name = "Install Nix";
          uses = "DeterminateSystems/nix-installer-action@main";
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
          name = "Build";
          run = "nix-build default.nix -A default";
        }
        {
          name = "Reproducibility check";
          run = "nix-build default.nix -A default --check";
        }
      ];
    };

    nuget-pack = {
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
          uses = "DeterminateSystems/nix-installer-action@main";
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
            shell = "dotnet-shell";
          };
        }
        {
          name = "Build";
          run = nix-shell {
            script = "dotnet build --no-restore --configuration Release";
            shell = "dotnet-shell";
          };
        }
        {
          name = "Pack";
          run = nix-shell {
            script = "dotnet pack --configuration Release";
            shell = "dotnet-shell";
          };
        }
        {
          name = "Upload NuGet artifact (plugin)";
          uses = "actions/upload-artifact@v4";
          "with" = {
            name = "nuget-package";
            path = "src/Saturn.OpenTelemetry/bin/Release/Saturn.OpenTelemetry.*.nupkg";
          };
        }
      ];
    };
  };
}
