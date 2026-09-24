_: {
  packages = pkgs: let
    python = pkgs.python3.withPackages (packages: [packages.ytmusicapi]);
  in {
    vjmusic = pkgs.writeShellScriptBin "vjmusic" ''
      exec ${python}/bin/python3 ${./_liked.py} "$@"
    '';
  };

  checks = pkgs: {
    vjmusic-liked =
      pkgs.runCommand "vjmusic-liked-check" {
        nativeBuildInputs = [pkgs.vj.vjmusic];
      } ''
        export HOME="$TMPDIR"
        export XDG_CONFIG_HOME="$TMPDIR/config"

        if vjmusic > "$TMPDIR/usage" 2>&1; then
          echo "vjmusic accepted a missing subcommand"
          exit 1
        fi
        grep -q 'usage: vjmusic liked' "$TMPDIR/usage"

        if vjmusic liked > "$TMPDIR/signed-out" 2>&1; then
          echo "vjmusic reported success without a signed-in profile"
          exit 1
        fi
        grep -q 'not_signed_in' "$TMPDIR/signed-out"

        touch $out
      '';
  };
}
