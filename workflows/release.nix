{
  name = "Release";
  on.push.tags = [ "*.*.*" ];
  env = {
    FORCE_COLOR = "1";
    DOTNET_NOLOGO = "true";
    DOTNET_CLI_TELEMETRY_OPTOUT = "true";
    DOTNET_SKIP_FIRST_TIME_EXPERIENCE = "true";
    NUGET_XMLDOC_MODE = "";
    DOTNET_MULTILEVEL_LOOKUP = "0";
  };
  jobs = {
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
          run = "nix-shell default.nix -A default --run 'dotnet restore'";
        }
        {
          name = "Build";
          run = "nix-shell default.nix -A default --run 'dotnet build --no-restore --configuration Release'";
        }
        {
          name = "Pack";
          run = "nix-shell default.nix -A default --run 'dotnet pack --configuration Release'";
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

    nuget-publish = {
      runs-on = "ubuntu-latest";
      needs = [ "nuget-pack" ];
      permissions = {
        id-token = "write";
        # attestations = "write";
        contents = "read";
      };
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
          name = "Download NuGet artifact";
          uses = "actions/download-artifact@v4";
          "with" = {
            name = "nuget-package";
            path = "packed";
          };
        }
        {
          name = "Prep packages";
          run = "nix-shell default.nix -A default --run 'dotnet nuget add source --username mrtz-j --password \${{ secrets.NUGET_AUTH_TOKEN }} --store-password-in-clear-text --name github \"https://nuget.pkg.github.com/mrtz-j/index.json\"'";
        }
        {
          name = "Publish GitHub package";
          run = "nix-shell default.nix -A default --run 'dotnet nuget push packed/*.nupkg --api-key \${{ secrets.NUGET_AUTH_TOKEN }}  --source \"github\" --skip-duplicate'";
        }
        {
          name = "Identify .NET";
          id = "identify-dotnet";
          run = "nix-shell default.nix -A default --run 'bash -c 'echo \"dotnet=$(which dotnet)\" >> $GITHUB_OUTPUT''";
        }
        {
          name = "Publish NuGet package";
          uses = "G-Research/common-actions/publish-nuget@2b7dc49cb14f3344fbe6019c14a31165e258c059";
          "with" = {
            package-name = "Saturn.OpenTelemetry";
            nuget-key = "\${{ secrets.NUGET_API_KEY }}";
            nupkg-dir = "packed/";
            dotnet = "\${{ steps.identify-dotnet.outputs.dotnet }}";
          };
        }
      ];
    };

    create-github-release = {
      runs-on = "ubuntu-latest";
      needs = [ "nuget-publish" ];
      permissions.contents = "write";
      steps = [
        {
          name = "Checkout code";
          uses = "actions/checkout@v4";
          "with" = {
            token = "\${{ github.token }}";
          };
        }
        {
          name = "Create Release";
          run = "gh release create \${{ github.ref }} --generate-notes";
          env.GITHUB_TOKEN = "\${{ secrets.GITHUB_TOKEN }}";
        }
      ];
    };
  };
}
