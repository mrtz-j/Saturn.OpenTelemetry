{ nix-actions, ... }:
let
  inherit (nix-actions.lib) nix-shell secret;
in
{
  name = "Update dependencies";
  on = {
    schedule = [
      # Run at 06:06 on Wednesday
      # This should avoid spikes in usage caused by other scheduled jobs
      { cron = "6 6 * * 3"; }
    ];
    # Allow manual trigger
    workflow_dispatch = { };
  };
  env = {
    FORCE_COLOR = "1";
  };
  jobs = {
    update = {
      runs-on = "ubuntu-latest";
      permissions = {
        contents = "write";
        pull-requests = "write";
        issues = "write";
      };
      steps = [
        {
          uses = "actions/checkout@v4";
          "with".fetch-depth = 0;
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
          name = "Set up Cache";
          uses = "DeterminateSystems/magic-nix-cache-action@main";
        }
        {
          env = {
            LON_TOKEN = secret "GITHUB_TOKEN";
            LON_LABELS = "bot";
            LON_LIST_COMMITS = true;
          };

          run = nix-shell {
            script = "lon bot github";
            shell = "lon-update";
          };
        }
        # TODO: Currently broken in pipeline :/
        # {
        #   name = "Build fetch deps";
        #   run = "nix-build -A packages.example.fetch-deps";
        # }
        # {
        #   name = "Update dotnet deps";
        #   run = "./result nix/packages/deps.json";
        # }
        # }
      ];
    };
  };
}
