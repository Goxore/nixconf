{self, ...}: let
  mkColorsQml = import ../vjshell/_colors.nix;
in {
  perSystem = {pkgs, ...}: let
    colorsQml = pkgs.writeText "Colors.qml" (mkColorsQml self.theme);

    qmlDir = pkgs.runCommand "vjshare-picker-qml" {} ''
      mkdir -p $out/Commons $out/Widgets
      cp ${./shell.qml} $out/shell.qml
      cp ${./ShareRow.qml} $out/ShareRow.qml

      cp ${../vjshell/Commons/Theme.qml} $out/Commons/Theme.qml
      cp ${../vjshell/Commons/Style.qml} $out/Commons/Style.qml
      cp ${colorsQml} $out/Commons/Colors.qml

      cp ${../vjshell/Widgets/Surface.qml} $out/Widgets/Surface.qml
      cp ${../vjshell/Widgets/StateLayer.qml} $out/Widgets/StateLayer.qml
      cp ${../vjshell/Widgets/MaterialIcon.qml} $out/Widgets/MaterialIcon.qml
    '';
  in {
    packages.vjSharePicker = pkgs.writeShellApplication {
      name = "vjSharePicker";
      runtimeInputs = [pkgs.quickshell];
      text = ''
        tmp=$(mktemp -d)
        trap 'rm -rf "$tmp"' EXIT

        cat > "$tmp/list"
        : > "$tmp/result"

        VJSHARE_LIST="$tmp/list" VJSHARE_RESULT="$tmp/result" \
          quickshell -p ${qmlDir} >/dev/null || true

        cat "$tmp/result"
      '';
    };
  };
}
