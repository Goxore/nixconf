{root, ...}: {
  formatter = pkgs: pkgs.alejandra;

  checks = pkgs: let
    inherit (pkgs) lib;

    ours = lib.fileset.toSource {
      inherit root;
      fileset = lib.fileset.union (root + "/statix.toml") (
        lib.fileset.difference
        (lib.fileset.fileFilter (file: file.hasExt "nix") root)
        (root + "/.tack")
      );
    };
  in {
    nix-fmt =
      pkgs.runCommand "nix-fmt-check" {
        nativeBuildInputs = [pkgs.alejandra];
      } ''
        if ! alejandra --check ${ours} 2>&1; then
          echo
          echo "Nix files are not alejandra-clean. Fix with:"
          echo "  nix fmt"
          exit 1
        fi
        touch $out
      '';

    nix-lint =
      pkgs.runCommand "nix-lint-check" {
        nativeBuildInputs = [pkgs.statix];
      } ''
        cd ${ours}
        if ! statix check . 2>&1; then
          echo
          echo "Nix files have statix warnings. Fix with:"
          echo "  statix fix ."
          exit 1
        fi
        touch $out
      '';
  };
}
