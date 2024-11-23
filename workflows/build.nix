{
  name = "Build";
  on = {
    push.branches = [ "main" ];
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
          uses = "cachix/install-nix-action@V28";
        }
        {
          name = "Set up cachix";
          uses = "cachix/cachix-action@v15";
          "with" = {
            name = "saturnopentelemetry";
            authToken = "\${{ secrets.CACHIX_AUTH_TOKEN }}";
          };
        }
        {
          name = "Restore dependencies";
          run = "nix -Lv develop -f . default --command dotnet restore";
        }
        {
          name = "Build";
          run = "nix -Lv develop -f . default --command dotnet build --no-restore --configuration \${{matrix.config}}";
        }
        {
          name = "Test";
          run = "nix -Lv develop -f . default --command dotnet test --no-build --verbosity normal --configuration \${{matrix.config}}";
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
          uses = "cachix/install-nix-action@V28";
        }
        {
          name = "Set up cachix";
          uses = "cachix/cachix-action@v15";
          "with" = {
            name = "saturnopentelemetry";
            authToken = "\${{ secrets.CACHIX_AUTH_TOKEN }}";
          };
        }
        {
          name = "Build";
          run = "nix -Lv build -f . default";
        }
        {
          name = "Reproducibility check";
          run = "nix -Lv build -f . default --rebuild";
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
          uses = "cachix/install-nix-action@V28";
        }
        {
          name = "Set up cachix";
          uses = "cachix/cachix-action@v15";
          "with" = {
            name = "saturnopentelemetry";
            authToken = "\${{ secrets.CACHIX_AUTH_TOKEN }}";
          };
        }
        {
          name = "Restore dependencies";
          run = "nix -Lv develop -f . default --command dotnet restore";
        }
        {
          name = "Build";
          run = "nix -Lv develop -f . default --command dotnet build --no-restore --configuration Release";
        }
        {
          name = "Pack";
          run = "nix -Lv develop -f . default --command dotnet pack --configuration Release";
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
