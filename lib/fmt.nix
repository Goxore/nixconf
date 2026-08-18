{
  perSystem = {pkgs, ...}: {
    formatter = pkgs.alejandra;

    checks.nix-fmt =
      pkgs.runCommand "nix-fmt-check" {
        nativeBuildInputs = [pkgs.alejandra];
      } ''
        if ! alejandra --check ${../.} 2>&1; then
          echo
          echo "Nix files are not alejandra-clean. Fix with:"
          echo "  nix fmt"
          exit 1
        fi
        touch $out
      '';
  };
}
