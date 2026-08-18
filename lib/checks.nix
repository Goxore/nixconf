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
    } ''
      if ! diff -u "$generatedPath" ${committed}; then
        echo
        echo "${path} is out of sync with lib/theme.nix."
        echo "Regenerate it with:"
        echo "  nix eval --raw .#checks.${pkgs.stdenv.hostPlatform.system}.${name}.generated \\"
        echo "    > ${path}"
        exit 1
      fi
      touch $out
    '';
}
