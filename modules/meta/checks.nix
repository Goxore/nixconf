{
  lib.sandboxHome = root: ''
    export XDG_RUNTIME_DIR="${root}/runtime"
    export XDG_CONFIG_HOME="${root}/config"
    export XDG_DATA_HOME="${root}/data"
    export XDG_STATE_HOME="${root}/state"
    export XDG_CACHE_HOME="${root}/cache"
    mkdir -p "$XDG_RUNTIME_DIR"
    chmod 700 "$XDG_RUNTIME_DIR"
  '';

  lib.mkGeneratedFileCheck = {
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
        echo "${path} is out of sync with modules/features/theme/palette.nix."
        echo "Regenerate every generated file with:"
        echo "  nix run .#regen"
        exit 1
      fi
      touch $out
    '';

  packages = pkgs: {
    regen = pkgs.writeShellApplication {
      name = "regen";
      runtimeInputs = [pkgs.jq pkgs.git];
      text = ''
        root=$(git rev-parse --show-toplevel)
        system=${pkgs.stdenv.hostPlatform.system}

        namesJson=$(nix eval --json "$root#checks.$system" --apply builtins.attrNames)
        mapfile -t names < <(jq -r '.[]' <<< "$namesJson")

        for name in "''${names[@]}"; do
          target=$(nix eval --raw "$root#checks.$system.$name.regenPath" 2>/dev/null) || continue
          generated=$(mktemp "$root/$target.XXXXXX")
          trap 'rm -f -- "$generated"' EXIT
          nix eval --raw "$root#checks.$system.$name.generated" > "$generated"
          chmod --reference="$root/$target" "$generated"
          mv -- "$generated" "$root/$target"
          echo "regenerated $target"
        done
      '';
    };
  };
}
