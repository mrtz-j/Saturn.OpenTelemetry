{
  pkgs,
  dotnet-sdk,
  saturn-opentelemetry,
}:
pkgs.writeShellApplication {
  name = "nuget-publish";
  runtimeInputs = [ dotnet-sdk ];
  text = ''
    : "''${NUGET_AUTH_TOKEN:?NUGET_AUTH_TOKEN must be set}"
    : "''${NUGET_API_KEY:?NUGET_API_KEY must be set}"

    export DOTNET_ROOT="${dotnet-sdk.unwrapped}/share/dotnet"
    export SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"

    NUPKG=$(find "${saturn-opentelemetry}/share/nuget/source" -name "*.nupkg" | head -1)
    if [ -z "$NUPKG" ]; then
      echo "No .nupkg found in ${saturn-opentelemetry}/share/nuget/source"
      exit 1
    fi
    echo "Publishing $NUPKG"

    dotnet nuget remove source github 2>/dev/null || true
    dotnet nuget add source \
      --username mrtz-j \
      --password "$NUGET_AUTH_TOKEN" \
      --store-password-in-clear-text \
      --name github \
      "https://nuget.pkg.github.com/mrtz-j/index.json"

    dotnet nuget push "$NUPKG" \
      --api-key "$NUGET_AUTH_TOKEN" \
      --source github \
      --skip-duplicate

    dotnet nuget push "$NUPKG" \
      --api-key "$NUGET_API_KEY" \
      --source "https://api.nuget.org/v3/index.json" \
      --skip-duplicate
  '';
}
