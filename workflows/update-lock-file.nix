{
  name = "update lock file";
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
          nix -Lv flake update
        '';
      }
      {
        name = "Build passthru";
        run = ''
          nix -Lv build .#default.fetch-deps
        '';
      }
      {
        name = "Run passthru";
        run = ''
          ./result nix/deps.json
        '';
      }
      {
        name = "Format";
        run = ''
          nix -Lv develop .#default --command nixfmt .
        '';
      }
      {
        name = "Check";
        run = ''
          nix -Lv flake check
        '';
      }
    ];
  };
}
