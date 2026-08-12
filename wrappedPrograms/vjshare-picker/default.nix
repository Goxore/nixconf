{...}: {
  perSystem = {
    pkgs,
    self',
    ...
  }: let
    qmlDir = pkgs.runCommand "vjshare-picker-qml" {} ''
      mkdir -p $out
      cp -r ${self'.packages.vjshellCommonsQml}/. $out/
      chmod -R u+w $out
      cp ${./shell.qml} $out/shell.qml
      cp ${./ShareRow.qml} $out/ShareRow.qml
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
