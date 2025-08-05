{
  pkgs,
  pname,
  version,
  dotnet-sdk,
  dotnet-runtime,
}:
rec {
  saturn-opentelemetry = pkgs.callPackage ./saturn-opentelemetry.nix {
    inherit
      pname
      version
      dotnet-sdk
      dotnet-runtime
      ;
  };
  example = pkgs.callPackage ./example.nix {
    inherit
      version
      dotnet-sdk
      dotnet-runtime
      saturn-opentelemetry
      ;
  };
}
