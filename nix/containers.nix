{
  pkgs,
  version,
  example,
}:
{
  container = pkgs.dockerTools.buildLayeredImage {
    name = "Example";
    tag = version;
    created = "now";
    contents = [
      pkgs.dockerTools.binSh
      pkgs.dockerTools.caCertificates
    ];
    config = {
      cmd = [
        "${example}/bin/Example"
      ];
      workingDir = "/app";
    };
  };
}
