{
  name = "update npins";
  on.schedule = [
    # Run at 00:00 UTC every Sunday
    { cron = "0 0 * * 1"; }
  ];
  jobs.npins_update = {
    runs-on = "ubuntu-latest";
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
          nix -Lv develop -f . default --command npins update -d nix
        '';
      }
      {
        name = "Build passthru";
        run = ''
          nix -Lv build -f . default.passthru.fetch-deps
        '';
      }
      {
        name = "Run passthru";
        run = ''
          ./result nix/deps.nix
        '';
      }
      {
        uses = "EndBug/add-and-commit@v9";
        "with" = {
          default_author = "github_actions";
          message = "chore(npins): Update deps";
          fetch = false;
          new_branch = "npins";
          push = "--set-upstream origin npins --force";
        };
      }
      {
        uses = "thomaseizinger/create-pull-request@1.4.0";
        "if" = "\${{ steps.commit.outputs.pushed == 'true' }}";
        "with" = {
          github_token = "\${{ secrets.GITHUB_TOKEN }}";
          head = "npins";
          base = "main";
          title = "chore(npins): Update deps";
        };
      }
    ];
  };
}
