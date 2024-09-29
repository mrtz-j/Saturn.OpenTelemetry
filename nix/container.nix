{
  default,
  dockerTools,
  ...
}:
dockerTools.buildLayeredImage {
  name = "my-container";
  tag = "latest";
  contents = [ default ];
  config = {
    Cmd = [ "${default}/bin/" ];
  };
}
