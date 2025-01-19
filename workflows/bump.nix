{
  name = "Weekly Npins Update";
  on = {
    schedule = [
      # Run at 00:00 UTC every Sunday
      { cron = "0 0 * * 1"; }
    ];
    # Allow manual trigger
    workflow_dispatch = { };
  };
  jobs.npins_update = {
    runs-on = "ubuntu-latest";
    permissions = {
      contents = "write";
      pull-requests = "write";
      actions = "write";
    };
    steps = [
      {
        uses = "actions/checkout@v4";
        "with" = {
          depth = 0;
          token = "\${{ secrets.GITHUB_TOKEN}}";
        };
      }
      {
        uses = "DeterminateSystems/nix-installer-action@v14";
        "with" = {
          diagnostic-endpoint = "";
          source-url = "https://install.lix.systems/lix/lix-installer-x86_64-linux";
        };
      }
      {
        name = "Update dependencies";
        run = ''
          nix-shell default.nix -A ci --run "npins -d ./nix update"
        '';
      }
      {
        name = "Create PR";
        uses = "peter-evans/create-pull-request@v7";
        "with" = {
          token = "\${{ secrets.GITHUB_TOKEN }}";
          commit-message = "chore: npins update";
          title = "chore: weekly npins update";
          body = ''
            Automatic npins update performed by GitHub Actions
          '';
          branch = "npins-auto-update";
          delete-branch = true;
          base = "main";
        };
      }
    ];
  };
}
