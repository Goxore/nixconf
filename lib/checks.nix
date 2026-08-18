{
  flake.lib.mkGeneratedFileCheck = {
    pkgs,
    name,
    generated,
    committed,
    path,
  }:
    pkgs.runCommand "${name}-check" {
      inherit generated;
      passAsFile = ["generated"];
      passthru.regenPath = path;
    } ''
      if ! diff -u "$generatedPath" ${committed}; then
        echo
        echo "${path} is out of sync with lib/theme.nix."
        echo "Regenerate every generated file with:"
        echo "  nix run .#regen"
        exit 1
      fi
      touch $out
    '';

  perSystem = {pkgs, ...}: {
    packages.regen = pkgs.writeShellApplication {
      name = "regen";
      runtimeInputs = [pkgs.jq pkgs.git];
      text = ''
        root=$(git rev-parse --show-toplevel)
        system=${pkgs.stdenv.hostPlatform.system}

        mapfile -t names < <(
          nix eval --json "$root#checks.$system" --apply builtins.attrNames | jq -r '.[]'
        )

        for name in "''${names[@]}"; do
          target=$(nix eval --raw "$root#checks.$system.$name.regenPath" 2>/dev/null) || continue
          nix eval --raw "$root#checks.$system.$name.generated" > "$root/$target"
          echo "regenerated $target"
        done
      '';
    };
  };
}
